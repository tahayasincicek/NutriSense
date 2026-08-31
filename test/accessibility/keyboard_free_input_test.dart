import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/shared/widgets/accessible_number_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  Future<double?> openDialog(
    WidgetTester tester, {
    double initial = 10,
    double min = 0,
    double max = 100,
    double step = 1,
  }) async {
    double? result;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showAccessibleNumberDialog(
                    context: context,
                    title: 'Test Değeri',
                    fieldLabel: 'Değer',
                    suffix: 'br',
                    spokenUnit: 'birim',
                    min: min,
                    max: max,
                    step: step,
                    initialValue: initial,
                  );
                },
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    return result;
  }

  group('Klavyesiz sayı girişi', () {
    testWidgets('üç giriş yolunun üçü de mevcut', (tester) async {
      await openDialog(tester);

      // Tam görme kaybı olan kullanıcı klavyeye mahkûm olmamalı.
      expect(find.byKey(const Key('number_input_voice')), findsOneWidget,
          reason: 'Sesle giriş düğmesi yok');
      expect(find.byKey(const Key('number_input_increase')), findsOneWidget,
          reason: 'Artır düğmesi yok');
      expect(find.byKey(const Key('number_input_decrease')), findsOneWidget,
          reason: 'Azalt düğmesi yok');
    });

    testWidgets('artır/azalt sınırları aşmaz', (tester) async {
      await openDialog(tester, initial: 99, min: 0, max: 100, step: 1);

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('number_input_increase')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('number_input_field')),
      );
      expect(field.controller!.text, '100');
    });

    testWidgets('değer alanı ekran okuyucuya birimiyle sunulur',
        (tester) async {
      final handle = tester.ensureSemantics();
      await openDialog(tester, initial: 7.5);

      // TalkBack odaklandığında "7,5 birim" duymalı, ham metin değil.
      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final valued = semantics.where(
        (widget) => widget.properties.value?.contains('birim') ?? false,
      );
      expect(valued, isNotEmpty,
          reason: 'Alanın Semantics.value değeri birim taşımıyor');
      handle.dispose();
    });

    testWidgets('her eylem düğmesi ipucu taşır', (tester) async {
      await openDialog(tester);

      for (final key in [
        'number_input_voice',
        'number_input_increase',
        'number_input_decrease',
      ]) {
        final button = tester.widget<IconButton>(find.byKey(Key(key)));
        expect(button.tooltip, isNotNull,
            reason: '$key için ipucu tanımlı değil');
        expect(button.tooltip, isNotEmpty);
      }
    });

    testWidgets('sınır dışı değer kaydedilmez', (tester) async {
      await openDialog(tester, initial: 10, min: 0, max: 24);

      await tester.enterText(find.byKey(const Key('number_input_field')), '99');
      await tester.tap(find.byKey(const Key('number_input_save')));
      await tester.pumpAndSettle();

      // Diyalog açık kalmalı ve hata gösterilmeli.
      expect(find.byKey(const Key('number_input_save')), findsOneWidget);
      expect(find.textContaining('arasında olmalıdır'), findsWidgets);
    });
  });
}
