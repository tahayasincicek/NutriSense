import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/survey/screens/usability_test_screen.dart';

/// Kullanılabilirlik testi ekranı araştırmacı arayüzüdür; TÜBİTAK raporunun
/// metodoloji bölümünde vaat edilen görev başarı/hata oranlarını toplar.
/// Araştırmacının kendisi de görme engelli olabileceğinden ekran okuyucuyla
/// kullanılabilir olmalıdır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => call.method == 'isLanguageAvailable' ? true : 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
  });

  Widget app({double textScale = 1}) => ProviderScope(
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const UsabilityTestScreen(),
          ),
        ),
      );

  testWidgets('katılımcı kimliği alanı etiketli', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app());
    await tester.pump();

    expect(
      find.bySemanticsLabel('Katılımcı kimliği giriş alanı'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('görev kartları göreve özgü eylem etiketi taşır',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app());
    await tester.pump();

    // Oturumu başlat.
    await tester.enterText(
      find.byKey(const Key('usability_participant_id')),
      'P001',
    );
    await tester.pumpAndSettle();

    final start = find.text('Testi Başlat');
    if (start.evaluate().isNotEmpty) {
      await tester.tap(start);
      await tester.pumpAndSettle();

      // Aynı ekranda birden çok "Başlat" olur; etiketler ayırt edici olmalı.
      final startLabels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((widget) => widget.properties.label)
          .whereType<String>()
          .where((label) => label.contains('görevini başlat'))
          .toSet();

      expect(
        startLabels.length,
        greaterThan(1),
        reason: 'Başlat butonları hangi göreve ait olduğunu söylemiyor',
      );
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

    await tester.pumpWidget(app(textScale: 2));
    await tester.pump();

    final error = tester.takeException();
    expect(
      error is FlutterError && '$error'.contains('overflowed'),
      isFalse,
      reason: '$error',
    );
  });
}
