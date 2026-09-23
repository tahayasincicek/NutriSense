import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accessibility_service.dart';
import 'voice_command_service.dart';

/// A short, action-oriented guide for a screen opened through Navigator.
class ScreenVoiceGuide {
  const ScreenVoiceGuide(this.title, this.instructions);

  final String title;
  final String instructions;

  String get announcement =>
      '$title ekranı. $instructions Yardımı yeniden dinlemek için uzun basın.';
}

/// Route names are kept in one place so every opened module receives the same
/// microphone and voice-guide behaviour.
abstract final class VoiceGuideRoutes {
  static const home = '/';
  static const settings = '/settings';
  static const manualFood = '/manual-food';
  static const camera = '/camera';
  static const article = '/article';
  static const category = '/category';
  static const register = '/register';
  static const passwordReset = '/password-reset';
  static const dietitianAccess = '/dietitian-access';
  static const verification = '/verification';
  static const privacy = '/privacy';
  static const survey = '/survey';
  static const usabilityTest = '/usability-test';
  static const emailChange = '/email-change';
  static const onboarding = '/onboarding';
  static const sendReport = '/send-report';
  static const reportDetail = '/report-detail';
  static const patientDetail = '/patient-detail';
  static const nutritionStats = '/nutrition-stats';
  static const foodShortcuts = '/food-shortcuts';
}

const _routeGuides = <String, ScreenVoiceGuide>{
  VoiceGuideRoutes.settings: ScreenVoiceGuide(
    'Ayarlar',
    'Erişilebilirlik, hesap, gizlilik ve beslenme tercihlerini düzenleyebilirsiniz.',
  ),
  VoiceGuideRoutes.manualFood: ScreenVoiceGuide(
    'Manuel besin girişi',
    'Besin adını arayın, miktarı seçin ve kaydedin.',
  ),
  VoiceGuideRoutes.camera: ScreenVoiceGuide(
    'Kamera ile besin tarama',
    'Besini çerçevenin ortasına getirin; çekim veya galeriden seçme düğmesini kullanın.',
  ),
  VoiceGuideRoutes.article: ScreenVoiceGuide(
    'Beslenme içeriği',
    'Metni kaydırarak okuyabilir, hoparlör düğmesiyle yeniden dinleyebilirsiniz.',
  ),
  VoiceGuideRoutes.category: ScreenVoiceGuide(
    'Tarif kategorisi',
    'Bir tarif veya makale seçerek ayrıntılarını açabilirsiniz.',
  ),
  VoiceGuideRoutes.register: ScreenVoiceGuide(
    'Hesap oluşturma',
    'Form alanlarını doldurun, sözleşmeleri okuyup kabul edin ve devam edin.',
  ),
  VoiceGuideRoutes.passwordReset: ScreenVoiceGuide(
    'Şifre yenileme',
    'E-posta adresinizi yazıp doğrulama adımlarını izleyin.',
  ),
  VoiceGuideRoutes.dietitianAccess: ScreenVoiceGuide(
    'Diyetisyen girişi',
    'Diyetisyen hesabınızla giriş yapabilir veya kayıt olabilirsiniz.',
  ),
  VoiceGuideRoutes.verification: ScreenVoiceGuide(
    'E-posta doğrulama',
    'E-postanıza gelen kodu girin veya kodu yeniden gönderin.',
  ),
  VoiceGuideRoutes.privacy: ScreenVoiceGuide(
    'Gizlilik ve açık rıza',
    'Metinleri okuyun; tercihlerinizi ayrı ayrı seçip kaydedin.',
  ),
  VoiceGuideRoutes.survey: ScreenVoiceGuide(
    'Kullanıcı anketi',
    'Soruları sırayla yanıtlayıp anketi gönderebilirsiniz.',
  ),
  VoiceGuideRoutes.usabilityTest: ScreenVoiceGuide(
    'Kullanılabilirlik testi',
    'Görevleri sırayla tamamlayıp sonuçları kaydedebilirsiniz.',
  ),
  VoiceGuideRoutes.emailChange: ScreenVoiceGuide(
    'E-posta değiştirme',
    'Yeni adresinizi girin ve doğrulama adımlarını tamamlayın.',
  ),
  VoiceGuideRoutes.onboarding: ScreenVoiceGuide(
    'Uygulama rehberi',
    'Sayfalar arasında ilerleyerek temel özellikleri dinleyebilirsiniz.',
  ),
  VoiceGuideRoutes.sendReport: ScreenVoiceGuide(
    'Rapor hazırlama',
    'Tarih aralığını ve bildirim kanallarını seçip raporu onaylayın.',
  ),
  VoiceGuideRoutes.reportDetail: ScreenVoiceGuide(
    'Rapor ayrıntıları',
    'Besin kayıtlarını ve diyetisyen yanıtını güvenli panelde inceleyebilirsiniz.',
  ),
  VoiceGuideRoutes.patientDetail: ScreenVoiceGuide(
    'Danışan ayrıntıları',
    'Danışanın izin verdiği kayıtları ve rapor geçmişini inceleyebilirsiniz.',
  ),
  VoiceGuideRoutes.nutritionStats: ScreenVoiceGuide(
    'Beslenme istatistikleri',
    'Kalori ve besin dağılımı özetini inceleyebilirsiniz.',
  ),
  VoiceGuideRoutes.foodShortcuts: ScreenVoiceGuide(
    'Besin kısayolları',
    'Sık tüketilenleri yeniden ekleyebilir veya son işlemi geri alabilirsiniz.',
  ),
};

/// Exposed for route coverage tests and for screens that want to present the
/// same guide visually without starting TTS.
ScreenVoiceGuide? voiceGuideForRoute(String routeName) =>
    _routeGuides[routeName];

class ScreenVoiceGuideController extends ChangeNotifier {
  ScreenVoiceGuideController(this._accessibility);

  final AccessibilityService _accessibility;
  String _routeName = VoiceGuideRoutes.home;
  ScreenVoiceGuide? _guide;

  String get routeName => _routeName;
  ScreenVoiceGuide? get guide => _guide;
  // Wrapping a Navigator route in an additional Stack corrupts some routes on
  // older Mali GPUs (including the Galaxy S8) and paints the whole route red.
  // Camera and manual food entry own contextual microphones inside their
  // screens, so neither needs this global compositing layer.
  bool get showGlobalMicrophone =>
      _routeName != VoiceGuideRoutes.home &&
      _routeName != VoiceGuideRoutes.camera &&
      _routeName != VoiceGuideRoutes.manualFood;

  Future<void> showRoute(String? routeName, {bool announce = true}) async {
    _routeName = routeName ?? VoiceGuideRoutes.home;
    _guide = voiceGuideForRoute(_routeName);
    notifyListeners();
    if (announce && _guide != null) {
      await _accessibility.speak(
        _guide!.announcement,
        priority: TtsPriority.normal,
      );
    }
  }

  Future<void> repeat() async {
    final current = _guide;
    if (current != null) {
      await _accessibility.speak(
        current.announcement,
        priority: TtsPriority.high,
        allowWhileScreenReaderActive: true,
      );
    }
  }
}

class ScreenVoiceGuideObserver extends NavigatorObserver {
  ScreenVoiceGuideObserver(this.controller);

  final ScreenVoiceGuideController controller;

  void _schedule(String? routeName) {
    // Navigator can report its initial route while Riverpod is still building
    // the provider listeners. Update after that frame to keep state consistent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(controller.showRoute(routeName));
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _schedule(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _schedule(previousRoute?.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _schedule(newRoute?.settings.name);
  }
}

final screenVoiceGuideControllerProvider =
    ChangeNotifierProvider<ScreenVoiceGuideController>((ref) {
  return ScreenVoiceGuideController(ref.read(accessibilityServiceProvider));
});

/// Places the same microphone over every secondary Navigator page.
class GlobalVoiceGuideOverlay extends ConsumerWidget {
  const GlobalVoiceGuideOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(screenVoiceGuideControllerProvider);
    if (!guide.showGlobalMicrophone || guide.guide == null) return child;

    final service = ref.read(voiceCommandServiceProvider);
    return Stack(
      children: [
        child,
        Positioned(
          right: 16,
          bottom: 24,
          child: SafeArea(
            child: Semantics(
              button: true,
              label: 'Sesli komut mikrofonu',
              hint: 'Uzun basınca bu ekranın rehberini yeniden okur',
              child: GestureDetector(
                onLongPress: guide.repeat,
                child: FloatingActionButton.small(
                  heroTag: 'global_voice_guide_microphone',
                  onPressed: service.toggleListening,
                  tooltip: 'Sesli komut; uzun basınca ekran rehberi',
                  child: const Icon(Icons.mic_none_rounded),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
