import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';
import 'package:nutrisense/shared/services/voice_command_service.dart';
import 'package:nutrisense/shared/services/voice_help_service.dart';

/// Görme engelli kullanıcı ekranı göremez; bu yüzden hiçbir yönerge konum
/// tarif etmemeli ("mikrofon düğmesine basın" gibi) ve her ana işlev tek
/// sesli komutla tamamlanabilmelidir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final help = VoiceHelpService(AccessibilityService());

  group('Sesle tam kontrol', () {
    test('ana işlevlerin hepsinin sesli komutu var', () {
      // Kullanıcının düğme aramadan yapabilmesi gereken işler.
      final required = {
        'besin ekleme': VoiceCommand.logFood,
        'kamera taraması': VoiceCommand.scan,
        'su ekleme': VoiceCommand.addWater,
        'uyku kaydı': VoiceCommand.logSleep,
        'kilo kaydı': VoiceCommand.logWeight,
        'geçmişi dinleme': VoiceCommand.history,
        'yardım': VoiceCommand.help,
      };

      for (final entry in required.entries) {
        expect(
          entry.value.aliases,
          isNotEmpty,
          reason: '${entry.key} için sesli komut tanımlı değil',
        );
      }
    });

    test('besin ekleme komutu doğal söyleyişleri tanır', () {
      for (final phrase in ['besin ekle', 'yemek ekle', 'yemek kaydet']) {
        expect(
          VoiceCommand.logFood.aliases.contains(phrase),
          isTrue,
          reason: '"$phrase" tanınmıyor',
        );
      }
    });

    test('yardım metni her ekranda besin eklemeyi anlatır', () {
      for (final context in HelpContext.values) {
        expect(
          help.helpText(context),
          contains(VoiceCommand.logFood.aliases.first),
          reason: '${context.name} ekranında besin ekleme komutu duyurulmuyor',
        );
      }
    });
  });

  group('Yönergeler konum tarif etmez', () {
    // Ekranı göremeyen kullanıcı için "sağ üstteki düğme" gibi ifadeler
    // hiçbir şey ifade etmez; yönerge eylemi anlatmalı.
    final forbidden = [
      'düğmesine basın',
      'butonuna basın',
      'düğmesini kullan',
      'ekranın altındaki',
      'sağ üst',
      'sol üst',
      'aşağıdaki düğme',
    ];

    test('sesli yardım metinlerinde konum tarifi yok', () {
      for (final context in HelpContext.values) {
        final text = help.helpText(context).toLowerCase();
        for (final phrase in forbidden) {
          expect(
            text.contains(phrase),
            isFalse,
            reason: '${context.name} yardımında konum tarifi var: "$phrase"',
          );
        }
      }
    });
  });
}
