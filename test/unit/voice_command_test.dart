// =============================================================================
// test/unit/voice_command_test.dart
// NutriSense — Sesli Komut Eşleştirme Birim Testleri
//
// VoiceCommandService.matchCommand() fuzzy matching testleri.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';
import 'package:nutrisense/shared/services/voice_command_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VoiceCommandService service;

  setUp(() {
    // Not: Gerçek testlerde mock AccessibilityService kullanılır.
    // Burada sadece matchCommand() pure fonksiyonunu test ediyoruz.
    service = VoiceCommandService(
      accessibility: AccessibilityService(),
    );
  });

  group('VoiceCommandService — matchCommand()', () {
    // ═══════════════════════════════════════════════════════════════════════
    // TAM EŞLEŞME
    // ═══════════════════════════════════════════════════════════════════════

    group('tam eşleşme', () {
      test('"tara" → VoiceCommand.scan', () {
        final result = service.matchCommand('tara');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.scan);
        expect(result.confidence, 1.0);
      });

      test('"geçmiş" → VoiceCommand.history', () {
        final result = service.matchCommand('geçmiş');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.history);
      });

      test('"bugün" → VoiceCommand.today', () {
        final result = service.matchCommand('bugün');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.today);
      });

      test('"gönder" → VoiceCommand.send', () {
        final result = service.matchCommand('gönder');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.send);
      });

      test('"iptal" → VoiceCommand.cancel', () {
        final result = service.matchCommand('iptal');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.cancel);
      });

      test('"yardım" → VoiceCommand.help', () {
        final result = service.matchCommand('yardım');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.help);
      });

      test('"evet" → VoiceCommand.yes', () {
        final result = service.matchCommand('evet');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.yes);
      });

      test('"hayır" → VoiceCommand.no', () {
        final result = service.matchCommand('hayır');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.no);
      });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // ALİAS (ALTERNATİF KOMUTLAR)
    // ═══════════════════════════════════════════════════════════════════════

    group('alias eşleşme', () {
      test('"besin tara" → scan', () {
        final result = service.matchCommand('besin tara');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.scan);
      });

      test('"geçmişimi göster" → history', () {
        final result = service.matchCommand('geçmişimi göster');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.history);
      });

      test('"bugün ne yedim" → today', () {
        final result = service.matchCommand('bugün ne yedim');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.today);
      });

      test('"diyetisyene gönder" → send', () {
        final result = service.matchCommand('diyetisyene gönder');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.send);
      });

      test('"ne yapabilirim" → help', () {
        final result = service.matchCommand('ne yapabilirim');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.help);
      });

      test('"tamam" → yes', () {
        final result = service.matchCommand('tamam');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.yes);
      });

      test('"vazgeç" → cancel', () {
        final result = service.matchCommand('vazgeç');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.cancel);
      });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // FUZZY MATCHING
    // ═══════════════════════════════════════════════════════════════════════

    group('fuzzy eşleşme', () {
      test('"tarra" (yazım hatası) → scan (fuzzy)', () {
        final result = service.matchCommand('tarra');
        // Levenshtein: "tarra" vs "tara" = 1 mesafe, benzerlik = 0.80
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.scan);
      });

      test('"gecmiş" (ç eksik) → history (fuzzy)', () {
        final result = service.matchCommand('gecmiş');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.history);
      });

      test('"gonder" (ö eksik) → send (fuzzy)', () {
        final result = service.matchCommand('gonder');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.send);
      });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // TANINMAYAN KOMUTLAR
    // ═══════════════════════════════════════════════════════════════════════

    group('tanınmayan komutlar', () {
      test('"hava nasıl" → tanınmadı', () {
        final result = service.matchCommand('hava nasıl');
        expect(result.recognized, false);
        expect(result.command, isNull);
      });

      test('boş metin → tanınmadı', () {
        final result = service.matchCommand('');
        expect(result.recognized, false);
      });

      test('"sadkjfhaskdjfh" (anlamsız) → tanınmadı', () {
        final result = service.matchCommand('sadkjfhaskdjfh');
        expect(result.recognized, false);
      });

      test('"merhaba dünya" → tanınmadı', () {
        final result = service.matchCommand('merhaba dünya');
        expect(result.recognized, false);
      });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // BÜYÜK/KÜÇÜK HARF
    // ═══════════════════════════════════════════════════════════════════════

    group('büyük/küçük harf duyarsızlık', () {
      test('"TARA" → scan', () {
        final result = service.matchCommand('TARA');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.scan);
      });

      test('"Geçmiş" → history', () {
        final result = service.matchCommand('Geçmiş');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.history);
      });

      test('"BUGÜN NE YEDİM" → today', () {
        final result = service.matchCommand('BUGÜN NE YEDİM');
        expect(result.recognized, true);
        expect(result.command, VoiceCommand.today);
      });
    });
  });
}
