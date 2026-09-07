import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/dietitian/screens/dietitian_screen.dart';
import 'package:nutrisense/shared/services/api_service.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';
import 'package:nutrisense/features/dietitian/widgets/report_history_section.dart';

class _Silent extends AccessibilityService {
  @override
  Future<void> speak(String text,
      {TtsPriority priority = TtsPriority.normal,
      bool allowWhileScreenReaderActive = false}) async {}
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
  _Adapter({this.historyCount = 0});
  final int historyCount;
  final writes = <bool>[];
  bool enabled = false;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    Object result = [];
    if (options.path.endsWith('/dietitians/assignment')) {
      result = {
        'assignment_id': 'assignment',
        'status': 'approved',
        'dietitian_id': 'dietitian',
        'dietitian_name': 'Test Diyetisyen',
        'email_verified': true,
        'phone_verified': true
      };
    } else if (options.path.endsWith('/dietitian-reports')) {
      result = List.generate(
          historyCount,
          (index) => {
                'report_id': '$index',
                'report_type': 'weekly',
                'from_date': '2026-09-01',
                'to_date': '2026-09-07',
                'created_at': '2026-09-07T10:00:00Z',
                'record_count': 1,
                'status': 'failed',
                'channels': [
                  {'channel': 'email', 'status': 'failed'}
                ],
              });
    } else if (options.path.endsWith('/dietitian-auto-share')) {
      if (options.method == 'PUT') {
        enabled = options.data['enabled'] == true;
        writes.add(enabled);
      }
      result = {'enabled': enabled};
    }
    return ResponseBody.fromString(jsonEncode(result), 200, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final barHeight in [72.0, 104.0]) {
    testWidgets('last report clears overlapping navigation height=$barHeight',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ApiService(
          dio: Dio(BaseOptions(baseUrl: 'https://test.invalid/api/v1'))
            ..httpClientAdapter = _Adapter(historyCount: 8),
          tokenStore: _Store());
      await tester.pumpWidget(ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(api),
            accessibilityServiceProvider.overrideWithValue(_Silent()),
          ],
          child: MaterialApp(
              home: Scaffold(
            extendBody: true,
            body: const DietitianScreen(),
            bottomNavigationBar:
                SizedBox(key: const Key('test_nav'), height: barHeight),
          ))));
      await tester.pumpAndSettle();
      final scroll =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.byType(ReportHistoryCard), findsNWidgets(8));
      final lastCard = tester.getRect(find.byType(ReportHistoryCard).last);
      final navigation = tester.getRect(find.byKey(const Key('test_nav')));
      expect(lastCard.bottom, lessThanOrEqualTo(navigation.top - 19));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('automatic sharing requires opt-in and can be turned off',
      (tester) async {
    final adapter = _Adapter();
    final api = ApiService(
        dio: Dio(BaseOptions(baseUrl: 'https://test.invalid/api/v1'))
          ..httpClientAdapter = adapter,
        tokenStore: _Store());
    await tester.pumpWidget(ProviderScope(overrides: [
      apiServiceProvider.overrideWithValue(api),
      accessibilityServiceProvider.overrideWithValue(_Silent()),
    ], child: const MaterialApp(home: DietitianScreen())));
    await tester.pumpAndSettle();
    final control = find.byKey(const Key('automatic_food_share'));
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(control).value, isFalse);
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(find.text('Otomatik paylaşımı aç?'), findsOneWidget);
    expect(adapter.writes, isEmpty);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(adapter.writes, isEmpty);
    await tester.tap(control);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onayla ve Aç'));
    await tester.pumpAndSettle();
    expect(adapter.writes, [true]);
    expect(tester.widget<SwitchListTile>(control).value, isTrue);
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(adapter.writes, [true, false]);
    expect(tester.widget<SwitchListTile>(control).value, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
