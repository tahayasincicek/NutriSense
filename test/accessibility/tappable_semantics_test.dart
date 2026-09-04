import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/auth/screens/login_screen.dart';
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

    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      final tappable = data.hasAction(SemanticsAction.tap) ||
          data.hasFlag(SemanticsFlag.isButton);
      // Metin alanları adını ipucu/etiket yerine değerinden alabilir.
      final isField = data.hasFlag(SemanticsFlag.isTextField);
      final named = data.label.trim().isNotEmpty ||
          data.tooltip.trim().isNotEmpty ||
          (isField && data.value.trim().isNotEmpty);

      if (tappable && !named) {
        offenders.add('id=${node.id} rect=${node.rect.size}');
      }
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(root);
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
}
