import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/history/screens/food_shortcuts_screen.dart';
import 'package:nutrisense/shared/services/api_service.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';
import 'package:nutrisense/shared/services/voice_command_service.dart';

class _Silent extends AccessibilityService {
  final messages = <String>[];
  @override
  Future<void> speak(String text,
      {TtsPriority priority = TtsPriority.normal,
      bool allowWhileScreenReaderActive = false}) async {
    messages.add(text);
  }
}

class _Store implements TokenStore {
  @override
  Future<AuthSession?> read() async => null;
  @override
  Future<void> write(AuthSession value) async {}
  @override
  Future<void> clear() async {}
}

class _Adapter implements HttpClientAdapter {
  final writes = <Map<String, dynamic>>[];
  bool failNext = false;
  bool undone = false;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.method == 'POST') {
      writes.add(Map<String, dynamic>.from(options.data as Map));
      if (failNext) {
        failNext = false;
        return _json({'detail': 'Bağlantı kesildi'}, 503);
      }
      if (options.path.endsWith('/undo')) undone = true;
      return _json({'message': 'İşlem tamamlandı.'});
    }
    return _json({
      'meals': [
        {
          'meal_type': 'kahvalti',
          'frequency': 3,
          'context_hash': 'a' * 64,
          'log_ids': ['11111111-1111-4111-8111-111111111111'],
          'items': [
            {
              'name': 'Omlet',
              'grams': 125,
              'calories': 178.75,
              'estimated': false
            }
          ],
        }
      ],
      'undo': undone
          ? null
          : {
              'action_id': '22222222-2222-4222-8222-222222222222',
              'label': 'Besin ekleme',
              'summary': 'Omlet',
              'context_hash': 'b' * 64,
            }
    });
  }

  ResponseBody _json(Object data, [int code = 200]) =>
      ResponseBody.fromString(jsonEncode(data), code, headers: {
        Headers.contentTypeHeader: ['application/json']
      });
  @override
  void close({bool force = false}) {}
}

void main() {
  for (final failFirst in [false, true]) {
    testWidgets('voice meal confirmation and undo; retry=$failFirst',
        (tester) async {
      final adapter = _Adapter()..failNext = failFirst;
      final speech = _Silent();
      final voice = VoiceCommandService(accessibility: speech);
      final api = ApiService(
          dio: Dio(BaseOptions(baseUrl: 'https://test.invalid/api/v1'))
            ..httpClientAdapter = adapter,
          tokenStore: _Store());
      await tester.pumpWidget(ProviderScope(overrides: [
        apiServiceProvider.overrideWithValue(api),
        accessibilityServiceProvider.overrideWithValue(speech),
        voiceCommandServiceProvider.overrideWithValue(voice),
      ], child: const MaterialApp(home: FoodShortcutsScreen())));
      await tester.pumpAndSettle();
      expect(voice.matchCommand('her zamanki kahvaltımı ekle').command,
          VoiceCommand.usualBreakfast);
      expect(voice.matchCommand('son işlemi geri al').command,
          VoiceCommand.undoFood);
      expect(speech.messages.join(' '), contains('Omlet, 125 gram'));
      void say(String text) =>
          voice.onCommandRecognized!(voice.matchCommand(text));
      say('birinci öğün');
      await tester.pumpAndSettle();
      expect(find.text('Kahvaltı tekrar eklensin mi?'), findsOneWidget);
      expect(adapter.writes, isEmpty);
      say('hayır');
      await tester.pumpAndSettle();
      expect(adapter.writes, isEmpty);
      say('birinci öğün');
      await tester.pumpAndSettle();
      say('evet');
      say('evet');
      await tester.pumpAndSettle();
      expect(adapter.writes.length, 1);
      expect(adapter.writes.first['confirmed'], isTrue);
      if (failFirst) {
        say('birinci öğün');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Onayla'));
        await tester.pumpAndSettle();
        expect(adapter.writes.length, 2);
        expect(
            adapter.writes[1]['request_id'], adapter.writes[0]['request_id']);
      }
      say('son işlemi geri al');
      await tester.pumpAndSettle();
      expect(find.textContaining('raporları geri çekilmez'), findsOneWidget);
      say('evet');
      await tester.pumpAndSettle();
      expect(adapter.writes.last['action_id'], isNotNull);
      expect(adapter.undone, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
