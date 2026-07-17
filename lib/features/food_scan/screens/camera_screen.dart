// =============================================================================
// lib/features/food_scan/screens/camera_screen.dart
// NutriSense — Erişilebilir Kamera Ekranı (Ana Modül)
//
// Görme engelli kullanıcılar için özel olarak tasarlanmış kamera ekranı.
//
// ÖZELLİKLER:
//   1. CameraController başlatma, izin kontrolü, ön/arka kamera seçimi
//   2. Her 2 saniyede otomatik kare yakalama + kalite analizi
//   3. Parlaklık ve bulanıklık kontrolü → sesli uyarı
//   4. 224×224 resize + JPEG %85 (ayrı isolate'te), multipart yükleme
//   5. Erişilebilir arayüz: büyük butonlar, haptic, Semantics
//   6. Her CameraState geçişinde TTS ile sesli bildirim
//
// BELLEK YÖNETİMİ: dispose() ile kamera, timer, controller serbest bırakılır.
// =============================================================================

import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/services/tts_service.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../models/camera_state.dart';
import '../services/image_preprocessing.dart';

/// Cihaz kameralarını tutan provider — uygulama başlangıcında doldurulur
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) {
  return availableCameras();
});

/// Erişilebilir kamera ekranı
///
/// Kullanım:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const CameraScreen(),
/// ));
/// ```
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  // ── Kamera ──
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // ── Otomatik yakalama ──
  Timer? _autoCaptureTimer;
  bool _isProcessing = false;

  // ── Son kalite uyarısı zamanı (spam önleme) ──
  DateTime? _lastQualityWarningTime;
  static const _qualityWarningCooldown = Duration(seconds: 5);

  // ── TTS ──
  late TtsService _tts;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // TTS servisini al
    _tts = ref.read(ttsServiceProvider);

    // Kamerayı başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoCapture();
    _cameraController?.dispose();
    _cameraController = null;
    super.dispose();
  }

  /// Uygulama yaşam döngüsü — arka plana geçtiğinde kamerayı durdur
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopAutoCapture();
      _cameraController?.dispose();
      _isCameraInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  // ===========================================================================
  // KAMERA BAŞLATMA
  // ===========================================================================

  /// Kamerayı başlatır — izin kontrolü, CameraController oluşturma
  Future<void> _initializeCamera() async {
    final notifier = ref.read(cameraStateProvider.notifier);

    // Durum: başlatılıyor
    notifier.setInitializing();
    _tts.speak('Kamera başlatılıyor, lütfen bekleyin.');

    // ── İzin kontrolü ──
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      notifier.setError(
        'Kamera erişimi reddedildi. Lütfen ayarlardan kamera iznini verin.',
      );
      _tts.speak(
        'Kamera erişimi reddedildi. '
        'Lütfen telefon ayarlarından kamera iznini verin.',
      );
      await AccessibilityUtils.errorHaptic();
      return;
    }

    // ── Kullanılabilir kameraları al ──
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        notifier.setError('Kullanılabilir kamera bulunamadı.');
        _tts.speak('Kullanılabilir kamera bulunamadı.');
        await AccessibilityUtils.errorHaptic();
        return;
      }

      // Arka kamerayı bul (varsayılan), yoksa ilk kamerayı kullan
      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // ── CameraController oluştur ──
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium, // Dengeli çözünürlük — hız vs kalite
        enableAudio: false, // Ses kaydı gerekmiyor
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      // Flaş kapalı başlat (pil tasarrufu)
      await _cameraController!.setFlashMode(FlashMode.off);

      // Otomatik odaklama
      await _cameraController!.setFocusMode(FocusMode.auto);

      if (mounted) {
        setState(() => _isCameraInitialized = true);
        notifier.setReady();
        _tts.speak(
          'Kamera hazır. '
          'Besini kameraya tutun, otomatik tarama başlayacak. '
          'Veya tara butonuna basarak manuel tarama yapabilirsiniz.',
        );
        await AccessibilityUtils.successHaptic();

        // Otomatik yakalamayı başlat
        _startAutoCapture();
      }
    } catch (e) {
      notifier.setError('Kamera başlatılamadı: ${e.toString()}');
      _tts.speak('Kamera başlatılamadı. Lütfen uygulamayı yeniden başlatın.');
      await AccessibilityUtils.errorHaptic();
    }
  }

  // ===========================================================================
  // OTOMATİK YAKALAMA
  // ===========================================================================

  /// Her 2 saniyede bir otomatik kare yakalar ve analiz eder
  void _startAutoCapture() {
    _stopAutoCapture(); // Önceki timer varsa temizle

    final cameraState = ref.read(cameraStateProvider);
    if (!cameraState.isAutoCapture) return;

    _autoCaptureTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _captureAndAnalyze(),
    );
  }

  /// Otomatik yakalamayı durdurur
  void _stopAutoCapture() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
  }

  /// Tek bir kare yakalar → kalite kontrol → ön işleme → API
  Future<void> _captureAndAnalyze() async {
    // Zaten işleniyorsa veya kamera hazır değilse atla
    if (_isProcessing) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    final notifier = ref.read(cameraStateProvider.notifier);

    try {
      _isProcessing = true;

      // ── Kare yakala ──
      final XFile imageFile = await _cameraController!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // ── Kalite kontrolü (hızlı — ayrı isolate'te) ──
      final qualityCheck = await ImagePreprocessor.checkQuality(imageBytes);

      // Kalite uyarıları (spam olmadan — 5 saniye aralık)
      if (!qualityCheck.isAcceptable) {
        _sendQualityWarning(qualityCheck);
        notifier.updateBrightness(qualityCheck.brightness);
        notifier.updateBlurry(qualityCheck.isBlurry);
        _isProcessing = false;
        return;
      }

      // ── Yiyecek tespit edildi bildirimi ──
      notifier.setFoodDetected();
      _tts.speak('Yiyecek tespit edildi, analiz ediliyor.');
      await AccessibilityUtils.mediumHaptic();

      // ── Ön işleme (ayrı isolate) ──
      notifier.setProcessing();
      final result = await ImagePreprocessor.processImage(
        imageBytes: imageBytes,
        targetWidth: AppConstants.cameraInputWidth,
        targetHeight: AppConstants.cameraInputHeight,
        jpegQuality: AppConstants.imageQuality,
      );

      if (!result.isAcceptableQuality) {
        _sendQualityWarning(ImageQualityCheck(
          brightness: result.brightness,
          blurScore: result.blurScore,
          isTooDark: result.brightness < 40,
          isTooBright: result.brightness > 220,
          isBlurry: result.blurScore < 100,
          isAcceptable: false,
          message: result.qualityIssue,
        ));
        _isProcessing = false;
        notifier.setReady();
        return;
      }

      // ── Backend'e gönder ──
      await _sendToBackend(result);
    } catch (e) {
      notifier.setError('Görüntü işleme hatası: ${e.toString()}');
      _tts.speakError('Görüntü işlenirken bir hata oluştu. Tekrar deneniyor.');
    } finally {
      _isProcessing = false;
    }
  }

  /// Kalite uyarısını sesli bildirir (spam korumalı)
  void _sendQualityWarning(ImageQualityCheck quality) {
    final now = DateTime.now();
    if (_lastQualityWarningTime != null &&
        now.difference(_lastQualityWarningTime!) < _qualityWarningCooldown) {
      return; // Çok sık uyarma — 5 saniye bekle
    }
    _lastQualityWarningTime = now;

    if (quality.isTooDark) {
      _tts.speak('Daha fazla ışık gerekiyor. Ortamı aydınlatın.');
      AccessibilityUtils.heavyHaptic();
    } else if (quality.isTooBright) {
      _tts.speak('Ortam çok parlak. Kamerayı gölgeye çevirin.');
      AccessibilityUtils.heavyHaptic();
    } else if (quality.isBlurry) {
      _tts.speak('Kamerayı sabit tutun. Görüntü bulanık.');
      AccessibilityUtils.heavyHaptic();
    }
  }

  /// İşlenmiş görüntüyü backend'e gönderir
  Future<void> _sendToBackend(PreprocessingResult result) async {
    final notifier = ref.read(cameraStateProvider.notifier);

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.analyzeFood(
        imageBytes: result.processedBytes,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final foodName = data.foodNameTr;
        final calories = data.totalCalories;
        final confidence = data.confidence;

        // ── Güvenilirlik kontrolü ──
        if (!data.needsConfirmation &&
            confidence >= AppConstants.highConfidenceThreshold) {
          // Yüksek güvenilirlik — doğrudan bildir
          notifier.setResult(
            foodName: foodName,
            calories: calories,
            confidence: confidence,
          );
          _tts.speakFoodResult(
            foodName: foodName,
            calories: calories,
            portionGrams: data.portionGrams,
            protein: data.nutrients.protein,
            carbs: data.nutrients.carbs,
            fat: data.nutrients.fat,
          );
          await AccessibilityUtils.successHaptic();

          // Otomatik yakalamayı durdur — sonuç alındı
          _stopAutoCapture();
        } else if (confidence >= AppConstants.lowConfidenceThreshold) {
          // Orta güvenilirlik — onay iste
          notifier.setResult(
            foodName: foodName,
            calories: calories,
            confidence: confidence,
          );
          _tts.speak(
            '$foodName olabilir. '
            '${calories.toStringAsFixed(0)} kalori. '
            'Doğru mu? Onaylamak için tara butonuna basın.',
          );
          _stopAutoCapture();
        } else {
          // Düşük güvenilirlik — tekrar dene
          notifier.setReady();
          _tts.speak(
            'Yiyecek net olarak tanınamadı. '
            'Lütfen besini kameraya biraz daha yaklaştırın.',
          );
        }
      } else {
        notifier.setReady();
        _tts.speakError(response.errorMessage ??
            'Sunucu isteği tamamlanamadı. Tekrar deneyin.');
      }
    } catch (e) {
      // API hatası — taramaya devam et
      notifier.setReady();
      _tts.speakError('Sunucuya bağlanılamadı. Tekrar deneniyor.');
    }
  }

  // ===========================================================================
  // KULLANICI ETKİLEŞİMLERİ
  // ===========================================================================

  /// Manuel tarama — kullanıcı butona bastığında
  Future<void> _manualCapture() async {
    await AccessibilityUtils.mediumHaptic();
    final notifier = ref.read(cameraStateProvider.notifier);
    notifier.setCapturing();
    _tts.speak('Görüntü yakalanıyor, telefonu sabit tutun.');
    await _captureAndAnalyze();
  }

  /// Flaş aç/kapat
  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    final notifier = ref.read(cameraStateProvider.notifier);
    final currentState = ref.read(cameraStateProvider);

    notifier.toggleFlash();
    final newFlash = !currentState.isFlashOn;

    await _cameraController!
        .setFlashMode(newFlash ? FlashMode.torch : FlashMode.off);

    _tts.speak(newFlash ? 'Flaş açıldı' : 'Flaş kapatıldı');
    await AccessibilityUtils.lightHaptic();
  }

  /// Yeniden taramaya başla
  void _resetAndRescan() {
    final notifier = ref.read(cameraStateProvider.notifier);
    notifier.reset();
    _tts.speak('Tarama sıfırlandı. Besini kameraya tutun.');
    AccessibilityUtils.lightHaptic();
    _startAutoCapture();
  }

  // ===========================================================================
  // ARAYÜZ (BUILD)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraStateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      // ── Durum çubuğunu gizle — tam ekran kamera ──
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              // ── Üst Çubuk: Geri + Flaş ──
              _buildTopBar(context, cameraState, theme),

              // ── Kamera Önizleme ──
              Expanded(
                child: _buildCameraBody(cameraState, theme),
              ),

              // ── Alt Panel: Durum + Butonlar ──
              _buildBottomPanel(cameraState, theme),
            ],
          ),
        ),
      ),
    );
  }

  /// Üst çubuk — geri butonu ve flaş kontrolü
  Widget _buildTopBar(
      BuildContext context, CameraState cameraState, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Geri butonu
          Semantics(
            label: 'Geri dön. Kamera ekranından çıkılır.',
            button: true,
            child: IconButton(
              onPressed: () {
                _stopAutoCapture();
                _tts.speak('Kamera kapatılıyor.');
                AccessibilityUtils.lightHaptic();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
              padding: const EdgeInsets.all(12),
            ),
          ),

          // Durum göstergesi
          Semantics(
            liveRegion: true,
            label: cameraState.statusMessage ?? '',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColor(cameraState.status).withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ExcludeSemantics(
                child: Text(
                  cameraState.statusMessage ?? '',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Flaş butonu
          Semantics(
            label: cameraState.isFlashOn
                ? 'Flaşı kapat. Flaş şu an açık.'
                : 'Flaşı aç. Karanlık ortamda aydınlatma sağlar.',
            button: true,
            child: IconButton(
              onPressed: _isCameraInitialized ? _toggleFlash : null,
              icon: Icon(
                cameraState.isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: cameraState.isFlashOn ? Colors.amber : Colors.white,
                size: 32,
              ),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  /// Kamera önizleme alanı
  Widget _buildCameraBody(CameraState cameraState, ThemeData theme) {
    // Kamera henüz hazır değilken
    if (!_isCameraInitialized || _cameraController == null) {
      return _buildLoadingOrError(cameraState, theme);
    }

    return Semantics(
      label: _cameraBodySemanticLabel(cameraState),
      image: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Kamera önizleme
          ClipRRect(
            child: CameraPreview(_cameraController!),
          ),

          // ── Hedefleme çerçevesi (görsel kılavuz) ──
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _frameColor(cameraState.status),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // ── İşleniyor göstergesi ──
          if (cameraState.status == CameraStatus.processing ||
              cameraState.status == CameraStatus.foodDetected)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 4,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      cameraState.statusMessage ?? 'Analiz ediliyor...',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Sonuç gösterimi ──
          if (cameraState.status == CameraStatus.resultReady)
            _buildResultOverlay(cameraState, theme),
        ],
      ),
    );
  }

  /// Yükleniyor veya hata durumu
  Widget _buildLoadingOrError(CameraState cameraState, ThemeData theme) {
    if (cameraState.status == CameraStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 72),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  cameraState.errorMessage ?? 'Bir hata oluştu',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              AccessibleButton(
                label: 'Tekrar Dene',
                semanticLabel: 'Kamerayı yeniden başlatmak için basın',
                icon: Icons.refresh,
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                onPressed: _initializeCamera,
              ),
            ],
          ),
        ),
      );
    }

    // Başlatılıyor
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
          SizedBox(height: 16),
          Text(
            'Kamera başlatılıyor...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  /// Tanıma sonucu overlay'ı
  Widget _buildResultOverlay(CameraState cameraState, ThemeData theme) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 64),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  cameraState.recognizedFood ?? '',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${cameraState.calories?.toStringAsFixed(0) ?? '--'} kcal',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              if (cameraState.confidence != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Güven: %${(cameraState.confidence! * 100).toStringAsFixed(0)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Alt panel — sesli yönlendirme + butonlar
  Widget _buildBottomPanel(CameraState cameraState, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xE6000000), // Yarı saydam siyah
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Sesli yönlendirme metni ──
          Semantics(
            liveRegion: true,
            label: _getGuidanceText(cameraState),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExcludeSemantics(
                child: Text(
                  _getGuidanceText(cameraState),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // ── Butonlar ──
          if (cameraState.status == CameraStatus.resultReady)
            // Sonuç alındı — Kaydet + Tekrar Tara
            Row(
              children: [
                Expanded(
                  child: AccessibleButton(
                    label: 'Kaydet',
                    semanticLabel:
                        '${cameraState.recognizedFood} kaydını yemek günlüğüne ekle',
                    semanticHint: 'Çift dokunarak kaydedin',
                    icon: Icons.save_alt,
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      _tts.speak('Yemek kaydedildi.');
                      AccessibilityUtils.successHaptic();
                      Navigator.of(context).pop(cameraState);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AccessibleButton(
                    label: 'Tekrar Tara',
                    semanticLabel: 'Sonucu sil ve yeni bir besin tara',
                    icon: Icons.refresh,
                    type: AccessibleButtonType.outlined,
                    foregroundColor: Colors.white,
                    onPressed: _resetAndRescan,
                  ),
                ),
              ],
            )
          else
            // Normal mod — Tara + İptal
            Row(
              children: [
                // İptal butonu
                Expanded(
                  child: AccessibleButton(
                    label: 'İptal',
                    semanticLabel: 'Besin taramayı iptal et ve geri dön',
                    semanticHint: 'Çift dokunarak iptal edin',
                    icon: Icons.close,
                    type: AccessibleButtonType.outlined,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      _tts.speak('Tarama iptal edildi.');
                      AccessibilityUtils.lightHaptic();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Manuel tara butonu
                Expanded(
                  flex: 2,
                  child: AccessibleButton(
                    label: 'Tara',
                    semanticLabel:
                        'Besini şimdi tara. Kamerayı besine tutun ve bu butona basın.',
                    semanticHint: 'Çift dokunarak taramayı başlatın',
                    icon: Icons.camera,
                    isLoading: cameraState.status == CameraStatus.processing ||
                        cameraState.status == CameraStatus.capturing,
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    onPressed: (cameraState.status == CameraStatus.ready ||
                            cameraState.status == CameraStatus.error)
                        ? _manualCapture
                        : null,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // YARDIMCI METOTLAR
  // ===========================================================================

  /// Durum rengini döner
  Color _statusColor(CameraStatus status) {
    switch (status) {
      case CameraStatus.initializing:
        return Colors.orange;
      case CameraStatus.ready:
        return AppTheme.primaryColor;
      case CameraStatus.capturing:
      case CameraStatus.processing:
        return Colors.amber;
      case CameraStatus.foodDetected:
        return Colors.blue;
      case CameraStatus.resultReady:
        return AppTheme.successColor;
      case CameraStatus.error:
        return AppTheme.errorColor;
    }
  }

  /// Çerçeve rengini döner
  Color _frameColor(CameraStatus status) {
    switch (status) {
      case CameraStatus.ready:
        return Colors.white.withOpacity(0.6);
      case CameraStatus.capturing:
      case CameraStatus.foodDetected:
        return Colors.amber;
      case CameraStatus.resultReady:
        return AppTheme.successColor;
      case CameraStatus.error:
        return AppTheme.errorColor;
      default:
        return Colors.white.withOpacity(0.3);
    }
  }

  /// Kamera gövdesi için semantik etiket
  String _cameraBodySemanticLabel(CameraState cameraState) {
    switch (cameraState.status) {
      case CameraStatus.ready:
        return 'Kamera önizleme alanı. Besini kameranın önüne tutun.';
      case CameraStatus.capturing:
        return 'Görüntü yakalanıyor. Telefonu sabit tutun.';
      case CameraStatus.processing:
        return 'Yiyecek analiz ediliyor. Lütfen bekleyin.';
      case CameraStatus.foodDetected:
        return 'Yiyecek tespit edildi. Analiz ediliyor.';
      case CameraStatus.resultReady:
        return '${cameraState.recognizedFood} tanındı. '
            '${cameraState.calories?.toStringAsFixed(0)} kalori.';
      case CameraStatus.error:
        return 'Hata: ${cameraState.errorMessage}';
      default:
        return 'Kamera başlatılıyor.';
    }
  }

  /// Alt paneldeki yönlendirme metni
  String _getGuidanceText(CameraState cameraState) {
    switch (cameraState.status) {
      case CameraStatus.initializing:
        return '⏳ Kamera başlatılıyor...';
      case CameraStatus.ready:
        return '📸 Besini kameraya tutun — otomatik tarama aktif';
      case CameraStatus.capturing:
        return '📷 Görüntü yakalanıyor — telefonu sabit tutun';
      case CameraStatus.processing:
        return '🔍 Yiyecek analiz ediliyor...';
      case CameraStatus.foodDetected:
        return '🍽️ Yiyecek tespit edildi, detaylar yükleniyor...';
      case CameraStatus.resultReady:
        return '✅ ${cameraState.recognizedFood} — '
            '${cameraState.calories?.toStringAsFixed(0)} kcal';
      case CameraStatus.error:
        return '❌ ${cameraState.errorMessage ?? "Hata oluştu"}';
    }
  }
}
