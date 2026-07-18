import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/contextual_voice_command.dart';

void main() {
  const parser = ContextualVoiceCommandParser();

  group('bağlama duyarlı sesli komut güvenliği', () {
    test('evet global bağlamda hiçbir eylem tetiklemez', () {
      final result = parser.parse(
        'evet',
        context: VoiceInteractionContext.globalNavigation,
      );
      expect(result.accepted, isFalse);
      expect(result.action, isNull);
    });

    test('evet yalnız etkin tarama onayında kabul edilir', () {
      final result = parser.parse(
        'evet',
        context: VoiceInteractionContext.scanConfirmation,
      );
      expect(result.accepted, isTrue);
      expect(result.action, ContextualVoiceAction.yes);
      expect(result.isExact, isTrue);
    });

    test('tehlikeli rapor gönder komutu fuzzy yazımla tetiklenmez', () {
      final result = parser.parse(
        'rapor gondarr',
        context: VoiceInteractionContext.reportConsent,
      );
      expect(result.accepted, isFalse);
    });

    test('tam rapor gönder komutu ikinci onay ister', () {
      final result = parser.parse(
        'rapor gönder',
        context: VoiceInteractionContext.reportConsent,
      );
      expect(result.action, ContextualVoiceAction.sendReport);
      expect(result.isExact, isTrue);
      expect(result.requiresSecondConfirmation, isTrue);
    });

    test('silme komutu geçmiş dışındaki bağlamda reddedilir', () {
      final result = parser.parse(
        'kaydı sil',
        context: VoiceInteractionContext.globalNavigation,
      );
      expect(result.accepted, isFalse);
    });

    test('aday ve porsiyon komutları gerçek değer taşır', () {
      final option = parser.parse(
        'birinci seçenek',
        context: VoiceInteractionContext.scanConfirmation,
      );
      final portion = parser.parse(
        'porsiyon 150 gram',
        context: VoiceInteractionContext.scanConfirmation,
      );
      expect(option.action, ContextualVoiceAction.firstOption);
      expect(portion.action, ContextualVoiceAction.setPortion);
      expect(portion.portionGrams, 150);
    });

    test('güvenli tara komutu küçük yazım hatasını tolere eder', () {
      final result = parser.parse(
        'tarra',
        context: VoiceInteractionContext.globalNavigation,
      );
      expect(result.action, ContextualVoiceAction.scan);
      expect(result.isExact, isFalse);
    });
  });

  group('kritik eylem ikinci onay kapısı', () {
    test('yalnız tam evet bekleyen eylemi bir kez çözer', () {
      final gate = VoiceConfirmationGate();
      gate.request(ContextualVoiceAction.sendReport);
      final fuzzy = parser.parse(
        'evett',
        context: VoiceInteractionContext.reportSendConfirmation,
      );
      expect(gate.resolve(fuzzy), isNull);
      expect(gate.isActive, isTrue);

      final exact = parser.parse(
        'evet',
        context: VoiceInteractionContext.reportSendConfirmation,
      );
      expect(gate.resolve(exact), ContextualVoiceAction.sendReport);
      expect(gate.resolve(exact), isNull);
    });

    test('hayır bekleyen kritik eylemi temizler', () {
      final gate = VoiceConfirmationGate();
      gate.request(ContextualVoiceAction.deleteEntry);
      final no = parser.parse(
        'hayır',
        context: VoiceInteractionContext.historyDeleteConfirmation,
      );
      expect(gate.resolve(no), isNull);
      expect(gate.isActive, isFalse);
    });

    test('timeout sonrası evet eylem üretmez', () async {
      final gate = VoiceConfirmationGate(
        timeout: const Duration(milliseconds: 1),
      );
      gate.request(ContextualVoiceAction.sendReport);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final yes = parser.parse(
        'evet',
        context: VoiceInteractionContext.reportSendConfirmation,
      );
      expect(gate.resolve(yes), isNull);
      expect(gate.isActive, isFalse);
    });
  });
}
