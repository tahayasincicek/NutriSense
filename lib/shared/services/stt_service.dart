// =============================================================================
// lib/shared/services/stt_service.dart
// NutriSense — Speech-to-Text (STT) Servisi
//
// speech_to_text paketini kullanarak Türkçe sesli komut tanıma.
// Mikrofon dinleme, metin dönüşümü ve güven skoru yönetimi.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'speech_locale_policy.dart';

/// STT dinleme durumu
enum SttState { idle, listening, processing, error }

/// STT sonucu
class SttResult {
  final String text;
  final double confidence;
  final bool isFinal;

  const SttResult({
    required this.text,
    required this.confidence,
    required this.isFinal,
  });

  @override
  String toString() =>
      'SttResult(text: "$text", confidence: $confidence, isFinal: $isFinal)';
}

/// STT servisi — ses-metin dönüştürücü
///
/// Kullanım:
/// ```dart
/// final stt = ref.read(sttServiceProvider);
/// await stt.initialize();
/// await stt.startListening(
///   onResult: (result) => print(result.text),
///   onError: (error) => print('Hata: $error'),
/// );
/// ```
class SttService {
  final SpeechToText _stt = SpeechToText();
  SttState _state = SttState.idle;
  bool _isInitialized = false;
  String? _turkishLocaleId;
  String? _initializationError;

  SttState get state => _state;
  bool get isListening => _state == SttState.listening;
  bool get isAvailable => _isInitialized;

  // Callback'ler
  void Function(SttResult)? _onResult;
  void Function(String)? _onError;
  void Function()? _onListeningStarted;
  void Function()? _onListeningStopped;

  // ---------------------------------------------------------------------------
  // BAŞLATMA
  // ---------------------------------------------------------------------------

  /// STT motorunu başlatır. Mikrofon izni gereklidir.
  /// Başarılıysa true döner.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    final microphoneStatus = await Permission.microphone.request();
    if (!microphoneStatus.isGranted) {
      _state = SttState.error;
      _initializationError =
          'Mikrofon izni verilmedi. Dokunmatik veya klavye ile devam edin.';
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final speechStatus = await Permission.speech.request();
      if (!speechStatus.isGranted) {
        _state = SttState.error;
        _initializationError =
            'Konuşma tanıma izni verilmedi. Dokunmatik veya klavye ile devam edin.';
        return false;
      }
    }

    _isInitialized = await _stt.initialize(
      onStatus: _handleStatus,
      onError: _handleError,
      debugLogging: false,
    );
    if (_isInitialized) {
      final locales = await _stt.locales();
      _turkishLocaleId = selectTurkishSpeechLocale(
        locales.map((locale) => locale.localeId),
      );
    }

    return _isInitialized;
  }

  // ---------------------------------------------------------------------------
  // DİNLEME
  // ---------------------------------------------------------------------------

  /// Mikrofonu açar ve dinlemeye başlar.
  ///
  /// [onResult] — her tanıma sonucunda çağrılır
  /// [onError] — hata durumunda çağrılır
  /// [locale] — dil kodu (varsayılan: tr-TR)
  /// [listenFor] — maksimum dinleme süresi
  Future<void> startListening({
    required void Function(SttResult) onResult,
    void Function(String)? onError,
    void Function()? onListeningStarted,
    void Function()? onListeningStopped,
    String? locale,
    Duration listenFor = const Duration(seconds: 30),
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        onError?.call(_initializationError ?? 'Ses tanıma başlatılamadı');
        return;
      }
    }

    // Callback'leri kaydet
    _onResult = onResult;
    _onError = onError;
    _onListeningStarted = onListeningStarted;
    _onListeningStopped = onListeningStopped;

    final requestedLocale = locale ?? _turkishLocaleId;
    if (requestedLocale == null) {
      _state = SttState.error;
      onError?.call(
        'Türkçe konuşma tanıma bu cihazda bulunamadı. '
        'Dokunmatik veya klavye ile devam edin.',
      );
      return;
    }

    _state = SttState.listening;
    _onListeningStarted?.call();

    await _stt.listen(
      onResult: _handleResult,
      listenOptions: SpeechListenOptions(
        localeId: requestedLocale,
        listenFor: listenFor,
        pauseFor: const Duration(seconds: 3), // 3 saniye sessizlikte dur
        listenMode: ListenMode.confirmation,
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  /// Dinlemeyi durdurur.
  Future<void> stopListening() async {
    await _stt.stop();
    _state = SttState.idle;
    _onListeningStopped?.call();
  }

  /// Dinlemeyi iptal eder (sonuç vermeden).
  Future<void> cancelListening() async {
    await _stt.cancel();
    _state = SttState.idle;
    _onListeningStopped?.call();
  }

  // ---------------------------------------------------------------------------
  // DİL DESTEĞİ
  // ---------------------------------------------------------------------------

  /// Mevcut dillerin listesini döner.
  Future<List<Map<String, String>>> getAvailableLocales() async {
    if (!_isInitialized) return [];
    final locales = await _stt.locales();
    return locales.map((l) => {'id': l.localeId, 'name': l.name}).toList();
  }

  // ---------------------------------------------------------------------------
  // DAHİLİ İŞLEYİCİLER (internal handlers)
  // ---------------------------------------------------------------------------

  void _handleResult(SpeechRecognitionResult result) {
    final sttResult = SttResult(
      text: result.recognizedWords,
      confidence: result.confidence,
      isFinal: result.finalResult,
    );

    if (result.finalResult) {
      _state = SttState.idle;
    }

    _onResult?.call(sttResult);
  }

  void _handleStatus(String status) {
    switch (status) {
      case 'listening':
        _state = SttState.listening;
        break;
      case 'notListening':
        _state = SttState.idle;
        _onListeningStopped?.call();
        break;
      case 'done':
        _state = SttState.idle;
        _onListeningStopped?.call();
        break;
    }
  }

  void _handleError(SpeechRecognitionError error) {
    _state = SttState.error;
    final message = _errorToTurkish(error.errorMsg);
    _onError?.call(message);
  }

  /// İngilizce hata mesajını Türkçe'ye çevirir
  String _errorToTurkish(String error) {
    switch (error) {
      case 'error_no_match':
        return 'Konuşma anlaşılamadı, lütfen tekrar deneyin';
      case 'error_speech_timeout':
        return 'Konuşma algılanamadı, zaman aşımı';
      case 'error_audio':
        return 'Ses kaydı hatası, mikrofonu kontrol edin';
      case 'error_permission':
        return 'Mikrofon izni verilmedi';
      case 'error_network':
        return 'Ağ bağlantısı hatası';
      case 'error_busy':
        return 'Ses tanıma meşgul, lütfen bekleyin';
      default:
        return 'Ses tanıma hatası: $error';
    }
  }

  /// Kaynakları serbest bırakır.
  void dispose() {
    _stt.cancel();
    _onResult = null;
    _onError = null;
    _onListeningStarted = null;
    _onListeningStopped = null;
  }
}

// =============================================================================
// RIVERPOD PROVIDER
// =============================================================================

/// STT servisi provider'ı — uygulama genelinde tek instance
final sttServiceProvider = Provider<SttService>((ref) {
  final service = SttService();
  ref.onDispose(() => service.dispose());
  return service;
});
