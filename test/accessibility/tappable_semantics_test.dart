import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/auth/screens/login_screen.dart';
import 'package:nutrisense/features/auth/screens/password_reset_screen.dart';
import 'package:nutrisense/features/auth/screens/privacy_consent_screen.dart';
import 'package:nutrisense/features/auth/screens/register_screen.dart';
import 'package:nutrisense/features/dietitian/screens/dietitian_access_screen.dart';
import 'package:nutrisense/features/discover/screens/discover_screen.dart';
import 'package:nutrisense/features/food_scan/screens/food_scan_screen.dart';
import 'package:nutrisense/features/food_scan/screens/manual_food_entry_screen.dart';
import 'package:nutrisense/features/settings/screens/accessibility_settings_screen.dart';
import 'package:nutrisense/features/survey/screens/survey_screen.dart';
import 'package:nutrisense/features/water_tracker/screens/water_tracker_screen.dart';
import 'package:nutrisense/features/dietitian/screens/dietitian_screen.dart';
import 'package:nutrisense/features/history/screens/nutrition_stats_screen.dart';
import 'package:nutrisense/features/settings/screens/settings_screen.dart';

import '../support/platform_channel_mocks.dart';

/// Dokunulabilir her ögenin ekran okuyucuya söyleyecek bir adı olmalıdır.
///
/// Görme engelli kullanıcı parmağını ekranda gezdirir; ekran okuyucu altındaki
/// ögenin adını okur. Adı olmayan bir düğme yalnız "düğme" diye okunur ve
/// kullanıcı neye dokunduğunu anlayamaz.
///
/// `scripts/qa/tappable_label_audit.py` kaynak kodu tarar; bu test ise
/// çalışan uygulamanın semantik ağacına bakar. İkincisi gerçek kanıttır,
/// çünkü etiketin çalışma anında gerçekten üretildiğini gösterir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(mockSecureStorage);

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  Widget app(Widget home) => ProviderScope(
        child: MaterialApp(theme: AppTheme.lightTheme, home: home),
      );

  /// Adı boş olan dokunulabilir düğümlerin okunabilir listesini üretir.
  List<String> unnamedTappables(SemanticsNode root) {
    final offenders = <String>[];

    void visit(SemanticsNode node, String path) {
      final data = node.getSemanticsData();
      final tappable = data.hasAction(SemanticsAction.tap) ||
          data.hasFlag(SemanticsFlag.isButton);
      // Metin alanları adını ipucu/etiket yerine değerinden alabilir.
      final isField = data.hasFlag(SemanticsFlag.isTextField);
      final named = data.label.trim().isNotEmpty ||
          data.tooltip.trim().isNotEmpty ||
          (isField && data.value.trim().isNotEmpty);

      if (tappable && !named) {
        // Yol, en yakın adlandırılmış atayı gösterir; hangi denetimin adsız
        // kaldığını aramadan bulmayı sağlar.
        offenders.add('${node.rect.size} (yakın: $path)');
      }
      node.visitChildren((child) {
        final childLabel = child.getSemanticsData().label.trim();
        visit(child, childLabel.isEmpty ? path : childLabel);
        return true;
      });
    }

    visit(root, 'kök');
    return offenders;
  }

  Future<void> expectAllTappablesNamed(WidgetTester tester, Widget home) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(home));
    await tester.pumpAndSettle();

    final offenders = unnamedTappables(
      tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!,
    );

    expect(
      offenders,
      isEmpty,
      reason: 'Adsız dokunulabilir öge ekran okuyucuda "düğme" diye okunur: '
          '${offenders.join(", ")}',
    );
    handle.dispose();

    // Bazı ekranlar açılışta gecikmeli seslendirme kurar. Zaman ilerletilip
    // ekran kapatılmazsa test bitiminde açık zamanlayıcı kalır.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('giriş ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const LoginScreen());
  });

  testWidgets('ayarlar ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const SettingsScreen());
  });

  testWidgets('diyetisyen ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const DietitianScreen());
  });

  testWidgets('istatistik ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const NutritionStatsScreen());
  });

  testWidgets('kayıt ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const RegisterScreen());
  });

  testWidgets('parola sıfırlama ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const PasswordResetScreen());
  });

  testWidgets('rıza ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const PrivacyConsentScreen());
  });

  testWidgets('diyetisyen erişim ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const DietitianAccessScreen());
  });

  testWidgets('keşfet ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const DiscoverScreen());
  });

  testWidgets('tarama ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const FoodScanScreen());
  });

  testWidgets('manuel giriş ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const ManualFoodEntryScreen());
  });

  testWidgets('aktivite ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const ActivityTrackerScreen());
  });

  testWidgets('erişilebilirlik ayarlarındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const AccessibilitySettingsScreen());
  });

  testWidgets('anket ekranındaki her dokunulabilir ögenin adı var',
      (tester) async {
    await expectAllTappablesNamed(tester, const SurveyScreen());
  });
}
