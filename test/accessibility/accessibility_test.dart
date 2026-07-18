import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/app.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/food_scan/screens/food_scan_screen.dart';
import 'package:nutrisense/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget realApp() => const ProviderScope(
        child: NutriSenseApp(
          initializePlatformServices: false,
          bypassAuthenticationForTests: true,
        ),
      );

  testWidgets('gerçek AppShell ana görevleri adlandırılmış sekmelerle sunar',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(realApp());
    await tester.pump();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(FoodScanScreen), findsOneWidget);
    expect(find.bySemanticsLabel('Ana navigasyon çubuğu, 4 sekme'),
        findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Tara sekmesi, seçili')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Sesli komut butonu')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('gerçek AppShell yüzde 200 fontta kritik taşma üretmez',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: realApp(),
      ),
    );
    await tester.pump();

    final layoutError = tester.takeException();
    expect(
      layoutError,
      isNull,
      reason: layoutError is FlutterError ? layoutError.toStringDeep() : null,
    );
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('gerçek AppShell görünür ikon eylemleri en az 48dp',
      (tester) async {
    await tester.pumpWidget(realApp());
    await tester.pump();

    final fab = tester.getSize(find.byType(FloatingActionButton));
    expect(fab.width, greaterThanOrEqualTo(48));
    expect(fab.height, greaterThanOrEqualTo(48));
  });

  test('tema ana metin kontrastı WCAG AA hedefini karşılar', () {
    expect(
        _contrastRatio(Colors.black, Colors.white), greaterThanOrEqualTo(4.5));
    expect(
      _contrastRatio(Colors.white, AppTheme.primaryDark),
      greaterThanOrEqualTo(4.5),
    );
  });
}

double _contrastRatio(Color foreground, Color background) {
  final first = _relativeLuminance(foreground);
  final second = _relativeLuminance(background);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  double linearize(double component) {
    final value = component / 255;
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linearize(color.r * 255) +
      0.7152 * linearize(color.g * 255) +
      0.0722 * linearize(color.b * 255);
}
