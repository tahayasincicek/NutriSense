// =============================================================================
// lib/shared/services/tts_service.dart
// NutriSense — Text-to-Speech (TTS) Servisi
//
// flutter_tts paketini kullanarak Türkçe ve İngilizce sesli geri bildirim.
// Singleton pattern ile uygulama genelinde tek instance.
// =============================================================================

import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';

/// TTS durumu
enum TtsState { playing, stopped, paused }

/// TTS servisi — metin-ses dönüştürücü
///
/// Kullanım:
/// ```dart
/// final tts = ref.read(ttsServiceProvider);
/// await tts.speak('Elma tanındı, 78 kalori');
/// ```
class TtsService {
  final FlutterTts _tts = FlutterTts();
  TtsState _state = TtsState.stopped;

  TtsState get state => _state;
  bool get isSpeaking => _state == TtsState.playing;

  // ---------------------------------------------------------------------------
  // BAŞLATMA
  // ---------------------------------------------------------------------------

  /// TTS motorunu yapılandır ve başlat.
  /// Uygulama başlangıcında çağrılmalı.
  Future<void> initialize() async {
    // Dil ayarı — Türkçe
    await _tts.setLanguage(AppConstants.defaultLocale);

    // Ses hızı, ton ve ses seviyesi
    await _tts.setSpeechRate(AppConstants.defaultTtsSpeed);
    await _tts.setPitch(AppConstants.defaultTtsPitch);
    await _tts.setVolume(AppConstants.defaultTtsVolume);

    // iOS özel ayarları
    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }

    // Durum dinleyicileri
    _tts.setStartHandler(() => _state = TtsState.playing);
    _tts.setCompletionHandler(() => _state = TtsState.stopped);
    _tts.setCancelHandler(() => _state = TtsState.stopped);
    _tts.setPauseHandler(() => _state = TtsState.paused);
    _tts.setContinueHandler(() => _state = TtsState.playing);
    _tts.setErrorHandler((msg) {
      _state = TtsState.stopped;
    });
  }

  // ---------------------------------------------------------------------------
  // KONUŞMA
  // ---------------------------------------------------------------------------

  /// Verilen metni sesli olarak okur.
  /// Eğer hâlâ konuşuyorsa, önce durdurur.
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (_state == TtsState.playing) {
      await stop();
    }
    await _tts.speak(text);
  }

  /// Besin tanıma sonucunu sesli olarak bildirir.
  /// Format: "{besin adı} tanındı. {porsiyon} gram, {kalori} kalori."
  Future<void> speakFoodResult({
    required String foodName,
    required double calories,
    required double portionGrams,
    double? protein,
    double? carbs,
    double? fat,
  }) async {
    final buffer = StringBuffer();
    buffer.write('$foodName tanındı. ');
    buffer.write('${portionGrams.toStringAsFixed(0)} gram, ');
    buffer.write('${calories.toStringAsFixed(0)} kalori. ');

    if (protein != null) {
      buffer.write('${protein.toStringAsFixed(0)} gram protein, ');
    }
    if (carbs != null) {
      buffer.write('${carbs.toStringAsFixed(0)} gram karbonhidrat, ');
    }
    if (fat != null) {
      buffer.write('${fat.toStringAsFixed(0)} gram yağ.');
    }

    await speak(buffer.toString());
  }

  /// Günlük kalori özetini sesli olarak bildirir.
  Future<void> speakDailySummary({
    required double totalCalories,
    required double targetCalories,
    required int mealCount,
  }) async {
    final remaining = targetCalories - totalCalories;
    final buffer = StringBuffer();
    buffer.write('Günlük özet: ');
    buffer
        .write('Toplam ${totalCalories.toStringAsFixed(0)} kalori tüketildi. ');
    buffer.write('$mealCount öğün kaydedildi. ');

    if (remaining > 0) {
      buffer.write('Hedefinize ${remaining.toStringAsFixed(0)} kalori kaldı.');
    } else {
      buffer.write(
          'Günlük hedefinizi ${(-remaining).toStringAsFixed(0)} kalori aştınız.');
    }

    await speak(buffer.toString());
  }

  /// Hata mesajını sesli olarak bildirir.
  Future<void> speakError(String error) async {
    await speak('Hata: $error');
  }

  // ---------------------------------------------------------------------------
  // KONTROL
  // ---------------------------------------------------------------------------

  /// Konuşmayı durdurur.
  Future<void> stop() async {
    await _tts.stop();
    _state = TtsState.stopped;
  }

  /// Konuşmayı duraklatır.
  Future<void> pause() async {
    await _tts.pause();
    _state = TtsState.paused;
  }

  // ---------------------------------------------------------------------------
  // AYARLAR
  // ---------------------------------------------------------------------------

  /// Konuşma hızını ayarlar (0.0 - 1.0).
  Future<void> setSpeed(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  /// Konuşma dilini değiştirir.
  Future<void> setLanguage(String locale) async {
    await _tts.setLanguage(locale);
  }

  /// Ses tonunu ayarlar (0.5 - 2.0).
  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
  }

  /// Ses seviyesini ayarlar (0.0 - 1.0).
  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Mevcut dillerin listesini döner.
  Future<List<String>> getAvailableLanguages() async {
    final languages = await _tts.getLanguages;
    return List<String>.from(languages ?? []);
  }

  /// Kaynakları serbest bırakır.
  void dispose() {
    _tts.stop();
  }
}

// =============================================================================
// RIVERPOD PROVIDER
// =============================================================================

/// TTS servisi provider'ı — uygulama genelinde tek instance
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(() => service.dispose());
  return service;
});
