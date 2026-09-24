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
  static const login = '/login';
  static const locked = '/locked';
  static const dietitianDashboard = '/dietitian-dashboard';
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
  static const accessibilitySettings = '/accessibility-settings';
  static const nutritionDetail = '/nutrition-detail';
}

const _routeGuides = <String, ScreenVoiceGuide>{
  VoiceGuideRoutes.login: ScreenVoiceGuide(
    'Kullanıcı girişi',
    'E-posta ve şifrenizi girip giriş yapabilir; hesap oluşturma, şifre yenileme veya diyetisyen girişini seçebilirsiniz.',
  ),
  VoiceGuideRoutes.locked: ScreenVoiceGuide(
    'Kilitli oturum',
    'Güvenliğiniz için oturum kilitlendi. Yeniden giriş yap seçeneğiyle giriş ekranına dönebilirsiniz.',
  ),
  VoiceGuideRoutes.dietitianDashboard: ScreenVoiceGuide(
    'Diyetisyen paneli',
    'Bekleyen danışan isteklerini, danışanları ve raporları inceleyebilir; arama alanlarıyla listeleri daraltabilirsiniz.',
  ),
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
  VoiceGuideRoutes.accessibilitySettings: ScreenVoiceGuide(
    'Erişilebilirlik ayarları',
    'Konuşma hızı, ses perdesi, titreşim ve sallayarak komut seçeneklerini düzenleyebilirsiniz.',
  ),
  VoiceGuideRoutes.nutritionDetail: ScreenVoiceGuide(
    'Besin ayrıntıları',
    'Besin adı, miktar, kalori ve besin değerlerini dinleyebilir; kaydet veya tekrar çek diyebilirsiniz.',
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
    _routeName = routeName ?? '/unnamed';
    final knownGuide = voiceGuideForRoute(_routeName);
    // A few feature routes are intentionally created without a name. They
    // still need the same microphone affordance so a screen is never a dead
    // end for a screen-reader user.
    _guide = knownGuide ??
        const ScreenVoiceGuide(
          'Bu ekran',
          'Başlıklar, alanlar, durumlar ve düğmeler ekran okuyucu sırasıyla okunur. Genel komutları öğrenmek için ne diyebilirim deyin.',
        );
    notifyListeners();
    if (announce) {
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

/// Navigator kullanılmadan, AuthGate içinde doğrudan değişen kök ekranlara
/// da aynı sesli rehber erişimini verir. Bu ekranlarda ortak rota gözlemcisi
/// yeni bir rota göremediği için rehber düğmesi ayrıca sağlanır.
class RootScreenVoiceGuideOverlay extends ConsumerStatefulWidget {
  const RootScreenVoiceGuideOverlay({
    super.key,
    required this.routeName,
    required this.child,
    this.announceOnOpen = true,
  });

  final String routeName;
  final Widget child;
  final bool announceOnOpen;

  @override
  ConsumerState<RootScreenVoiceGuideOverlay> createState() =>
      _RootScreenVoiceGuideOverlayState();
}

class _RootScreenVoiceGuideOverlayState
    extends ConsumerState<RootScreenVoiceGuideOverlay> {
  ScreenVoiceGuide? get _guide => voiceGuideForRoute(widget.routeName);

  @override
  void initState() {
    super.initState();
    if (widget.announceOnOpen) _announceAfterFrame();
  }

  @override
  void didUpdateWidget(covariant RootScreenVoiceGuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.announceOnOpen && oldWidget.routeName != widget.routeName) {
      _announceAfterFrame();
    }
  }

  void _announceAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _guide == null) return;
      unawaited(ref.read(accessibilityServiceProvider).speak(
            '${_guide!.title} ekranı. ${_guide!.instructions}',
            priority: TtsPriority.high,
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final guide = _guide;
    if (guide == null) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 16,
          bottom: 20,
          child: SafeArea(
            child: Semantics(
              button: true,
              label: '${guide.title} sesli rehberini dinle',
              hint: 'Bu ekrandaki alanları ve yapılabilecek işlemleri açıklar',
              child: FloatingActionButton.small(
                heroTag: 'root_voice_guide_${widget.routeName}',
                onPressed: () => ref.read(accessibilityServiceProvider).speak(
                      '${guide.title} ekranı. ${guide.instructions}',
                      priority: TtsPriority.high,
                      allowWhileScreenReaderActive: true,
                    ),
                tooltip: 'Ekran rehberini dinle',
                child: const Icon(Icons.record_voice_over_rounded),
              ),
            ),
          ),
        ),
      ],
    );
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
