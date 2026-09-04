import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/food_scan/screens/food_scan_screen.dart';
import '../support/platform_channel_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(mockSecureStorage);
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_tts'), (call) async => 1);
  });

  testWidgets('dokum2', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(ProviderScope(
      child:
          MaterialApp(theme: AppTheme.lightTheme, home: const FoodScanScreen()),
    ));
    await tester.pumpAndSettle();

    void visit(SemanticsNode n, int depth) {
      final d = n.getSemanticsData();
      final tap =
          d.hasAction(SemanticsAction.tap) || d.hasFlag(SemanticsFlag.isButton);
      if (tap && d.label.trim().isEmpty && d.tooltip.trim().isEmpty) {
        // ignore: avoid_print
        print('ADSIZ2 derinlik=$depth size=${n.rect.size} rect=${n.rect} '
            'flags=${d.flags} actions=${d.actions}');
      }
      n.visitChildren((c) {
        visit(c, depth + 1);
        return true;
      });
    }

    visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!, 0);
    handle.dispose();
  });
}
