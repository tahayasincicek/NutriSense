import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';
import 'package:nutrisense/shared/services/voice_command_service.dart';
import 'package:nutrisense/shared/services/voice_help_service.dart';

void main() {
  // AccessibilityService kurucusu TTS platform kanalını açtığı için binding
  // gerekiyor; helpText'in kendisi saf bir fonksiyon, TTS'e dokunmuyor.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Sesli yardım, görme engelli kullanıcının "ne diyebilirim?" sorusuna tek
  // cevabı. Bağlam yanlışsa kullanıcı olmayan bir komutu dener ve tıkanır.
  final help = VoiceHelpService(AccessibilityService());

  test('sekme sırası doğru bağlama eşlenir', () {
    expect(HelpContext.fromTabIndex(0), HelpContext.scan);
    expect(HelpContext.fromTabIndex(1), HelpContext.activity);
    expect(HelpContext.fromTabIndex(2), HelpContext.history);
    expect(HelpContext.fromTabIndex(3), HelpContext.discover);
    expect(HelpContext.fromTabIndex(4), HelpContext.dietitian);
  });

  test('yardım metni bulunulan ekranı adıyla duyurur', () {
    expect(help.helpText(HelpContext.scan), startsWith('Besin tarama ekranı'));
    expect(
      help.helpText(HelpContext.history),
      startsWith('Beslenme günlüğü ekranı'),
    );
  });

  test('her bağlam kendi komutlarını içerir', () {
    final activity = help.helpText(HelpContext.activity);
    expect(activity, contains(VoiceCommand.addWater.aliases.first));
    expect(activity, contains(VoiceCommand.logWeight.aliases.first));

    final dietitian = help.helpText(HelpContext.dietitian);
    expect(dietitian, contains(VoiceCommand.send.aliases.first));
  });

  test('global komutlar her ekranda okunur', () {
    for (final context in HelpContext.values) {
      final text = help.helpText(context);
      expect(text, contains(VoiceCommand.scan.aliases.first),
          reason: '${context.name} ekranında tara komutu eksik');
      expect(text, contains(VoiceCommand.settings.aliases.first),
          reason: '${context.name} ekranında ayarlar komutu eksik');
    }
  });

  test('komut adı tekrar etmez', () {
    // "tara" hem bağlama özgü hem global listede; iki kez okunmamalı.
    final text = help.helpText(HelpContext.scan);
    final commandList = text.split('Şunları söyleyebilirsiniz: ')[1];
    final phrases = commandList.split('.').first.split(', ');
    expect(phrases.toSet().length, phrases.length,
        reason: 'Yinelenen komut var: $phrases');
  });

  test('yardım kendini yeniden çağırmayı öğretir', () {
    for (final context in HelpContext.values) {
      expect(help.helpText(context), contains('ne diyebilirim'));
    }
  });
}
