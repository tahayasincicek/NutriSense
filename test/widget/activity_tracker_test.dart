import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/water_tracker/screens/water_tracker_screen.dart';
import 'package:nutrisense/features/water_tracker/state/water_provider.dart';

Widget _app(ProviderContainer container, {double textScale = 1}) {
  return UncontrolledProviderScope(
    container: container,
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ActivityTrackerScreen(),
      ),
    ),
  );
}

void main() {
  // flutter_tts platform kanalı testte yok; dispose sırasında MissingPlugin
  // fırlatmaması için kanalı sessizce karşılıyoruz.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('Aktivite ekranı işlevleri', () {
    testWidgets('uyku kartı süre girişi kabul eder', (tester) async {
      await tester.pumpWidget(_app(container));
      await tester.pump();

      final before = container.read(activityProvider).sleepHours;
      expect(before, 6.5);

      await tester.tap(find.byKey(const Key('sleep_card')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('sleep_input')), '7.5');
      await tester.tap(find.byKey(const Key('number_input_save')));
      await tester.pumpAndSettle();

      expect(container.read(activityProvider).sleepHours, 7.5);
    });

    testWidgets('uyku süresi klavye olmadan artır düğmesiyle girilebilir',
        (tester) async {
      // Tam görme kaybı senaryosu: klavyeye hiç dokunmadan değer değiştirme.
      await tester.pumpWidget(_app(container));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sleep_card')));
      await tester.pumpAndSettle();

      // 6.5 başlangıç + 0.5 adım = 7.0
      await tester.tap(find.byKey(const Key('number_input_increase')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('number_input_save')));
      await tester.pumpAndSettle();

      expect(container.read(activityProvider).sleepHours, 7.0);
    });

    testWidgets('azalt düğmesi alt sınırın altına inmez', (tester) async {
      await tester.pumpWidget(_app(container));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sleep_card')));
      await tester.pumpAndSettle();

      // 6.5'ten 0'ın altına inmeye çalış: 20 kez azalt.
      for (var i = 0; i < 20; i++) {
        await tester.tap(find.byKey(const Key('number_input_decrease')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('number_input_save')));
      await tester.pumpAndSettle();

      expect(container.read(activityProvider).sleepHours, 0);
    });

    testWidgets('sayı giriş diyaloğu sesli giriş düğmesi sunar',
        (tester) async {
      await tester.pumpWidget(_app(container));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sleep_card')));
      await tester.pumpAndSettle();

      // Klavye tek yol olmamalı: sesle söyleme ve artır/azalt da bulunmalı.
      expect(find.byKey(const Key('number_input_voice')), findsOneWidget);
      expect(find.byKey(const Key('number_input_increase')), findsOneWidget);
      expect(find.byKey(const Key('number_input_decrease')), findsOneWidget);
    });

    testWidgets('geçersiz uyku süresi reddedilir', (tester) async {
      await tester.pumpWidget(_app(container));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sleep_card')));
      await tester.pumpAndSettle();

      // 24 saatten fazla uyku kabul edilmemeli.
      await tester.enterText(find.byKey(const Key('sleep_input')), '30');
      await tester.tap(find.byKey(const Key('number_input_save')));
      await tester.pumpAndSettle();

      expect(container.read(activityProvider).sleepHours, 6.5);
      expect(find.textContaining('0 ile 24 saat'), findsWidgets);
    });

    testWidgets('su kartı bir bardak ekler', (tester) async {
      await tester.pumpWidget(_app(container));
      await tester.pump();

      expect(container.read(activityProvider).consumedWater, 0);
      await tester.tap(find.byKey(const Key('water_card')));
      await tester.pumpAndSettle();
      expect(container.read(activityProvider).consumedWater, 200);
    });

    testWidgets('ilaç alındı olarak işaretlenebilir', (tester) async {
      await tester.pumpWidget(_app(container));
      await tester.pump();

      final before = container
          .read(activityProvider)
          .medications
          .firstWhere((m) => m.name == 'D Vitamini');
      expect(before.isTaken, isFalse);

      await tester.ensureVisible(find.byKey(const Key('med_D Vitamini')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('med_D Vitamini')));
      await tester.pumpAndSettle();

      final after = container
          .read(activityProvider)
          .medications
          .firstWhere((m) => m.name == 'D Vitamini');
      expect(after.isTaken, isTrue);
    });

    testWidgets('kilo girişi kaydedilir', (tester) async {
      await tester.pumpWidget(_app(container));
      await tester.pump();

      await tester
          .ensureVisible(find.byIcon(Icons.add_circle_outline_rounded).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('weight_input')), '74.2');
      await tester.tap(find.byKey(const Key('number_input_save')));
      await tester.pumpAndSettle();

      expect(container.read(activityProvider).currentWeight, 74.2);
    });
  });

  group('Aktivite durumu', () {
    test('setSleep 0-24 aralığına sıkıştırır', () {
      final notifier = container.read(activityProvider.notifier);
      notifier.setSleep(30);
      expect(container.read(activityProvider).sleepHours, 24);
      notifier.setSleep(-5);
      expect(container.read(activityProvider).sleepHours, 0);
    });

    test('toggleMedication yalnızca hedef ilacı değiştirir', () {
      final notifier = container.read(activityProvider.notifier);
      notifier.toggleMedication('D Vitamini');
      final meds = container.read(activityProvider).medications;
      expect(meds.firstWhere((m) => m.name == 'D Vitamini').isTaken, isTrue);
      expect(meds.firstWhere((m) => m.name == 'Omega 3').isTaken, isTrue);
    });
  });
}
