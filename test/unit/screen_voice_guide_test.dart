import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';
import 'package:nutrisense/shared/services/screen_voice_guide.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every secondary module route has a useful voice guide', () {
    const routes = <String>[
      VoiceGuideRoutes.login,
      VoiceGuideRoutes.locked,
      VoiceGuideRoutes.dietitianDashboard,
      VoiceGuideRoutes.settings,
      VoiceGuideRoutes.manualFood,
      VoiceGuideRoutes.camera,
      VoiceGuideRoutes.article,
      VoiceGuideRoutes.category,
      VoiceGuideRoutes.register,
      VoiceGuideRoutes.passwordReset,
      VoiceGuideRoutes.dietitianAccess,
      VoiceGuideRoutes.verification,
      VoiceGuideRoutes.privacy,
      VoiceGuideRoutes.survey,
      VoiceGuideRoutes.usabilityTest,
      VoiceGuideRoutes.emailChange,
      VoiceGuideRoutes.onboarding,
      VoiceGuideRoutes.sendReport,
      VoiceGuideRoutes.reportDetail,
      VoiceGuideRoutes.patientDetail,
      VoiceGuideRoutes.nutritionStats,
      VoiceGuideRoutes.foodShortcuts,
      VoiceGuideRoutes.accessibilitySettings,
      VoiceGuideRoutes.nutritionDetail,
    ];

    for (final route in routes) {
      final guide = voiceGuideForRoute(route);
      expect(guide, isNotNull, reason: 'Missing guide for $route');
      expect(guide!.announcement, contains('ekranı'));
      expect(guide.announcement, contains('uzun basın'));
    }
  });

  test('adı olmayan rota da güvenli ve doğru bir rehber alır', () async {
    final controller = ScreenVoiceGuideController(AccessibilityService());
    await controller.showRoute(null, announce: false);

    expect(controller.guide, isNotNull);
    expect(controller.guide!.announcement, contains('ekran okuyucu'));
    expect(controller.showGlobalMicrophone, isTrue);
  });

  testWidgets('kök ekran sesli rehber düğmesi erişilebilir ad taşır',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RootScreenVoiceGuideOverlay(
            routeName: VoiceGuideRoutes.login,
            announceOnOpen: false,
            child: Scaffold(body: Text('Giriş içeriği')),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Ekran rehberini dinle'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Kullanıcı girişi sesli rehberini dinle'),
      findsOneWidget,
    );
  });
}
