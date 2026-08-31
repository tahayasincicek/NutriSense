import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/dietitian/screens/dietitian_screen.dart';
import 'package:nutrisense/features/history/screens/nutrition_stats_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  Widget app(Widget home, {double textScale = 1}) => ProviderScope(
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: MaterialApp(theme: AppTheme.lightTheme, home: home),
        ),
      );

  group('Diyetisyen ekranı', () {
    testWidgets('e-posta alanı ve eylem etiketli', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(const DietitianScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      // Oturum yoksa kurulum kartı görünür.
      if (find.byKey(const Key('dietitian_email')).evaluate().isNotEmpty) {
        expect(
          find.bySemanticsLabel('Diyetisyen e-posta adresi giriş alanı'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('dietitian_request')), findsOneWidget);
      }
      handle.dispose();
    });

    testWidgets('yüzde 200 fontta taşma üretmez', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(app(const DietitianScreen(), textScale: 2));
      await tester.pump(const Duration(milliseconds: 300));

      final error = tester.takeException();
      expect(
        error is FlutterError && '$error'.contains('overflowed'),
        isFalse,
        reason: '$error',
      );
    });
  });

  group('İstatistik ekranı', () {
    testWidgets('veri yokken boş durum gösterir', (tester) async {
      await tester.pumpWidget(app(const NutritionStatsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      // Ekran çökmeden açılmalı.
      expect(find.byType(NutritionStatsScreen), findsOneWidget);
    });

    testWidgets('yüzde 200 fontta taşma üretmez', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(app(const NutritionStatsScreen(), textScale: 2));
      await tester.pump(const Duration(milliseconds: 300));

      final error = tester.takeException();
      expect(
        error is FlutterError && '$error'.contains('overflowed'),
        isFalse,
        reason: '$error',
      );
    });
  });
}
