import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/screen_voice_guide.dart';

void main() {
  test('every secondary module route has a useful voice guide', () {
    const routes = <String>[
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
    ];

    for (final route in routes) {
      final guide = voiceGuideForRoute(route);
      expect(guide, isNotNull, reason: 'Missing guide for $route');
      expect(guide!.announcement, contains('ekranı'));
      expect(guide.announcement, contains('uzun basın'));
    }
  });
}
