// =============================================================================
// lib/shared/services/accessibility_service.dart
// NutriSense — Erişilebilirlik Ana Servisi
//
// Öncelikli TTS kuyruğu, haptic desenleri, lifecycle yönetimi.
// Görme engelli kullanıcılar için tek merkezi erişilebilirlik servisi.
//
// Özellikler:
//   - Öncelik sistemi: CRITICAL > HIGH > NORMAL > LOW
//   - SharedPreferences ile kullanıcı tercihleri
//   - Uygulama arka plana geçince TTS'i duraklat
//   - Kulaklık durumu takibi
//   - Haptic feedback desenleri
// =============================================================================

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ÖNCELİK SEVİYELERİ
// ═══════════════════════════════════════════════════════════════════════════════

/// TTS mesaj öncelik seviyeleri
enum TtsPriority {
  /// Acil — hatalar, uyarılar. Mevcut sesi KESER ve anında çalar.
  critical(4),

  /// Yüksek — sonuçlar, durum değişiklikleri. Kuyrukta öne geçer.
  high(3),

  /// Normal — bildirimler, yönergeler. Sırayla çalar.
  normal(2),

  /// Düşük — ipuçları, opsiyonel bilgiler. Sadece kuyruk boşsa çalar.
  low(1);

  const TtsPriority(this.value);
  final int value;
}

/// TTS kuyruğundaki mesaj
class _TtsMessage implements Comparable<_TtsMessage> {
  final String text;
  final TtsPriority priority;
  final int sequence;

  _TtsMessage(this.text, this.priority, this.sequence);

  @override
  int compareTo(_TtsMessage other) {
    // Yüksek öncelik önce, aynı öncelikte ekleme sırasına göre
    final priComp = other.priority.value.compareTo(priority.value);
    if (priComp != 0) return priComp;
    return sequence.compareTo(other.sequence);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREFERENCES KEYS
// ═══════════════════════════════════════════════════════════════════════════════

class _PrefKeys {
  static const speechRate = 'accessibility_speech_rate';
  static const pitch = 'accessibility_pitch';
  static const volume = 'accessibility_volume';
  static const vibrationEnabled = 'accessibility_vibration';
  static const autoReadDelay = 'accessibility_auto_read_delay';
  static const highContrast = 'accessibility_high_contrast';
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANA SERVİS
// ═══════════════════════════════════════════════════════════════════════════════

/// NutriSense erişilebilirlik ana servisi
class AccessibilityService with WidgetsBindingObserver {
  final FlutterTts _tts = FlutterTts();
  SharedPreferences? _prefs;

  // ── Durum ──
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _isAppInForeground = true;
  bool _screenReaderActive = false;
  bool _speechInputActive = false;
  bool _observerRegistered = false;
  final ValueNotifier<String?> _ttsFailure = ValueNotifier<String?>(null);

  // ── Öncelikli kuyruk ──
  final SplayTreeSet<_TtsMessage> _messageQueue = SplayTreeSet<_TtsMessage>();
  bool _isProcessingQueue = false;
  int _nextMessageSequence = 0;

  // ── Ayarlar (varsayılanlar) ──
  double _speechRate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;
  bool _vibrationEnabled = true;
  double _autoReadDelay = 0.5; // saniye
  bool _highContrast = true;

  // ── Getter'lar ──
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  double get volume => _volume;
  bool get vibrationEnabled => _vibrationEnabled;
  double get autoReadDelay => _autoReadDelay;
  bool get highContrast => _highContrast;
  bool get screenReaderActive => _screenReaderActive;
  bool get speechInputActive => _speechInputActive;
  String? get ttsFailureReason => _ttsFailure.value;
  ValueListenable<String?> get ttsFailureListenable => _ttsFailure;

  // ─────────────────────────────────────────────────────────────────────────
  // BAŞLATMA
  // ─────────────────────────────────────────────────────────────────────────

  /// Servisi başlatır: TTS motoru + tercihleri yükler.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }

    // Tercihleri yükle
    _prefs = await SharedPreferences.getInstance();
    _loadPreferences();

    try {
      // TTS konfigürasyonu
      final languageAvailable = await _tts.isLanguageAvailable('tr-TR');
      if (languageAvailable == true) {
        await _tts.setLanguage('tr-TR');
        _setTtsFailure(null);
      } else {
        _setTtsFailure('Türkçe metin okuma sesi bu cihazda bulunamadı.');
      }
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      await _tts.setVolume(_volume);
      await _tts.awaitSpeakCompletion(true);

      // iOS ayarları. Android motorları bu çağrıyı yok sayar.
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    } catch (_) {
      _setTtsFailure(
        'Metin okuma servisi başlatılamadı. Dokunma ve ekran okuyucu ile devam edebilirsiniz.',
      );
    }

    // Durum dinleyicileri
    _tts.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _processQueue(); // Kuyruktaki sıradaki mesajı çal
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _tts.setPauseHandler(() {
      _isSpeaking = false;
      _isPaused = true;
    });

    _tts.setContinueHandler(() {
      _isSpeaking = true;
      _isPaused = false;
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      _setTtsFailure('Metin okuma motoru konuşmayı tamamlayamadı.');
    });

    _isInitialized = true;
  }

  void _loadPreferences() {
    _speechRate = _prefs?.getDouble(_PrefKeys.speechRate) ?? 0.5;
    _pitch = _prefs?.getDouble(_PrefKeys.pitch) ?? 1.0;
    _volume = _prefs?.getDouble(_PrefKeys.volume) ?? 1.0;
    _vibrationEnabled = _prefs?.getBool(_PrefKeys.vibrationEnabled) ?? true;
    _autoReadDelay = _prefs?.getDouble(_PrefKeys.autoReadDelay) ?? 0.5;
    _highContrast = _prefs?.getBool(_PrefKeys.highContrast) ?? true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ÖNCELİKLİ KONUŞMA
  // ─────────────────────────────────────────────────────────────────────────

  /// Metni öncelik seviyesine göre seslendirir.
  ///
  /// - [TtsPriority.critical]: Mevcut sesi KESER, anında çalar.
  /// - [TtsPriority.high]: Kuyruğun ÖNÜNE eklenir.
  /// - [TtsPriority.normal]: Kuyruğa sırayla eklenir.
  /// - [TtsPriority.low]: Sadece kuyruk boş ve ses yokken çalar.
  Future<void> speak(
    String text, {
    TtsPriority priority = TtsPriority.normal,
    bool allowWhileScreenReaderActive = false,
  }) async {
    if (text.isEmpty || !_isInitialized) return;
    if (!_isAppInForeground && priority != TtsPriority.critical) return;
    if (_speechInputActive || _ttsFailure.value != null) return;
    if (_screenReaderActive && !allowWhileScreenReaderActive) return;

    if (priority == TtsPriority.critical) {
      // Kritik: hemen kes ve çal
      await stop();
      _messageQueue.clear();
      _isSpeaking = true;
      await _tts.speak(text);
      _isSpeaking = false;
      if (_vibrationEnabled) await heavyHaptic();
      return;
    }

    if (priority == TtsPriority.low &&
        (_isSpeaking || _messageQueue.isNotEmpty)) {
      // Düşük öncelik: kuyruk doluysa atla
      return;
    }

    // SplayTreeSet karşılaştırması kimlik görevi de görür. Monoton sıra numarası,
    // aynı öncelikte aynı anda eklenen iki farklı duyurunun kaybolmasını önler.
    _messageQueue.add(_TtsMessage(text, priority, _nextMessageSequence++));
    _processQueue();
  }

  /// Kuyruktaki mesajları sırayla çalar
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _isSpeaking || _messageQueue.isEmpty) return;
    _isProcessingQueue = true;

    while (_messageQueue.isNotEmpty && _isAppInForeground) {
      final message = _messageQueue.first;
      _messageQueue.remove(message);

      _isSpeaking = true;
      await _tts.speak(message.text);
      _isSpeaking = false;
    }

    _isProcessingQueue = false;
  }

  /// Tüm konuşmayı durdurur ve kuyruğu temizler.
  Future<void> stop() async {
    _messageQueue.clear();
    await _tts.stop();
    _isSpeaking = false;
    _isPaused = false;
    _isProcessingQueue = false;
  }

  /// Ekran okuyucu etkinse otomatik TTS'i susturur ve çift konuşmayı önler.
  void setScreenReaderActive(bool active) {
    if (_screenReaderActive == active) return;
    _screenReaderActive = active;
    if (active && _isInitialized) unawaited(stop());
  }

  /// STT mikrofonunu açmadan önce bütün TTS çıkışını ve kuyruğu durdurur.
  Future<void> prepareForSpeechInput() async {
    _speechInputActive = true;
    if (_isInitialized) await stop();
  }

  /// STT tamamlandığında TTS kuyruğunun yeniden kullanılabilmesini sağlar.
  void finishSpeechInput() {
    _speechInputActive = false;
  }

  void _setTtsFailure(String? reason) {
    if (_ttsFailure.value == reason) return;
    _ttsFailure.value = reason;
  }

  /// Konuşmayı duraklatır.
  Future<void> pause() async {
    await _tts.pause();
  }

  /// Duraklatılmış konuşmayı devam ettirir.
  Future<void> resume() async {
    // FlutterTts'de doğrudan resume yok — ama iOS'ta pause/continue var
    _isPaused = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KISA YOLLAR
  // ─────────────────────────────────────────────────────────────────────────

  /// Kritik hata mesajı — anında çalar
  Future<void> speakError(String message) =>
      speak('Hata: $message', priority: TtsPriority.critical);

  /// Uyarı mesajı
  Future<void> speakWarning(String message) =>
      speak(message, priority: TtsPriority.high);

  /// Bilgi mesajı
  Future<void> speakInfo(String message) =>
      speak(message, priority: TtsPriority.normal);

  /// İpucu mesajı (kuyruk boşsa çalar)
  Future<void> speakHint(String message) =>
      speak(message, priority: TtsPriority.low);

  // ─────────────────────────────────────────────────────────────────────────
  // AYARLAR
  // ─────────────────────────────────────────────────────────────────────────

  /// Konuşma hızı: 0.0 = en yavaş, 1.0 = en hızlı
  /// UI'da gösterim: 0.5x – 2.0x
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    await _tts.setSpeechRate(_speechRate);
    await _prefs?.setDouble(_PrefKeys.speechRate, _speechRate);
  }

  /// Ses tonu: 0.5 – 2.0
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
    await _prefs?.setDouble(_PrefKeys.pitch, _pitch);
  }

  /// Ses seviyesi: 0.0 – 1.0
  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
    await _prefs?.setDouble(_PrefKeys.volume, _volume);
  }

  /// Titreşim aç/kapat
  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    await _prefs?.setBool(_PrefKeys.vibrationEnabled, enabled);
  }

  /// Otomatik okuma gecikmesi (0 – 3 saniye)
  Future<void> setAutoReadDelay(double seconds) async {
    _autoReadDelay = seconds.clamp(0.0, 3.0);
    await _prefs?.setDouble(_PrefKeys.autoReadDelay, _autoReadDelay);
  }

  /// Yüksek kontrast mod
  Future<void> setHighContrast(bool enabled) async {
    _highContrast = enabled;
    await _prefs?.setBool(_PrefKeys.highContrast, enabled);
  }

  /// UI'da gösterilecek hız etiketi (0.5x - 2.0x)
  String get speechRateLabel {
    final displayRate = 0.5 + (_speechRate * 1.5); // 0.0→0.5x, 1.0→2.0x
    return '${displayRate.toStringAsFixed(1)}x';
  }

  /// UI'da gösterilecek ton etiketi
  String get pitchLabel {
    if (_pitch < 0.8) return 'Kalın';
    if (_pitch < 1.2) return 'Normal';
    return 'İnce';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // YAŞAM DÖNGÜSÜ
  // ─────────────────────────────────────────────────────────────────────────

  /// Uygulama arka plana geçtiğinde çağrılır
  void onAppPaused() {
    _isAppInForeground = false;
    if (_isSpeaking) {
      _tts.stop();
      _isSpeaking = false;
    }
  }

  /// Uygulama öne geldiğinde çağrılır
  void onAppResumed() {
    _isAppInForeground = true;
    // Kuyruktakileri devam ettir
    if (_messageQueue.isNotEmpty) {
      _processQueue();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onAppResumed();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        onAppPaused();
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HAPTİK GERİ BİLDİRİM
  // ─────────────────────────────────────────────────────────────────────────

  /// Hafif titreşim — bilgi, ipucu
  Future<void> lightHaptic() async {
    if (!_vibrationEnabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Orta titreşim — onay, başarı
  Future<void> mediumHaptic() async {
    if (!_vibrationEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Ağır titreşim — hata, kritik uyarı
  Future<void> heavyHaptic() async {
    if (!_vibrationEnabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// Çift titreşim — sonuç hazır
  Future<void> doubleHaptic() async {
    if (!_vibrationEnabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
  }

  /// Başarı deseni — üçlü yumuşak titreşim
  Future<void> successHaptic() async {
    if (!_vibrationEnabled) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }

  /// Hata deseni — tek uzun titreşim
  Future<void> errorHaptic() async {
    if (!_vibrationEnabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.heavyImpact();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TEMİZLİK
  // ─────────────────────────────────────────────────────────────────────────

  /// Kaynakları serbest bırakır
  void dispose() {
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
    _messageQueue.clear();
    _tts.stop();
    _ttsFailure.dispose();
    _isInitialized = false;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RIVERPOD PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

/// Uygulama genelinde tek AccessibilityService instance'ı
final accessibilityServiceProvider = Provider<AccessibilityService>((ref) {
  final service = AccessibilityService();
  ref.onDispose(() => service.dispose());
  return service;
});
