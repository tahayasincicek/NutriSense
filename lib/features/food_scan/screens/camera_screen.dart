import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/models/food_analysis_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/stt_service.dart';
import '../../../shared/services/tts_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../models/camera_state.dart';
import '../services/image_preprocessing.dart';
import '../services/offline_recognizer.dart';
import '../services/recognition_policy.dart';
import '../services/turkish_portion_parser.dart';
import '../widgets/accessible_portion_selector.dart';

final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) {
  return availableCameras();
});

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  static final _qualityConfig = ImageQualityConfig.fromEnvironment();
  static const _policy = RecognitionPolicy();
  static const _qualityWarningCooldown = Duration(seconds: 6);
  static const _uuid = Uuid();

  CameraController? _controller;
  Timer? _autoCaptureTimer;
  CancelToken? _requestCancelToken;
  File? _temporaryCapture;
  late final TtsService _tts;
  late final SttService _stt;
  late final OfflineFoodRecognizer _offline;
  bool _initialized = false;
  bool _singleFlight = false;
  bool _saving = false;
  bool _portionUpdating = false;
  bool _disposed = false;
  int _generation = 0;
  DateTime? _lastQualityWarningAt;
  String? _captureId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts = ref.read(ttsServiceProvider);
    _stt = ref.read(sttServiceProvider);
    _offline = ref.read(offlineFoodRecognizerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeCamera());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoCapture();
    _requestCancelToken?.cancel('Kamera ekranı kapatıldı.');
    unawaited(_stt.cancelListening());
    unawaited(_deleteTemporaryCapture());
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopAutoCapture();
      _requestCancelToken?.cancel('Uygulama arka plana geçti.');
      final controller = _controller;
      _controller = null;
      _initialized = false;
      if (mounted) setState(() {});
      unawaited(controller?.dispose());
    } else if (state == AppLifecycleState.resumed && !_disposed) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initializeCamera() async {
    if (_disposed || _initialized) return;
    final notifier = ref.read(cameraStateProvider.notifier);
    notifier.setPermissionRequesting();
    final permission = await Permission.camera.request();
    if (_disposed) return;
    if (!permission.isGranted) {
      final permanent =
          permission.isPermanentlyDenied || permission.isRestricted;
      notifier.setError(
        permanent
            ? 'Kamera izni kalıcı olarak kapalı. Ayarlardan izin verin.'
            : 'Kamera izni verilmedi. Tekrar deneyebilir veya manuel giriş kullanabilirsiniz.',
        permanentlyDenied: permanent,
      );
      await _tts.speak('Kamera izni verilmedi. Manuel giriş kullanılabilir.');
      return;
    }
    notifier.setInitializing();
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('Kullanılabilir kamera yok.');
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      await controller.setFocusMode(FocusMode.auto);
      if (_disposed) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      _initialized = true;
      setState(() {});
      notifier.setReady();
      await _tts.speak(
        'Kamera hazır. Besini çerçeveye yerleştirin ve tara düğmesine basın.',
      );
      _startAutoCapture();
    } catch (_) {
      notifier.setError(
        'Kamera başlatılamadı. Tekrar deneyin veya manuel giriş kullanın.',
      );
      await _tts.speakError('Kamera başlatılamadı.');
    }
  }

  void _startAutoCapture() {
    _stopAutoCapture();
    if (!ref.read(cameraStateProvider).isAutoCapture) return;
    _autoCaptureTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (!_singleFlight &&
            {CameraStatus.ready, CameraStatus.qualityWarning}
                .contains(ref.read(cameraStateProvider).status)) {
          unawaited(_captureAndAnalyze(automatic: true));
        }
      },
    );
  }

  void _stopAutoCapture() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
  }

  Future<void> _captureAndAnalyze({required bool automatic}) async {
    final controller = _controller;
    if (_singleFlight ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    final generation = ++_generation;
    final notifier = ref.read(cameraStateProvider.notifier);
    _singleFlight = true;
    _requestCancelToken?.cancel('Yeni çekim başlatıldı.');
    _requestCancelToken = CancelToken();
    _captureId = _uuid.v4();
    try {
      notifier.setCapturing();
      if (!automatic) {
        await _tts.speak('Görüntü çekiliyor. Telefonu sabit tutun.');
      }
      final captured = await controller.takePicture();
      _temporaryCapture = File(captured.path);
      final bytes = await captured.readAsBytes();
      if (!_isCurrent(generation)) return;

      final quality = await ImagePreprocessor.checkQuality(
        bytes,
        config: _qualityConfig,
      );
      if (!_isCurrent(generation)) return;
      if (!quality.isAcceptable) {
        notifier.setQualityWarning(
          quality.message ?? 'Görüntü kalitesini iyileştirin.',
          quality.brightness,
          quality.isBlurry,
        );
        await _announceQualityWarning(quality);
        return;
      }

      notifier.setPreprocessing();
      final processed = await ImagePreprocessor.processImage(
        imageBytes: bytes,
        targetWidth: AppConstants.cameraInputWidth,
        targetHeight: AppConstants.cameraInputHeight,
        jpegQuality: AppConstants.imageQuality,
        qualityConfig: _qualityConfig,
      );
      if (!_isCurrent(generation)) return;
      if (!processed.isAcceptableQuality || processed.processedBytes.isEmpty) {
        notifier.setQualityWarning(
          processed.qualityIssue ?? 'Görüntü kalitesini iyileştirin.',
          processed.brightness,
          processed.blurScore < _qualityConfig.minimumBlurScore,
        );
        return;
      }
      notifier.setUploading();
      final response = await ref.read(apiServiceProvider).analyzeFood(
            imageBytes: processed.processedBytes,
            captureId: _captureId!,
            cancelToken: _requestCancelToken,
          );
      if (!_isCurrent(generation)) return;
      if (!response.isSuccess || response.data == null) {
        await _handleOnlineFailure(response.failure, processed.processedBytes);
        return;
      }
      await _presentAnalysis(response.data!);
    } on CameraException {
      if (_isCurrent(generation)) {
        notifier.setError('Kamera görüntüyü çekemedi. Lütfen tekrar deneyin.');
      }
    } on Object {
      if (_isCurrent(generation)) {
        notifier.setError(
          'Görüntü güvenli biçimde işlenemedi. Lütfen yeniden çekin.',
        );
        await _tts.speakError(
          'Görüntü işlenemedi. Lütfen yeniden çekin veya manuel giriş kullanın.',
        );
      }
    } finally {
      await _deleteTemporaryCapture();
      if (generation == _generation) _singleFlight = false;
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed && mounted && generation == _generation;

  Future<void> _handleOnlineFailure(
    ApiFailure? failure,
    Uint8List processedBytes,
  ) async {
    if (failure?.kind == ApiFailureKind.cancelled) return;
    if (failure?.kind == ApiFailureKind.connection ||
        failure?.kind == ApiFailureKind.timeout) {
      ref.read(cameraStateProvider.notifier).setOfflineInference();
      final offline = await _offline.recognize(processedBytes);
      if (offline.status == OfflineRecognitionStatus.success) {
        const message =
            'Çevrimdışı model doğrulama kapısından geçmedi. Manuel giriş kullanın.';
        ref.read(cameraStateProvider.notifier).setError(message);
        await _tts.speakError(message);
        return;
      }
      ref.read(cameraStateProvider.notifier).setError(offline.message);
      await _tts.speak('${offline.message} Manuel giriş düğmesini kullanın.');
      return;
    }
    final message = failure?.message ??
        'Analiz hizmeti kullanılamıyor. Manuel giriş yapabilirsiniz.';
    ref.read(cameraStateProvider.notifier).setError(message);
    await _tts.speakError(message);
  }

  Future<void> _presentAnalysis(FoodAnalysisResult result) async {
    _stopAutoCapture();
    final band = _policy.classify(result);
    if (band == RecognitionBand.low) {
      ref.read(cameraStateProvider.notifier).setRejected();
      await _tts.speak(
        'Yiyecek güvenilir biçimde tanınamadı. Kalori söylenmedi ve kayıt oluşturulmadı. Yeniden çekin veya manuel giriş kullanın.',
      );
      await AccessibilityUtils.errorHaptic();
      return;
    }
    ref.read(cameraStateProvider.notifier).setAnalysis(
          result,
          medium: band == RecognitionBand.medium,
        );
    await AccessibilityUtils.mediumHaptic();
    if (band == RecognitionBand.high) {
      final nutritionNote = result.nutritionStatus == 'unverified'
          ? 'Besin değeri yerel ve doğrulanmamış kaynaktan geliyor.'
          : 'Besin değeri kaynağı ${result.nutritionSource}.';
      await _tts.speak(
        '${result.foodNameTr} bulundu. Yaklaşık ${result.totalCalories.toStringAsFixed(0)} kalori. '
        'Tahmini ${result.portionGrams.toStringAsFixed(0)} gram; değiştirmek ister misiniz? '
        '$nutritionNote Doğruysa onaylayın, değilse düzeltin.',
      );
    } else {
      final names = _policy
          .candidates(result)
          .map((candidate) => candidate.foodNameTr)
          .join(', ');
      await _tts.speak(
        'Sonuç kesin değil. Olası seçenekler: $names. Bir seçenek seçin, yeniden çekin veya manuel giriş kullanın.',
      );
    }
  }

  Future<void> _announceQualityWarning(ImageQualityCheck quality) async {
    final now = DateTime.now();
    if (_lastQualityWarningAt != null &&
        now.difference(_lastQualityWarningAt!) < _qualityWarningCooldown) {
      return;
    }
    _lastQualityWarningAt = now;
    await _tts.speak(quality.message ?? 'Görüntü kalitesini iyileştirin.');
    await AccessibilityUtils.heavyHaptic();
  }

  Future<void> _confirm(
      {String? correctedName, String? correctedNameTr}) async {
    final analysis = ref.read(cameraStateProvider).analysis;
    if (_saving || analysis == null) return;
    if (correctedName == null && !analysis.canConfirm) {
      await _tts.speak('Bu sonuç onaylanamaz. Manuel düzeltme yapın.');
      return;
    }
    _saving = true;
    setState(() {});
    final hasUserPortion = !analysis.portionIsEstimate;
    final correctedWithPortion = correctedName != null && hasUserPortion;
    final result = await ref.read(apiServiceProvider).decideFoodAnalysis(
          analysisId: analysis.analysisId,
          action: correctedName == null ? 'confirm' : 'correct',
          correctedFoodName: correctedName,
          correctedFoodNameTr: correctedNameTr,
          portionValue: hasUserPortion
              ? (correctedWithPortion
                  ? analysis.portionGrams
                  : analysis.portionValue)
              : null,
          portionUnit: hasUserPortion
              ? (correctedWithPortion ? 'gram' : analysis.portionUnit)
              : null,
          portionMethod: hasUserPortion ? 'user_selected' : null,
          cancelToken: _requestCancelToken,
        );
    _saving = false;
    if (!mounted) return;
    setState(() {});
    if (result.isSuccess && result.data?.logId != null) {
      ref.read(cameraStateProvider.notifier).setDecisionAccepted(
            corrected: correctedName != null,
          );
      await _tts.speak('Onay alındı. Yemek geçmişine kaydediliyor.');
      ref.read(cameraStateProvider.notifier).setSaved(
            result.data!.logId!,
            corrected: correctedName != null,
          );
      await _tts.speak('Yemek geçmişine kaydedildi.');
      await AccessibilityUtils.successHaptic();
    } else {
      await _tts.speakError(result.errorMessage ?? 'Kayıt oluşturulamadı.');
    }
  }

  Future<void> _updatePortion(
    double value,
    String unit, {
    String method = 'user_selected',
  }) async {
    final analysis = ref.read(cameraStateProvider).analysis;
    if (analysis == null || _portionUpdating || _saving) return;
    _portionUpdating = true;
    if (mounted) setState(() {});
    final result = await ref.read(apiServiceProvider).updateFoodPortion(
          analysisId: analysis.analysisId,
          portionValue: value,
          portionUnit: unit,
          portionMethod: method,
          cancelToken: _requestCancelToken,
        );
    _portionUpdating = false;
    if (!mounted) return;
    setState(() {});
    if (!result.isSuccess || result.data == null) {
      await _tts.speakError(
        result.errorMessage ?? 'Porsiyon yeniden hesaplanamadı.',
      );
      return;
    }
    final updated = result.data!;
    ref.read(cameraStateProvider.notifier).setAnalysis(
          updated,
          medium: _policy.classify(updated) == RecognitionBand.medium,
        );
    await _tts.speak(updated.ttsText);
  }

  Future<PortionInput?> _showPortionDialog({double initialGrams = 100}) async {
    final controller = TextEditingController(
      text: initialGrams.toStringAsFixed(0),
    );
    final result = await showDialog<PortionInput>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Porsiyonu gram olarak girin'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Gram',
            hintText: 'Örnek: 150',
            helperText: '0 ile 2000 gram arasında olmalıdır.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (value == null ||
                  !value.isFinite ||
                  value <= 0 ||
                  value > 2000) {
                return;
              }
              Navigator.pop(
                context,
                PortionInput(value: value, unit: 'gram'),
              );
            },
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _editPortion() async {
    final analysis = ref.read(cameraStateProvider).analysis;
    if (analysis == null) return;
    final input = await _showPortionDialog(initialGrams: analysis.portionGrams);
    if (input != null) await _updatePortion(input.value, input.unit);
  }

  Future<void> _listenForPortion() async {
    await _tts.speak(
      'Porsiyonu birimiyle söyleyin. Örnek: yüz elli gram veya iki dilim.',
    );
    await _stt.startListening(
      listenFor: const Duration(seconds: 8),
      onResult: (result) {
        if (!result.isFinal) return;
        final input = parseTurkishPortion(result.text);
        if (input == null) {
          unawaited(_tts.speakError(
            'Porsiyon anlaşılamadı. Gram, adet, dilim veya kase ile tekrar söyleyin.',
          ));
          return;
        }
        unawaited(_updatePortion(
          input.value,
          input.unit,
          method: 'user_voice',
        ));
      },
      onError: (message) => _tts.speakError(message),
    );
  }

  Future<void> _reject() async {
    final analysis = ref.read(cameraStateProvider).analysis;
    if (_saving) return;
    if (analysis == null) {
      ref.read(cameraStateProvider.notifier).setRejected();
      return;
    }
    _saving = true;
    if (mounted) setState(() {});
    final result = await ref.read(apiServiceProvider).decideFoodAnalysis(
          analysisId: analysis.analysisId,
          action: 'reject',
          cancelToken: _requestCancelToken,
        );
    _saving = false;
    if (!mounted) return;
    setState(() {});
    if (!result.isSuccess || result.data?.status != 'rejected') {
      await _tts.speakError(
        result.errorMessage ??
            'Ret kararı kaydedilemedi. Lütfen tekrar deneyin.',
      );
      return;
    }
    ref.read(cameraStateProvider.notifier).setRejected();
    await _tts.speak('Sonuç reddedildi. Kayıt oluşturulmadı.');
  }

  Future<void> _showManualEntry({FoodCandidate? candidate}) async {
    final controller = TextEditingController(text: candidate?.foodNameTr ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Besini manuel girin'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Besin adı',
            hintText: 'Örnek: simit',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.length < 2 || !mounted) return;
    final analysis = ref.read(cameraStateProvider).analysis;
    if (analysis != null) {
      await _confirm(
        correctedName: value.toLowerCase().replaceAll(' ', '_'),
        correctedNameTr: value,
      );
      return;
    }
    final portion = await _showPortionDialog(initialGrams: 100);
    if (portion == null || !mounted) return;
    _captureId ??= _uuid.v4();
    final result = await ref.read(apiServiceProvider).createManualFoodLog(
          captureId: _captureId!,
          foodName: value.toLowerCase().replaceAll(' ', '_'),
          foodNameTr: value,
          portionValue: portion.value,
          portionMethod: 'user_selected',
          cancelToken: _requestCancelToken,
        );
    if (!mounted) return;
    if (result.isSuccess && result.data?.logId != null) {
      ref.read(cameraStateProvider.notifier).setSaved(result.data!.logId!);
      await _tts.speak('Manuel yemek geçmişine kaydedildi.');
    } else {
      await _tts.speakError(
        result.errorMessage ?? 'Besin değeri bulunamadığı için kaydedilmedi.',
      );
    }
  }

  Future<void> _listenForDecision() async {
    await _stt.startListening(
      listenFor: const Duration(seconds: 8),
      onResult: (result) {
        if (!result.isFinal) return;
        final text = result.text.toLowerCase();
        if (text.contains('evet') || text.contains('onay')) {
          unawaited(_confirm());
        } else if (text.contains('hayır') || text.contains('reddet')) {
          unawaited(_reject());
        } else {
          final candidates =
              ref.read(cameraStateProvider).analysis?.candidates ?? [];
          final index = text.contains('bir')
              ? 0
              : text.contains('iki')
                  ? 1
                  : text.contains('üç')
                      ? 2
                      : -1;
          if (index >= 0 && index < candidates.length) {
            unawaited(_confirm(
              correctedName: candidates[index].foodName,
              correctedNameTr: candidates[index].foodNameTr,
            ));
          }
        }
      },
      onError: (message) => _tts.speakError(message),
    );
  }

  Future<void> _deleteTemporaryCapture() async {
    final file = _temporaryCapture;
    _temporaryCapture = null;
    if (file != null && await file.exists()) {
      try {
        await file.delete();
      } on FileSystemException {
        // Camera cache cleanup will retry at the next lifecycle boundary.
      }
    }
  }

  void _reset() {
    _generation++;
    _requestCancelToken?.cancel('Yeni tarama başlatıldı.');
    _requestCancelToken = null;
    _captureId = null;
    _singleFlight = false;
    ref.read(cameraStateProvider.notifier).reset();
    if (_initialized) {
      _startAutoCapture();
    } else {
      unawaited(_initializeCamera());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cameraStateProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              _topBar(state),
              Expanded(child: _cameraBody(state)),
              _bottomPanel(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(CameraState state) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Geri',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
            ),
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  state.statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            IconButton(
              tooltip: state.isFlashOn ? 'Flaşı kapat' : 'Flaşı aç',
              onPressed: _initialized ? _toggleFlash : null,
              icon: Icon(
                state.isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );

  Widget _cameraBody(CameraState state) {
    if (!_initialized || _controller == null) {
      return Center(
        child: state.status == CameraStatus.error
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.errorMessage ?? state.statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: _statusColor(state.status), width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        if (_busy(state.status))
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        if (state.analysis != null &&
            {CameraStatus.resultReady, CameraStatus.confirmationRequired}
                .contains(state.status))
          _resultCard(state.analysis!),
      ],
    );
  }

  Widget _resultCard(FoodAnalysisResult result) => Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.foodNameTr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Model güveni: %${(result.confidence * 100).toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                result.nutritionReliability == 'verified_provider'
                    ? 'Besin verisi: doğrulanmış sağlayıcı (${result.nutritionSource})'
                    : result.nutritionReliability == 'verified_local'
                        ? 'Besin verisi: doğrulanmış yerel kaynak'
                        : 'Besin verisi doğrulanamadı',
                style: const TextStyle(color: Colors.amberAccent),
              ),
              if (result.canConfirm)
                Column(
                  children: [
                    Text(
                      'Yaklaşık ${result.totalCalories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(color: Colors.white, fontSize: 22),
                    ),
                    Text(
                      '${result.portionGrams.toStringAsFixed(0)} g '
                      '(${result.portionIsEstimate ? 'kaynak önerisi' : 'kullanıcı seçimi'})',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const Text(
                      'Tahmini bilgi; tıbbi teşhis veya kişiselleştirilmiş tedavi değildir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );

  Widget _bottomPanel(CameraState state) {
    final analysis = state.analysis;
    final candidates =
        analysis == null ? <FoodCandidate>[] : _policy.candidates(analysis);
    return Container(
      color: const Color(0xEE000000),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (analysis?.canConfirm == true) ...[
            AccessiblePortionSelector(
              result: analysis!,
              enabled: !_saving,
              loading: _portionUpdating,
              onSelected: (value, unit) => _updatePortion(value, unit),
              onManual: _editPortion,
              onVoice: _listenForPortion,
            ),
            const SizedBox(height: 8),
          ],
          if (state.status == CameraStatus.confirmationRequired)
            Wrap(
              spacing: 8,
              children: [
                for (final candidate in candidates)
                  ActionChip(
                    label: Text(candidate.foodNameTr),
                    onPressed: () => _confirm(
                      correctedName: candidate.foodName,
                      correctedNameTr: candidate.foodNameTr,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          if ({CameraStatus.resultReady, CameraStatus.confirmationRequired}
              .contains(state.status))
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                AccessibleButton(
                  label: 'Onayla',
                  semanticLabel: 'Sonucu onayla ve yemek geçmişine kaydet',
                  icon: Icons.check,
                  isLoading: _saving,
                  onPressed: analysis?.canConfirm == true && !_saving
                      ? _confirm
                      : null,
                ),
                AccessibleButton(
                  label: 'Düzelt',
                  semanticLabel: 'Besin adını düzelt',
                  icon: Icons.edit,
                  onPressed: () => _showManualEntry(),
                ),
                AccessibleButton(
                  label: 'Reddet',
                  semanticLabel: 'Sonucu reddet ve kaydetme',
                  icon: Icons.close,
                  onPressed: _reject,
                ),
                IconButton(
                  tooltip: 'Sesli evet, hayır veya seçenek söyle',
                  onPressed: _listenForDecision,
                  icon: const Icon(Icons.mic, color: Colors.white),
                ),
              ],
            )
          else if (state.status == CameraStatus.saved)
            AccessibleButton(
              label: 'Geçmişe Dön',
              semanticLabel: 'Kaydedilen yemeği geçmişte görmek için dön',
              icon: Icons.history,
              onPressed: () => Navigator.pop(context, state),
            )
          else
            Row(
              children: [
                Expanded(
                  child: AccessibleButton(
                    label: 'Manuel Giriş',
                    semanticLabel: 'Besin adını elle gir',
                    icon: Icons.edit_note,
                    onPressed: () => _showManualEntry(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AccessibleButton(
                    label: state.permissionPermanentlyDenied
                        ? 'Ayarları Aç'
                        : 'Tara',
                    semanticLabel: state.permissionPermanentlyDenied
                        ? 'Kamera izni için uygulama ayarlarını aç'
                        : 'Şimdi fotoğraf çek ve analiz et',
                    icon: state.permissionPermanentlyDenied
                        ? Icons.settings
                        : Icons.camera,
                    isLoading: _singleFlight,
                    onPressed: state.permissionPermanentlyDenied
                        ? openAppSettings
                        : _initialized && !_singleFlight
                            ? () => _captureAndAnalyze(automatic: false)
                            : null,
                  ),
                ),
                if ({CameraStatus.rejected, CameraStatus.error}
                    .contains(state.status)) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Yeniden dene',
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final current = ref.read(cameraStateProvider);
    await controller.setFlashMode(
      current.isFlashOn ? FlashMode.off : FlashMode.torch,
    );
    ref.read(cameraStateProvider.notifier).toggleFlash();
  }

  bool _busy(CameraStatus status) => {
        CameraStatus.capturing,
        CameraStatus.preprocessing,
        CameraStatus.uploading,
        CameraStatus.offlineInference,
      }.contains(status);

  Color _statusColor(CameraStatus status) {
    if (status == CameraStatus.saved) return AppTheme.successColor;
    if (status == CameraStatus.error || status == CameraStatus.rejected) {
      return AppTheme.errorColor;
    }
    if (_busy(status) || status == CameraStatus.qualityWarning) {
      return Colors.amber;
    }
    return Colors.white70;
  }
}
