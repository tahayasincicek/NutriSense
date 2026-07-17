import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/history/screens/food_history_screen.dart';
import 'package:nutrisense/shared/services/api_service.dart';

void main() {
  group('FoodHistoryScreen gerçek ürün widget testleri', () {
    testWidgets('kanonik API boş geçmiş döndürdüğünde boş durum görünür',
        (tester) async {
      final payload = _fixture()..['daily_logs'] = <dynamic>[];
      await tester.pumpWidget(_app(payload));
      await _load(tester);

      expect(find.text('Henüz besin kaydı yok'), findsOneWidget);
      expect(
          find.text('Besin taramak için ana sayfaya dönün.'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
    });

    testWidgets('ürün ekranındaki dönem seçici üç kanonik seçeneği gösterir',
        (tester) async {
      await tester.pumpWidget(_app(_fixture()));
      await _load(tester);

      expect(find.text('Günlük'), findsOneWidget);
      expect(find.text('Haftalık'), findsOneWidget);
      expect(find.text('Aylık'), findsOneWidget);
    });

    testWidgets('paylaşılan contract fixture besin ve özet bilgilerine dönüşür',
        (tester) async {
      await tester.pumpWidget(_app(_fixture()));
      await _load(tester);

      expect(find.text('Elma'), findsOneWidget);
      expect(find.text('78 kcal'), findsOneWidget);
      expect(find.text('150g • Atıştırmalık'), findsOneWidget);
      expect(find.text('10:30'), findsOneWidget);
      expect(find.text('78 / 2000 kcal'), findsOneWidget);
      expect(find.text('1 öğün'), findsOneWidget);
    });

    testWidgets('ürün satırının semantik etiketi besin bağlamını içerir',
        (tester) async {
      await tester.pumpWidget(_app(_fixture()));
      await _load(tester);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Elma, 150 gram, 78 kalori. Atıştırmalık öğünü.',
        ),
        findsOneWidget,
      );
    });
  });
}

Map<String, dynamic> _fixture() => jsonDecode(
      File('contracts/fixtures/food_history_success.json').readAsStringSync(),
    ) as Map<String, dynamic>;

Widget _app(Map<String, dynamic> payload) {
  final dio = Dio(BaseOptions(baseUrl: 'https://contract.test/api/v1'))
    ..httpClientAdapter = _FixtureAdapter(payload);
  final api = ApiService(
    dio: dio,
    tokenStore: _MemoryTokenStore(),
  );
  return ProviderScope(
    overrides: [apiServiceProvider.overrideWithValue(api)],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const FoodHistoryScreen(),
    ),
  );
}

Future<void> _load(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

class _MemoryTokenStore implements TokenStore {
  AuthSession? session = const AuthSession(
    accessToken: 'fixture-access',
    refreshToken: 'fixture-refresh',
    userId: '9e4e5356-b491-4575-a9dd-c5abbc777fe9',
    fullName: 'Fixture User',
    expiresIn: 3600,
    refreshExpiresIn: 86400,
  );

  @override
  Future<void> clear() async => session = null;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession value) async => session = value;
}

class _FixtureAdapter implements HttpClientAdapter {
  _FixtureAdapter(this.payload);

  final Map<String, dynamic> payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/food-history/')) {
      return ResponseBody.fromString(
        jsonEncode(payload),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString('{}', 404);
  }

  @override
  void close({bool force = false}) {}
}
