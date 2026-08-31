// =============================================================================
// lib/shared/services/voice_help_service.dart
// NutriSense — Sesli Yardım ("ne diyebilirim?")
//
// Görme engelli kullanıcı, ekranda ne olduğunu göremediği için hangi komutların
// geçerli olduğunu da göremez. Bu servis, bulunulan sekmeye göre kullanılabilir
// komutları tek bir yerden üretir ve sesli olarak okur.
//
// Komut listesi VoiceCommand enum'undan türetilir; yeni bir komut eklendiğinde
// yardım metni kendiliğinden güncel kalır, ayrıca elle güncellenmesi gerekmez.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accessibility_service.dart';
import 'voice_command_service.dart';

/// Yardımın hangi ekran için üretileceğini belirtir.
enum HelpContext {
  scan('Besin tarama'),
  activity('Aktivite ve su takibi'),
  history('Beslenme günlüğü'),
  discover('Keşfet'),
  dietitian('Diyetisyen');

  const HelpContext(this.screenName);
  final String screenName;

  /// Sekme sırasına göre bağlam. AppShell'deki IndexedStack ile aynı sıra.
  static HelpContext fromTabIndex(int index) => switch (index) {
        0 => HelpContext.scan,
        1 => HelpContext.activity,
        2 => HelpContext.history,
        3 => HelpContext.discover,
        _ => HelpContext.dietitian,
      };
}

/// Her yerde geçerli olan komutlar.
const _globalCommands = <VoiceCommand>[
  VoiceCommand.logFood,
  VoiceCommand.scan,
  VoiceCommand.history,
  VoiceCommand.today,
  VoiceCommand.settings,
  VoiceCommand.cancel,
];

/// Ekrana özgü ek komutlar.
const _contextCommands = <HelpContext, List<VoiceCommand>>{
  HelpContext.scan: [VoiceCommand.logFood, VoiceCommand.scan],
  HelpContext.activity: [
    VoiceCommand.addWater,
    VoiceCommand.logSleep,
    VoiceCommand.logWeight,
    VoiceCommand.setMood,
  ],
  HelpContext.history: [VoiceCommand.today, VoiceCommand.send],
  HelpContext.discover: [],
  HelpContext.dietitian: [VoiceCommand.send],
};

/// Ekranda sesle değil, dokunarak yapılan işler için kısa ipuçları.
const _contextTips = <HelpContext, String>{
  HelpContext.scan:
      'Tara diyerek kamerayı açabilir, ya da besin ekle deyip adını '
          'söyleyerek doğrudan kaydedebilirsiniz.',
  HelpContext.activity:
      'Değerleri tek cümlede söyleyebilirsiniz; örneğin uyku kaydet yedi '
          'buçuk, ya da su içtim diyebilirsiniz.',
  HelpContext.history: 'Bugün diyerek günlük özetinizi dinleyebilirsiniz. '
      'Silinen kayıt geri alınabilir.',
  HelpContext.discover: 'Tarif ve beslenme ipuçlarını dinleyebilirsiniz.',
  HelpContext.dietitian:
      'Gönder diyerek raporunuzu diyetisyeninize iletebilirsiniz.',
};

class VoiceHelpService {
  const VoiceHelpService(this._accessibility);

  final AccessibilityService _accessibility;

  /// Verilen bağlam için okunacak yardım metnini üretir.
  ///
  /// Ayrı bir metot olarak durur ki testler sesli okuma yapmadan içeriği
  /// doğrulayabilsin.
  String helpText(HelpContext context) {
    final commands = <VoiceCommand>[
      ..._contextCommands[context] ?? const [],
      ..._globalCommands,
    ];

    // Aynı komut hem bağlama özgü hem global listede olabilir; sırayı koruyarak
    // yineleyenleri ayıklıyoruz.
    final seen = <VoiceCommand>{};
    final unique = commands.where(seen.add).toList();
    final phrases = unique.map((command) => command.aliases.first).join(', ');

    final buffer = StringBuffer()
      ..write('${context.screenName} ekranındasınız. ')
      ..write('Şunları söyleyebilirsiniz: $phrases. ');

    final tip = _contextTips[context];
    if (tip != null && tip.isNotEmpty) buffer.write('$tip ');

    buffer.write(
      'Sekme adını söyleyerek doğrudan geçebilirsiniz. '
      'Yardımı yeniden dinlemek için ne diyebilirim deyin.',
    );
    return buffer.toString();
  }

  /// Yardımı sesli okur. Kullanıcı yolunu kaybettiğinde başvurduğu yol
  /// olduğu için diğer duyuruların önüne geçer.
  Future<void> announce(HelpContext context) {
    return _accessibility.speak(
      helpText(context),
      priority: TtsPriority.high,
      allowWhileScreenReaderActive: true,
    );
  }
}

final voiceHelpServiceProvider = Provider<VoiceHelpService>((ref) {
  return VoiceHelpService(ref.watch(accessibilityServiceProvider));
});
