// =============================================================================
// lib/shared/services/voice_command_service.dart
// NutriSense — Sesli Komut Tanıma Servisi
//
// speech_to_text ile Türkçe sesli komut tanıma.
// Fuzzy matching ile yaklaşık eşleşme.
// Komut yönlendirme + haptic onay + TTS geri bildirim.
//
// Desteklenen komutlar:
//   "Tara"     → kamera ekranını aç
//   "Geçmiş"   → kalori geçmişini sesli oku
//   "Bugün"    → günlük özeti sesli oku
//   "Gönder"   → diyetisyene rapor gönder
//   "İptal"    → mevcut işlemi iptal et
//   "Ayarlar"  → ayarlar ekranını aç
//   "Yardım"   → komut listesini oku
// =============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import '../../core/constants/app_strings.dart';
import 'accessibility_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KOMUT TANIMLARI
// ═══════════════════════════════════════════════════════════════════════════════

/// Tanınan sesli komut
enum VoiceCommand {
  scan('Tara', [
    'tara',
    'besin tara',
    'tarama',
    'taramaya başla',
    'yiyecek tara',
    'kamera'
  ]),
  history('Geçmiş',
      ['geçmiş', 'geçmişimi göster', 'geçmişim', 'ne yedim', 'yemeklerim']),
  today(
      'Bugün', ['bugün', 'bugün ne yedim', 'bugünkü', 'günlük özet', 'günlük']),
  send('Gönder',
      ['gönder', 'diyetisyene gönder', 'rapor gönder', 'raporla', 'paylaş']),
  cancel('İptal', ['iptal', 'iptal et', 'vazgeç', 'durdur', 'bırak']),
  settings('Ayarlar', ['ayarlar', 'ayarları aç', 'tercihler', 'seçenekler']),
  help('Yardım', ['yardım', 'komutlar', 'ne yapabilirim', 'ne diyebilirim']),
  yes('Evet', ['evet', 'tamam', 'olur', 'kabul', 'kaydet', 'onayla']),
  no('Hayır', ['hayır', 'yok', 'istemiyorum', 'reddet']);

  const VoiceCommand(this.displayName, this.aliases);
  final String displayName;
  final List<String> aliases;
}

/// Komut tanıma sonucu
class CommandResult {
  final VoiceCommand? command;
  final double confidence;
  final String rawText;
  final bool recognized;

  const CommandResult({
    this.command,
    this.confidence = 0,
    required this.rawText,
    this.recognized = false,
  });
}

/// Komut dinleme durumu
enum ListeningState { idle, listening, processing }

// ═══════════════════════════════════════════════════════════════════════════════
// CALLBACK TİPLERİ
// ═══════════════════════════════════════════════════════════════════════════════

typedef OnCommandRecognized = void Function(VoiceCommand command);
typedef OnListeningStateChanged = void Function(ListeningState state);

// ═══════════════════════════════════════════════════════════════════════════════
// ANA SERVİS
// ═══════════════════════════════════════════════════════════════════════════════

class VoiceCommandService {
  final AccessibilityService _accessibility;
  final stt.SpeechToText _speech = stt.SpeechToText();

  // ── Durum ──
  bool _isInitialized = false;
  ListeningState _listeningState = ListeningState.idle;
  Timer? _restartTimer;
  Timer? _timeoutTimer;

  // ── Callback'ler ──
  OnCommandRecognized? onCommandRecognized;
  OnListeningStateChanged? onListeningStateChanged;

  // ── Ayarlar ──
  static const _listenTimeout = Duration(seconds: 10);
  static const _restartDelay = Duration(seconds: 2);
  static const _minConfidence = 0.4; // Fuzzy match eşiği
  bool _continuousMode = false;

  VoiceCommandService({required AccessibilityService accessibility})
      : _accessibility = accessibility;

  ListeningState get listeningState => _listeningState;
  bool get isListening => _listeningState == ListeningState.listening;
  bool get isInitialized => _isInitialized;

  // ─────────────────────────────────────────────────────────────────────────
  // BAŞLATMA
  // ─────────────────────────────────────────────────────────────────────────

  /// Sesli komut servisini başlatır
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final microphoneStatus = await Permission.microphone.request();
      if (!microphoneStatus.isGranted) {
        await _accessibility.speakError(
          AppStrings.errorMicrophonePermission,
        );
        return false;
      }

      _isInitialized = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: false,
      );

      if (_isInitialized) {
        // Türkçe locale kontrol
        final locales = await _speech.locales();
        final hasTurkish = locales.any(
          (l) => l.localeId.startsWith('tr'),
        );

        if (!hasTurkish) {
          await _accessibility.speakWarning(
            'Türkçe ses tanıma bu cihazda desteklenmiyor olabilir.',
          );
        }
      } else {
        await _accessibility.speakError(
          AppStrings.errorMicrophonePermission,
        );
      }

      return _isInitialized;
    } catch (e) {
      await _accessibility.speakError(
        'Sesli komut başlatılamadı. $e',
      );
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DİNLEME KONTROL
  // ─────────────────────────────────────────────────────────────────────────

  /// Tek seferlik dinleme başlatır
  Future<void> startListening() async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    await _accessibility.prepareForSpeechInput();
    _setListeningState(ListeningState.listening);
    await _accessibility.lightHaptic();

    await _speech.listen(
      onResult: _onResult,
      listenFor: _listenTimeout,
      pauseFor: const Duration(seconds: 3),
      localeId: 'tr_TR',
      listenMode: stt.ListenMode.confirmation,
      cancelOnError: false,
      partialResults: true,
    );
  }

  /// Sürekli dinleme modunu başlatır (pil tüketimine dikkat!)
  Future<void> startContinuousListening() async {
    _continuousMode = true;
    await startListening();
  }

  /// Dinlemeyi durdurur
  Future<void> stopListening() async {
    _continuousMode = false;
    _restartTimer?.cancel();
    _timeoutTimer?.cancel();

    if (_speech.isListening) {
      await _speech.stop();
    }

    _setListeningState(ListeningState.idle);
    _accessibility.finishSpeechInput();
  }

  /// Dinleme/durdurma geçişi
  Future<void> toggleListening() async {
    if (isListening) {
      await stopListening();
      await _accessibility.speakInfo(AppStrings.listeningStopped);
    } else {
      await startListening();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SONUÇ İŞLEME
  // ─────────────────────────────────────────────────────────────────────────

  void _onResult(SpeechRecognitionResult result) {
    if (!result.finalResult) return; // Sadece final sonuçları işle

    final text = result.recognizedWords.toLowerCase().trim();
    _accessibility.finishSpeechInput();
    if (text.isEmpty) {
      _setListeningState(ListeningState.idle);
      return;
    }
    _setListeningState(ListeningState.processing);

    // Fuzzy matching ile komut ara
    final cmdResult = matchCommand(text);

    if (cmdResult.recognized && cmdResult.command != null) {
      _handleRecognizedCommand(cmdResult);
    } else {
      _handleUnrecognizedCommand(text);
    }

    // Sürekli modda tekrar dinlemeye başla
    if (_continuousMode) {
      _restartTimer?.cancel();
      _restartTimer = Timer(_restartDelay, () {
        if (_continuousMode) startListening();
      });
    } else {
      _setListeningState(ListeningState.idle);
    }
  }

  void _handleRecognizedCommand(CommandResult result) {
    final cmd = result.command!;

    // Haptic onay
    _accessibility.mediumHaptic();

    // Sesli onay
    _accessibility.speak(
      AppStrings.commandRecognized(cmd.displayName),
      priority: TtsPriority.high,
    );

    // Callback
    onCommandRecognized?.call(cmd);
  }

  void _handleUnrecognizedCommand(String text) {
    _accessibility.speak(
      AppStrings.commandNotRecognized,
      priority: TtsPriority.normal,
    );
    _accessibility.lightHaptic();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FUZZY MATCHING
  // ─────────────────────────────────────────────────────────────────────────

  /// Metin ile en iyi eşleşen komutu bulur (fuzzy matching)
  CommandResult matchCommand(String input) {
    final normalized = _normalize(input);
    if (normalized.isEmpty) {
      return CommandResult(rawText: input, recognized: false);
    }

    VoiceCommand? bestCommand;
    double bestScore = 0;

    for (final command in VoiceCommand.values) {
      for (final alias in command.aliases) {
        final normalizedAlias = _normalize(alias);

        // 1. Tam eşleşme
        if (normalized == normalizedAlias) {
          return CommandResult(
            command: command,
            confidence: 1.0,
            rawText: input,
            recognized: true,
          );
        }

        // 2. İçeriyor mu (substring)
        if (normalized.contains(normalizedAlias) ||
            normalizedAlias.contains(normalized)) {
          final score = 0.85;
          if (score > bestScore) {
            bestScore = score;
            bestCommand = command;
          }
          continue;
        }

        // 3. Levenshtein mesafesi (fuzzy)
        final distance = _levenshteinDistance(normalized, normalizedAlias);
        final maxLen = max(normalized.length, normalizedAlias.length);
        if (maxLen == 0) continue;

        final similarity = 1.0 - (distance / maxLen);
        if (similarity > bestScore && similarity >= _minConfidence) {
          bestScore = similarity;
          bestCommand = command;
        }
      }
    }

    if (bestCommand != null && bestScore >= _minConfidence) {
      return CommandResult(
        command: bestCommand,
        confidence: bestScore,
        rawText: input,
        recognized: true,
      );
    }

    return CommandResult(rawText: input, recognized: false);
  }

  /// Metni normalize eder — Türkçe karakterleri standartlaştırır
  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\sçğıöşüâîû]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Levenshtein edit mesafesi — iki string arasındaki minimum düzenleme sayısı
  int _levenshteinDistance(String s, String t) {
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final sLen = s.length;
    final tLen = t.length;
    var previous = List.generate(tLen + 1, (i) => i);
    var current = List.filled(tLen + 1, 0);

    for (var i = 1; i <= sLen; i++) {
      current[0] = i;
      for (var j = 1; j <= tLen; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        current[j] = [
          previous[j] + 1, // silme
          current[j - 1] + 1, // ekleme
          previous[j - 1] + cost, // değiştirme
        ].reduce(min);
      }
      final temp = previous;
      previous = current;
      current = temp;
    }

    return previous[tLen];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DURUM VE HATA
  // ─────────────────────────────────────────────────────────────────────────

  void _setListeningState(ListeningState state) {
    _listeningState = state;
    onListeningStateChanged?.call(state);
  }

  void _onStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      _accessibility.finishSpeechInput();
      if (!_continuousMode) _setListeningState(ListeningState.idle);
    }
    if (status == 'notListening' && _continuousMode) {
      _restartTimer?.cancel();
      _restartTimer = Timer(_restartDelay, () {
        if (_continuousMode) startListening();
      });
    }
  }

  void _onError(SpeechRecognitionError error) {
    _accessibility.finishSpeechInput();
    if (error.permanent) {
      _accessibility.speakError(
        'Sesli tanıma kalıcı olarak başarısız oldu. '
        'Mikrofon izinlerini kontrol edin.',
      );
      _setListeningState(ListeningState.idle);
    } else if (_continuousMode) {
      // Geçici hata — yeniden dene
      _restartTimer?.cancel();
      _restartTimer = Timer(_restartDelay, () {
        if (_continuousMode) startListening();
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TEMİZLİK
  // ─────────────────────────────────────────────────────────────────────────

  /// Kaynakları serbest bırakır
  void dispose() {
    _continuousMode = false;
    _restartTimer?.cancel();
    _timeoutTimer?.cancel();
    if (_speech.isListening) {
      _speech.stop();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RIVERPOD PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

final voiceCommandServiceProvider = Provider<VoiceCommandService>((ref) {
  final accessibility = ref.read(accessibilityServiceProvider);
  final service = VoiceCommandService(accessibility: accessibility);
  ref.onDispose(() => service.dispose());
  return service;
});
