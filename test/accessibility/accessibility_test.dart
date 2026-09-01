import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/platform_channel_mocks.dart';
import 'package:nutrisense/app.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/food_scan/screens/food_scan_screen.dart';
import 'package:nutrisense/main.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(mockSecureStorage);
  tearDown(resetSecureStorageMock);

  Widget realApp() => ProviderScope(
        overrides: [memoryTokenStoreOverride()],
        child: const NutriSenseApp(
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
    // Sekme sayısı 5: Tara, Aktivite, Günlük, Keşfet, Diyetisyen.
    expect(find.bySemanticsLabel('Ana navigasyon çubuğu, 5 sekme'),
        findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Tara sekmesi, seçili')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Sesli komut butonu')), findsOneWidget);
    semantics.dispose();

    // Açılış zaman aşımının süresi dolsun.
    await tester.pump(const Duration(seconds: 6));
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
    // Material 3 NavigationBar kullanılıyor (eski BottomNavigationBar değil).
    expect(find.byType(NavigationBar), findsOneWidget);

    // Açılış zaman aşımının süresi dolsun.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('gerçek AppShell görünür ikon eylemleri en az 48dp',
      (tester) async {
    await tester.pumpWidget(realApp());
    await tester.pump();

    final fab = tester.getSize(find.byType(FloatingActionButton));
    expect(fab.width, greaterThanOrEqualTo(48));
    expect(fab.height, greaterThanOrEqualTo(48));

    // Açılış zaman aşımının süresi dolsun.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets(
      'Türkçe TTS yoksa merkezi ve erişilebilir alternatif uyarısı görünür',
      (tester) async {
    final accessibility = _UnavailableTtsService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessibilityServiceProvider.overrideWithValue(accessibility),
        ],
        child: const NutriSenseApp(
          initializePlatformServices: false,
          bypassAuthenticationForTests: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('tts_failure_banner')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Sesli okuma kullanılamıyor')),
      findsOneWidget,
    );
    expect(find.text('Ayarları Aç'), findsOneWidget);

    // Açılış zaman aşımının süresi dolsun.
    await tester.pump(const Duration(seconds: 6));
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

class _UnavailableTtsService extends AccessibilityService {
  final ValueNotifier<String?> _failure = ValueNotifier<String?>(
    'Türkçe metin okuma sesi bu cihazda bulunamadı.',
  );

  @override
  ValueListenable<String?> get ttsFailureListenable => _failure;

  @override
  String? get ttsFailureReason => _failure.value;

  @override
  void setScreenReaderActive(bool active) {}

  @override
  void dispose() {
    _failure.dispose();
  }
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
