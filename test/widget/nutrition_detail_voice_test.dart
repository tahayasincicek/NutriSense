import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/food_scan/screens/nutrition_detail_screen.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';
import 'package:nutrisense/shared/services/voice_command_service.dart';
import 'package:nutrisense/shared/models/food_analysis_model.dart';

class _Speech extends AccessibilityService {
  final messages = <String>[];
  @override
  Future<void> speak(
    String text, {
    TtsPriority priority = TtsPriority.normal,
    bool allowWhileScreenReaderActive = false,
  }) async {
    messages.add(text);
  }
}

void main() {
  for (final action in [
    'kaydet',
    'evet',
    'tekrar çek',
    'iptal',
    'button',
    'back'
  ]) {
    testWidgets('detail confirmation via $action restores shared listening',
        (tester) async {
      final speech = _Speech();
      final voice = VoiceCommandService(accessibility: speech);
      var globalCalls = 0;
      void globalHandler(CommandResult result) {
        globalCalls++;
      }

      voice.onCommandRecognized = globalHandler;
      final results = <String?>[];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          accessibilityServiceProvider.overrideWithValue(speech),
          voiceCommandServiceProvider.overrideWithValue(voice),
        ],
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () async {
                            results.add(await Navigator.of(context)
                                .push<String>(MaterialPageRoute(
                              builder: (_) => const NutritionDetailScreen(
                                foodName: 'apple',
                                foodNameTr: 'Elma',
                                calories: 52,
                                portionGrams: 100,
                                confidence: .95,
                                nutrients: NutrientData(
                                  protein: 1.2,
                                  carbs: 13.5,
                                  fat: .3,
                                  fiber: 2.4,
                                ),
                              ),
                            )));
                          },
                          child: const Text('open')),
                    ))),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final handler = voice.onCommandRecognized!;
      expect(identical(handler, globalHandler), isFalse);

      final initialAnnouncement = speech.messages.last;
      for (final phrase in [
        'besin bilgilerini oku',
        'besin değerlerini oku',
        'detayları oku',
        'tekrar oku'
      ]) {
        final command = voice.matchCommand(phrase);
        expect(command.command, VoiceCommand.readNutrition);
        final count = speech.messages.length;
        handler(command);
        await tester.pumpAndSettle();
        expect(speech.messages.length, count + 1);
        expect(speech.messages.last, initialAnnouncement);
        for (final detail in [
          'Elma',
          '100 gram',
          '52 kalori',
          '1.2 gram protein',
          '13.5 gram karbonhidrat',
          '0.3 gram yağ',
          '2.4 gram lif'
        ]) {
          expect(speech.messages.last, contains(detail));
        }
        expect(results, isEmpty);
        expect(globalCalls, 0);
      }

      // Even a global fuzzy match marked "yes" cannot save arbitrary words.
      handler(const CommandResult(
          rawText: 'kaydetme',
          command: VoiceCommand.yes,
          recognized: true,
          confidence: .9));
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      expect(globalCalls, 0);
      if (action == 'button') {
        await tester.ensureVisible(find.text('Kaydet'));
        await tester.tap(find.text('Kaydet'));
      } else if (action == 'back') {
        await tester.pageBack();
      } else {
        handler(voice.matchCommand(action));
        // Repeated final speech events must not pop the parent route.
        handler(voice.matchCommand(action));
      }
      await tester.pumpAndSettle();
      expect(results, [
        switch (action) {
          'kaydet' || 'evet' || 'button' => 'saved',
          'back' => null,
          _ => 'rescan',
        }
      ]);
      expect(find.text('open'), findsOneWidget);
      expect(identical(voice.onCommandRecognized, globalHandler), isTrue);
      expect(speech.messages.any((m) => m.contains('kaydedildi')), isFalse);
      voice.onCommandRecognized!(voice.matchCommand('geçmiş'));
      expect(globalCalls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
