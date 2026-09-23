import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/models/food_analysis_model.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/contextual_voice_command.dart';
import '../../../shared/services/stt_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/accessible_number_dialog.dart';
import '../../history/state/history_controller.dart';
import '../models/camera_state.dart';
import '../services/food_correction_sample_store.dart';
import '../services/image_preprocessing.dart';
import '../services/offline_recognizer.dart';
import '../services/recognition_policy.dart';
import '../services/turkish_portion_parser.dart';
import '../widgets/accessible_portion_selector.dart';

final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) {
  return availableCameras();
});

final galleryImagePickerProvider =
    Provider<ImagePicker>((ref) => ImagePicker());

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({
    super.key,
    this.initializeHardware = true,
  });

  /// Yalnız widget testlerinde platform kamerasını başlatmadan gerçek ekran
  /// ağacını doğrulamak için kullanılır. Ürün varsayılanı her zaman `true`dur.
  final bool initializeHardware;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  static final _qualityConfig = ImageQualityConfig.fromEnvironment();
  static const _policy = RecognitionPolicy();
  static const _qualityWarningCooldown = Duration(seconds: 6);
  static const _uuid = Uuid();
  static const _voiceParser = ContextualVoiceCommandParser();

  CameraController? _controller;
  Timer? _autoCaptureTimer;
  CancelToken? _requestCancelToken;
  File? _temporaryCapture;
  late final AccessibilityService _tts;
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
  String? _voiceStatus;
  bool _voiceListening = false;
  bool _pickingGallery = false;
  Uint8List? _correctionSampleBytes;
  String? _correctionPredictedName;
  double? _correctionPredictedConfidence;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts = ref.read(accessibilityServiceProvider);
    _stt = ref.read(sttServiceProvider);
    _offline = ref.read(offlineFoodRecognizerProvider);
    if (widget.initializeHardware) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initializeCamera());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tts.setScreenReaderActive(MediaQuery.of(context).accessibleNavigation);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoCapture();
    _requestCancelToken?.cancel('Kamera ekranı kapatıldı.');
    if (widget.initializeHardware) unawaited(_stt.cancelListening());
    unawaited(_deleteTemporaryCapture());
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sistem fotoğraf seçicisi de uygulamayı geçici olarak arka plana alır.
    // Dönüşte seçilen fotoğrafın analiz durumunu kamera başlangıcıyla ezmeyin.
    if (_pickingGallery) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopAutoCapture();
      _requestCancelToken?.cancel('Uygulama arka plana geçti.');
      final controller = _controller;
      _controller = null;
      _initialized = false;
      if (mounted) setState(() {});
      if (widget.initializeHardware) unawaited(_stt.cancelListening());
      _tts.finishSpeechInput();
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
        'Kamera hazır. Telefonu besine doğru tutun ve tara deyin.',
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

  Future<void> _captureAndAnalyze(
      {required bool automatic, bool fromGallery = false}) async {
    final controller = _controller;
    if (_singleFlight ||
        (!fromGallery &&
            (controller == null || !controller.value.isInitialized))) {
      return;
    }
    final generation = ++_generation;
    final notifier = ref.read(cameraStateProvider.notifier);
    _singleFlight = true;
    _requestCancelToken?.cancel('Yeni çekim başlatıldı.');
    _requestCancelToken = CancelToken();
    _captureId = _uuid.v4();
    try {
      late final Uint8List bytes;
      if (fromGallery) {
        _stopAutoCapture();
        _pickingGallery = true;
        setState(() {});
        final selected = await ref.read(galleryImagePickerProvider).pickImage(
              source: ImageSource.gallery,
              maxWidth: 2048,
              maxHeight: 2048,
              requestFullMetadata: false,
            );
        _pickingGallery = false;
        if (!_isCurrent(generation)) return;
        if (selected == null) {
          await _tts.speak('Fotoğraf seçimi iptal edildi.');
          return;
        }
        // Galerideki asıl fotoğrafı silmeyin; yalnız baytlarını okuyun.
        bytes = await selected.readAsBytes();
        notifier.setCapturing();
        await _tts.speak('Seçilen fotoğraf analiz ediliyor.');
      } else {
        notifier.setCapturing();
        if (!automatic) {
          await _tts.speak('Görüntü çekiliyor. Telefonu sabit tutun.');
        }
        final captured = await controller!.takePicture();
        _temporaryCapture = File(captured.path);
        bytes = await captured.readAsBytes();
      }
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
      // Düzeltme örneği için yalnız modelin gördüğü yeniden boyutlandırılmış,
      // yeniden kodlanmış JPEG tutulur. Orijinal fotoğraf/EXIF saklanmaz.
      _correctionSampleBytes = Uint8List.fromList(processed.processedBytes);
      _correctionPredictedName = null;
      _correctionPredictedConfidence = null;
      // Fotoğraf telefondan çıkmaz: tanımayı telefondaki NutriSense modeli
      // yapar. Kalori, kullanıcı onayından sonra doğrulanmış katalogdan gelir.
      notifier.setOfflineInference();
      await _runOnDeviceModel(processed.processedBytes, generation);
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
      _pickingGallery = false;
      await _deleteTemporaryCapture();
      if (generation == _generation) {
        _singleFlight = false;
        if (mounted) {
          setState(() {});
          if (fromGallery && _initialized) _startAutoCapture();
        }
      }
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed && mounted && generation == _generation;

  Future<void> _runOnDeviceModel(
      Uint8List processedBytes, int generation) async {
    final outcome = await _offline.recognize(processedBytes);
    if (!_isCurrent(generation)) return;

    if ({
      OfflineRecognitionStatus.success,
      OfflineRecognitionStatus.suggestion,
    }.contains(outcome.status)) {
      final name = outcome.foodNameTr!;
      final percent = (outcome.confidence! * 100).round();
      final tentative = outcome.status == OfflineRecognitionStatus.suggestion;
      _correctionPredictedName = name;
      _correctionPredictedConfidence = outcome.confidence!;
      ref.read(cameraStateProvider.notifier).setOnDeviceSuggestion(
            name,
            outcome.confidence!,
            tentative: tentative,
            candidates: outcome.candidates,
          );
      final alternatives = outcome.candidates.skip(1).map((candidate) {
        return candidate.foodNameTr;
      }).join(' ve ');
      await _tts.speak(
        tentative
            ? 'Olası tahmin $name. Güven yüzde $percent. Kaydetmeden önce '
                'kontrol edin. Diğer seçenekler $alternatives. Birinci, ikinci '
                'veya üçüncü seçenek diyebilirsiniz.'
            : 'Cihaz üstü model bunu $name olarak tanıdı. Güven yüzde '
                '$percent. '
                'Kalori için bağlantı gerekiyor; onaylayabilir veya manuel giriş '
                'yapabilirsiniz.',
      );
      return;
    }

    if (outcome.status == OfflineRecognitionStatus.rejected) {
      ref.read(cameraStateProvider.notifier).setRejected();
      await _tts.speak(outcome.message);
      await AccessibilityUtils.errorHaptic();
      return;
    }

    ref.read(cameraStateProvider.notifier).setError(outcome.message);
    await _tts.speak(
      '${outcome.message} Besin adını söyleyerek de ekleyebilirsiniz.',
    );
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
      unawaited(ref.read(historyControllerProvider.notifier).refresh());
      await _tts.speak('Yemek geçmişine kaydedildi.');
      await AccessibilityUtils.successHaptic();
    } else {
      await _tts.speakError(result.errorMessage ?? 'Kayıt oluşturulamadı.');
    }
  }

  Future<void> _saveCorrectionSample(String correctName) async {
    final bytes = _correctionSampleBytes;
    final predictedName = _correctionPredictedName;
    final confidence = _correctionPredictedConfidence;
    final captureId = _captureId;
    if (bytes == null ||
        predictedName == null ||
        confidence == null ||
        captureId == null ||
        _normalizedFoodName(predictedName) ==
            _normalizedFoodName(correctName)) {
      return;
    }
    try {
      await ref.read(foodCorrectionSampleStoreProvider).save(
            processedJpeg: bytes,
            correctFoodName: correctName,
            predictedFoodName: predictedName,
            confidence: confidence,
            captureId: captureId,
          );
      _correctionSampleBytes = null;
      await _tts.speak(
        'Yanlış tahmin düzeltmesi cihazda kaydedildi. Bu fotoğraf '
        'gelecekteki model iyileştirmesinde kullanılabilir.',
      );
    } on Object {
      // Besin kaydı başarılıysa yerel eğitim örneği hatası ana akışı bozmaz.
    }
  }

  String _normalizedFoodName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[ _-]+'), '');

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
    // Ortak erişilebilir diyalog: sesle söyleme, artır/azalt ve klavye.
    final grams = await showAccessibleNumberDialog(
      context: context,
      title: 'Gram miktarı',
      fieldLabel: 'Gram miktarını metin olarak girin',
      suffix: 'g',
      spokenUnit: 'gram',
      min: 1,
      max: 2000,
      step: 10,
      initialValue: initialGrams,
      helper: 'Yediğiniz miktarı gram cinsinden metin olarak girin.',
      fieldKey: const Key('portion_input'),
    );
    if (grams == null) return null;
    return PortionInput(value: grams, unit: 'gram');
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
    await _tts.prepareForSpeechInput();
    await _stt.startListening(
      listenFor: const Duration(seconds: 8),
      onResult: (result) {
        if (!result.isFinal) return;
        final input = parseTurkishPortion(result.text);
        if (input == null) {
          unawaited(_tts.speakError(
            'Porsiyon anlaşılamadı. Gram, adet, dilim veya kase ile tekrar söyleyin.',
          ));
          _tts.finishSpeechInput();
          return;
        }
        unawaited(_updatePortion(
          input.value,
          input.unit,
          method: 'user_voice',
        ));
        _tts.finishSpeechInput();
      },
      onError: (message) {
        _tts.finishSpeechInput();
        _tts.speakError(message);
      },
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
    if (!mounted) return;
    final nameDialog = showDialog<String>(
      context: context,
      builder: (_) => _ManualEntryDialog(initialText: candidate?.foodNameTr),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_tts.speak(
        'Besin adını metin olarak girin. Örneğin simit veya lahmacun.',
        priority: TtsPriority.high,
      ));
    });
    final value = await nameDialog;
    if (value == null || value.length < 2 || !mounted) return;
    final analysis = ref.read(cameraStateProvider).analysis;
    if (analysis != null) {
      // Eğitim örneği, ağdaki besin kaydı başarısız olsa da kaybolmamalıdır.
      // Kullanıcının doğru adı göndermesi açık düzeltme eylemidir.
      await _saveCorrectionSample(value);
      await _confirm(
        correctedName: value.toLowerCase().replaceAll(' ', '_'),
        correctedNameTr: value,
      );
      return;
    }
    if (!mounted) return;
    final amountDialog = showDialog<PortionInput>(
      context: context,
      builder: (_) => const _ManualAmountDialog(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_tts.speak(
        'Kaç adet yediğinizi metin olarak girin. İsterseniz gram seçeneğine geçebilirsiniz.',
        priority: TtsPriority.high,
      ));
    });
    final portion = await amountDialog;
    if (portion == null || !mounted) return;
    _captureId ??= _uuid.v4();
    final result = await ref.read(apiServiceProvider).createManualFoodLog(
          captureId: _captureId!,
          foodName: value.toLowerCase().replaceAll(' ', '_'),
          foodNameTr: value,
          portionValue: portion.value,
          portionUnit: portion.unit,
          portionMethod: 'user_selected',
          cancelToken: _requestCancelToken,
        );
    if (!mounted) return;
    if (result.isSuccess && result.data?.logId != null) {
      ref.read(cameraStateProvider.notifier).setSaved(result.data!.logId!);
      unawaited(ref.read(historyControllerProvider.notifier).refresh());
      await _tts.speak('Manuel yemek geçmişine kaydedildi.');
    } else {
      await _tts.speakError(
        result.errorMessage ?? 'Besin değeri bulunamadığı için kaydedilmedi.',
      );
    }
  }

  Future<void> _listenForDecision() async {
    await _tts.prepareForSpeechInput();
    await _stt.startListening(
      listenFor: const Duration(seconds: 8),
      onListeningStarted: () {
        if (!mounted) return;
        setState(() {
          _voiceListening = true;
          _voiceStatus =
              'Dinleniyor. Evet, hayır, tekrar çek veya seçenek söyleyin.';
        });
        unawaited(_tts.mediumHaptic());
      },
      onListeningStopped: () {
        _tts.finishSpeechInput();
        if (!mounted) return;
        setState(() => _voiceListening = false);
      },
      onResult: (result) {
        if (!result.isFinal) return;
        _tts.finishSpeechInput();
        final intent = _voiceParser.parse(
          result.text,
          context: VoiceInteractionContext.scanConfirmation,
        );
        if (!intent.accepted) {
          if (mounted) {
            setState(() => _voiceStatus =
                'Komut anlaşılmadı. Dokunmatik düğmeleri kullanabilir veya yeniden deneyebilirsiniz.');
          }
          unawaited(_tts.errorHaptic());
          return;
        }
        switch (intent.action!) {
          case ContextualVoiceAction.yes:
          case ContextualVoiceAction.save:
            unawaited(_confirm());
            break;
          case ContextualVoiceAction.no:
          case ContextualVoiceAction.cancel:
            unawaited(_reject());
            break;
          case ContextualVoiceAction.retake:
            _reset();
            break;
          case ContextualVoiceAction.firstOption:
          case ContextualVoiceAction.secondOption:
          case ContextualVoiceAction.thirdOption:
            final state = ref.read(cameraStateProvider);
            final candidates = state.analysis?.candidates ?? state.candidates;
            final index = switch (intent.action!) {
              ContextualVoiceAction.firstOption => 0,
              ContextualVoiceAction.secondOption => 1,
              _ => 2,
            };
            if (index < candidates.length) {
              if (state.analysis != null) {
                unawaited(_confirm(
                  correctedName: candidates[index].foodName,
                  correctedNameTr: candidates[index].foodNameTr,
                ));
              } else {
                unawaited(_showManualEntry(candidate: candidates[index]));
              }
            }
            break;
          case ContextualVoiceAction.setPortion:
            unawaited(_updatePortion(intent.portionGrams!, 'gram',
                method: 'user_voice'));
            break;
          case ContextualVoiceAction.back:
            if (mounted) Navigator.pop(context);
            break;
          default:
            break;
        }
      },
      onError: (message) {
        _tts.finishSpeechInput();
        if (mounted) {
          setState(() {
            _voiceListening = false;
            _voiceStatus =
                '$message. Mikrofon olmadan dokunmatik düğmeleri kullanabilirsiniz.';
          });
        }
        _tts.errorHaptic();
      },
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
    _correctionSampleBytes = null;
    _correctionPredictedName = null;
    _correctionPredictedConfidence = null;
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
          // Panel gerçekte kalan alanın yarısını geçemez: porsiyon seçici,
          // onay düğmeleri ve galeri düğmesi birlikte göründüğünde kısa
          // ekranlarda (Pixel 4) taşıyordu. Sınır MediaQuery'den değil
          // LayoutBuilder'dan alınır; MediaQuery boyutu verilmeyen
          // bağlamlarda sıfır dönebiliyor.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxPanel = constraints.hasBoundedHeight
                  ? constraints.maxHeight * 0.5
                  : double.infinity;
              return Column(
                children: [
                  _topBar(state),
                  Expanded(child: _cameraBody(state)),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxPanel),
                    child: _bottomPanel(state),
                  ),
                ],
              );
            },
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
    final previewReady = _initialized && _controller != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Önizleme hazır değilken bile analiz sonucu görünür kalmalıdır;
        // aksi halde kamera yeniden bağlanırken sonuç kartı kaybolur.
        if (!previewReady)
          Center(
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
          )
        else ...[
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
        ],
        if (previewReady && _busy(state.status))
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
        analysis == null ? state.candidates : _policy.candidates(analysis);
    return Container(
      color: const Color(0xEE000000),
      padding: const EdgeInsets.all(16),
      // Denetim alanı kaydırılabilir: porsiyon seçici, onay düğmeleri ve
      // galeri düğmesi birlikte göründüğünde kısa ekranlarda taşıyordu.
      // Ekran okuyucu kaydırılabilir içeriği gezebildiği için erişilebilirlik
      // korunur.
      child: SingleChildScrollView(
        // Alt boşluk, kaydırma sonundaki düğmenin tam görünür olmasını sağlar;
        // aksi hâlde ekranın kenarına yapışıp dokunma alanı kırpılıyor.
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_voiceStatus != null)
              Semantics(
                liveRegion: true,
                label: _voiceStatus,
                child: Text(
                  _voiceStatus!,
                  key: const Key('camera_voice_status'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
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
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final candidate in candidates)
                    ActionChip(
                      label: Text(candidate.foodNameTr),
                      onPressed: () => analysis == null
                          ? _showManualEntry(candidate: candidate)
                          : _confirm(
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
                    // Cihaz üstü modelde sunucudan gelen bir analiz yoktur;
                    // kalori değeri katalogdan çekileceği için onay, tanınan ad
                    // önceden doldurulmuş porsiyon akışına gider. Aksi hâlde
                    // ekran "onaylayın" der ama düğme çalışmaz.
                    onPressed: _saving
                        ? null
                        : analysis?.canConfirm == true
                            ? _confirm
                            : state.recognizedFood != null
                                ? () => _showManualEntry(
                                      candidate: FoodCandidate(
                                        foodName: state.recognizedFood!
                                            .toLowerCase()
                                            .replaceAll(' ', '_'),
                                        foodNameTr: state.recognizedFood!,
                                        confidence: state.confidence ?? 0,
                                      ),
                                    )
                                : null,
                  ),
                  AccessibleButton(
                    label: 'Yanlış Tahmini Düzelt',
                    semanticLabel:
                        'Yanlış tahmini düzelt ve doğru besin adını gir',
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
                    tooltip: _voiceListening
                        ? 'Sesli komut dinleniyor'
                        : 'Sesli evet, hayır, tekrar çek veya seçenek söyle',
                    onPressed: _listenForDecision,
                    icon: Icon(
                      _voiceListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
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
            // Galeri düğmesi kendi satırında değil, düğme grubunun içinde
            // durur: onay ekranında porsiyon seçici de görünürken ayrı bir tam
            // genişlik satırı kısa ekranlarda paneli taşırıyordu.
            if (!_busy(state.status) && state.status != CameraStatus.saved)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AccessibleButton(
                      label: 'Galeriden fotoğraf seç',
                      semanticLabel:
                          'Galeriden besin fotoğrafı seç ve analiz et',
                      icon: Icons.photo_library_outlined,
                      onPressed: _singleFlight || _saving || _portionUpdating
                          ? null
                          : () => _captureAndAnalyze(
                                automatic: false,
                                fromGallery: true,
                              ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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

/// Manuel besin adı girişi diyaloğu.
///
/// [TextEditingController] burada tutulur; böylece diyalog kapanma animasyonu
/// sürerken controller'ın atılıp "used after being disposed" hatası vermesi ve
/// bunun alt ağacı yıkarak `_dependents.isEmpty` assert'ini tetiklemesi önlenir.
class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog({this.initialText});

  final String? initialText;

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Besini manuel girin'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (text) => Navigator.pop(context, text.trim()),
        decoration: const InputDecoration(
          labelText: 'Besin adını metin olarak girin',
          hintText: 'Örnek: simit',
          helperText: 'Tanıyamadıysanız doğru besin adını buraya yazın.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// Manual scan fallback asks for a count first because foods such as lahmacun,
/// simit and fruit are naturally entered as pieces. Gram remains available for
/// foods that are not countable.
class _ManualAmountDialog extends StatefulWidget {
  const _ManualAmountDialog();

  @override
  State<_ManualAmountDialog> createState() => _ManualAmountDialogState();
}

class _ManualAmountDialogState extends State<_ManualAmountDialog> {
  final _controller = TextEditingController(text: '1');
  String _unit = 'adet';
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    final maximum = _unit == 'adet' ? 20 : 2000;
    if (value == null || !value.isFinite || value <= 0 || value > maximum) {
      setState(() => _error = _unit == 'adet'
          ? 'Adet sayısı 0 ile 20 arasında olmalıdır.'
          : 'Gram miktarı 0 ile 2000 arasında olmalıdır.');
      return;
    }
    Navigator.pop(context, PortionInput(value: value, unit: _unit));
  }

  @override
  Widget build(BuildContext context) {
    final isCount = _unit == 'adet';
    return AlertDialog(
      title: Text(isCount ? 'Kaç adet yediniz?' : 'Kaç gram yediniz?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Önce adet sayısını girin. Besin adetle ölçülmüyorsa gramı seçin.',
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'adet', label: Text('Adet')),
                ButtonSegment(value: 'gram', label: Text('Gram')),
              ],
              selected: {_unit},
              onSelectionChanged: (selection) {
                setState(() {
                  _unit = selection.first;
                  _controller.text = _unit == 'adet' ? '1' : '100';
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('manual_amount_input'),
              controller: _controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: isCount
                    ? 'Adet sayısını metin olarak girin'
                    : 'Gram miktarını metin olarak girin',
                suffixText: _unit,
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          key: const Key('manual_amount_save'),
          onPressed: _save,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
