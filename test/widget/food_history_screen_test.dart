import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/history/data/history_cache_store.dart';
import 'package:nutrisense/features/history/data/history_repository.dart';
import 'package:nutrisense/features/history/screens/food_history_screen.dart';
import 'package:nutrisense/features/history/state/history_controller.dart';
import 'package:nutrisense/shared/models/food_analysis_model.dart';
import 'package:nutrisense/shared/services/api_service.dart';
import 'package:nutrisense/shared/services/stt_service.dart';

const _userId = '9e4e5356-b491-4575-a9dd-c5abbc777fe9';
const _logId = '550e8400-e29b-41d4-a716-446655440000';

void main() {
  group('FoodHistoryScreen kanonik ürün widget testleri', () {
    testWidgets('yüklenirken açık loading durumu gösterir', (tester) async {
      final repository = _FakeHistoryRepository(_fixtureHistory())
        ..fetchGate = Completer<void>();

      await tester.pumpWidget(_app(repository));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(repository.fetchCount, 1);
    });

    testWidgets('boş durum tarama eylemini gerçek callbacke bağlar',
        (tester) async {
      var scanRequested = false;
      final repository = _FakeHistoryRepository(_emptyHistory());

      await tester.pumpWidget(
        _app(repository, onScanRequested: () => scanRequested = true),
      );
      await _load(tester);

      expect(find.text('Seçilen dönemde kayıt yok'), findsOneWidget);
      await tester.tap(find.byKey(const Key('history_scan_action')));
      expect(scanRequested, isTrue);
    });

    testWidgets('fixture kaydı, özet, kaynak ve durum bilgilerini gösterir',
        (tester) async {
      await tester.pumpWidget(_app(_FakeHistoryRepository(_fixtureHistory())));
      await _load(tester);

      expect(find.text('Elma'), findsOneWidget);
      expect(find.text('78 kcal'), findsOneWidget);
      expect(find.text('150 gram • Atıştırmalık'), findsOneWidget);
      expect(find.textContaining('çevrim içi görüntü tanıma'), findsOneWidget);
      expect(find.text('Kullanıcı onaylı'), findsOneWidget);
      expect(find.textContaining('1 kayıt • 78 kcal'), findsOneWidget);
    });

    testWidgets('başarısız istek açık hata ve yeniden dene eylemi gösterir',
        (tester) async {
      final repository = _FakeHistoryRepository(_fixtureHistory())
        ..fetchFailure = _connectionFailure;

      await tester.pumpWidget(_app(repository));
      await _load(tester);

      expect(find.text('Ağ bağlantısı kurulamadı.'), findsOneWidget);
      expect(find.byKey(const Key('history_retry')), findsOneWidget);
    });

    testWidgets('ağ yokken kullanıcıya ait şifreli cache durumunu gösterir',
        (tester) async {
      final history = _fixtureHistory();
      final repository = _FakeHistoryRepository(history)
        ..fetchFailure = _connectionFailure
        ..cache = HistoryCacheSnapshot(
          history: history,
          cachedAt: DateTime.utc(2026, 7, 18, 8),
        );

      await tester.pumpWidget(_app(repository));
      await _load(tester);

      expect(find.textContaining('Çevrim dışı kayıtlar gösteriliyor'),
          findsOneWidget);
      expect(find.text('Elma'), findsOneWidget);
    });

    testWidgets('oturum yoksa repository çağrılmaz', (tester) async {
      final repository = _FakeHistoryRepository(_fixtureHistory());

      await tester.pumpWidget(_app(repository, userId: null));
      await _load(tester);

      expect(repository.fetchCount, 0);
      expect(find.textContaining('oturum açın'), findsOneWidget);
    });

    testWidgets('gerçek kart tek anlamlı kayıt semantiği üretir',
        (tester) async {
      final history = _fixtureHistory();
      final entry = history.dailyLogs.single.foods.single;
      await tester.pumpWidget(_app(_FakeHistoryRepository(history)));
      await _load(tester);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == entry.semanticLabel,
        ),
        findsOneWidget,
      );
      expect(entry.semanticLabel, contains('Elma, 150 gram, 78 kalori'));
      expect(entry.semanticLabel, contains('Kullanıcı onaylı'));
    });

    testWidgets('düzeltme repositoryye gider ve yenilenen kaydı gösterir',
        (tester) async {
      final repository = _FakeHistoryRepository(_fixtureHistory());
      await tester.pumpWidget(_app(repository));
      await _load(tester);

      await _revealActions(tester);
      await tester.tap(find.byKey(const Key('edit_$_logId')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('history_edit_name')),
        'Yeşil elma',
      );
      await tester.enterText(
        find.byKey(const Key('history_edit_portion')),
        '100',
      );
      await tester.tap(find.byKey(const Key('history_edit_save')));
      await tester.pumpAndSettle();

      expect(repository.updateCount, 1);
      expect(find.text('Yeşil elma'), findsOneWidget);
      expect(find.text('Düzeltilmiş'), findsOneWidget);
    });

    testWidgets('silme onaylıdır ve snackbar üzerinden geri alınabilir',
        (tester) async {
      final repository = _FakeHistoryRepository(_fixtureHistory());
      await tester.pumpWidget(_app(repository));
      await _load(tester);

      await _revealActions(tester);
      await tester.tap(find.byKey(const Key('delete_$_logId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history_delete_confirm')));
      await tester.pumpAndSettle();

      expect(repository.deleteCount, 1);
      expect(find.text('Seçilen dönemde kayıt yok'), findsOneWidget);
      expect(find.text('Geri al'), findsOneWidget);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(repository.restoreCount, 1);
      expect(find.text('Elma'), findsOneWidget);
    });

    testWidgets('tek başına silme komutu kaydı silmez, onay ister',
        (tester) async {
      final repository = _FakeHistoryRepository(_fixtureHistory());
      // Yalnız komut var, onay yok: kayıt silinmemeli.
      final stt = _FakeSttService([
        const SttResult(text: 'kaydı sil', confidence: 1, isFinal: true),
      ]);
      await tester.pumpWidget(_app(repository, stt: stt));
      await _load(tester);
      await _revealActions(tester);

      await tester.ensureVisible(find.byKey(const Key('voice_$_logId')));
      await tester.pumpAndSettle();
      _invokeVoiceButton(tester);
      await tester.pumpAndSettle();

      expect(repository.deleteCount, 0);
      expect(find.textContaining('evet deyin'), findsOneWidget);
      // Kullanıcıya göremediği bir düğme tarif edilmemeli.
      expect(find.textContaining('Mikrofon düğmesine'), findsNothing);
    });

    testWidgets('komuttan sonra söylenen evet kaydı siler', (tester) async {
      final repository = _FakeHistoryRepository(_fixtureHistory());
      // Onay için mikrofon kendiliğinden yeniden açılır; ayrı bir "evet"
      // söylenmesi hâlâ zorunludur.
      final stt = _FakeSttService([
        const SttResult(text: 'kaydı sil', confidence: 1, isFinal: true),
        const SttResult(text: 'evet', confidence: 1, isFinal: true),
      ]);
      await tester.pumpWidget(_app(repository, stt: stt));
      await _load(tester);
      await _revealActions(tester);

      await tester.ensureVisible(find.byKey(const Key('voice_$_logId')));
      await tester.pumpAndSettle();
      _invokeVoiceButton(tester);
      await tester.pumpAndSettle();

      expect(repository.deleteCount, 1);
      expect(find.text('Geri al'), findsOneWidget);
    });

    testWidgets('kısmi STT sonucu geçmiş kaydını değiştirmez', (tester) async {
      final repository = _FakeHistoryRepository(_fixtureHistory());
      final stt = _FakeSttService([
        const SttResult(
          text: 'porsiyon 150 gram',
          confidence: 1,
          isFinal: false,
        ),
      ]);
      await tester.pumpWidget(_app(repository, stt: stt));
      await _load(tester);
      await _revealActions(tester);

      await tester.ensureVisible(find.byKey(const Key('voice_$_logId')));
      await tester.pumpAndSettle();
      _invokeVoiceButton(tester);
      await tester.pumpAndSettle();

      expect(stt.startCount, 1);
      expect(repository.updateCount, 0);
      expect(find.textContaining('Komut henüz çalıştırılmadı'), findsOneWidget);
    });

    testWidgets('gerçek geçmiş ekranı yüzde 200 fontta taşmaz', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        _app(
          _FakeHistoryRepository(_fixtureHistory()),
          textScale: 2,
        ),
      );
      await _load(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('history_list')), findsOneWidget);
    });
  });
}

const _connectionFailure = ApiFailure(
  code: 'CONNECTION_ERROR',
  message: 'Ağ bağlantısı kurulamadı.',
  kind: ApiFailureKind.connection,
);

FoodHistoryResult _fixtureHistory() {
  final payload = jsonDecode(
    File('contracts/fixtures/food_history_success.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final today = DateTime.now();
  final date = _dateOnly(today);
  payload
    ..['from_date'] = date
    ..['to_date'] = date
    ..['total_days'] = 1;
  final day = (payload['daily_logs'] as List).single as Map<String, dynamic>;
  day['date'] = date;
  return FoodHistoryResult.fromJson(payload);
}

FoodHistoryResult _emptyHistory([FoodHistoryResult? source]) {
  final current = source ?? _fixtureHistory();
  return FoodHistoryResult(
    userId: current.userId,
    fromDate: current.fromDate,
    toDate: current.toDate,
    totalDays: current.totalDays,
    averageDailyCalories: 0,
    totalCalories: 0,
    totalLogCount: 0,
    totalDateCount: 0,
    page: 1,
    pageSize: current.pageSize,
    hasMore: false,
    dailyLogs: const [],
  );
}

String _dateOnly(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

Widget _app(
  _FakeHistoryRepository repository, {
  String? userId = _userId,
  VoidCallback? onScanRequested,
  SttService? stt,
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      historyRepositoryProvider.overrideWithValue(repository),
      historyUserIdProvider.overrideWithValue(userId),
      if (stt != null) sttServiceProvider.overrideWithValue(stt),
    ],
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: FoodHistoryScreen(onScanRequested: onScanRequested),
      ),
    ),
  );
}

Future<void> _load(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _revealActions(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('history_list')),
    const Offset(0, -500),
  );
  await tester.pumpAndSettle();
}

void _invokeVoiceButton(WidgetTester tester) {
  final button = tester.widget<IconButton>(
    find.byKey(const Key('voice_$_logId')),
  );
  expect(button.onPressed, isNotNull);
  button.onPressed!.call();
}

class _FakeHistoryRepository implements HistoryRepository {
  _FakeHistoryRepository(this.remote);

  FoodHistoryResult remote;
  FoodHistoryResult? _deleted;
  HistoryCacheSnapshot? cache;
  ApiFailure? fetchFailure;
  Completer<void>? fetchGate;
  int fetchCount = 0;
  int updateCount = 0;
  String? lastPortionUnit;
  int deleteCount = 0;
  int restoreCount = 0;

  @override
  Future<ApiResult<FoodHistoryResult>> fetch({
    required DateTime fromDate,
    required DateTime toDate,
    required int page,
    required int pageSize,
  }) async {
    fetchCount += 1;
    final gate = fetchGate;
    if (gate != null) await gate.future;
    if (fetchFailure != null) return ApiResult.error(fetchFailure!);
    remote = _withRange(remote, fromDate, toDate, pageSize);
    return ApiResult.success(remote);
  }

  @override
  Future<HistoryCacheSnapshot?> readCache(String userId) async => cache;

  @override
  Future<void> writeCache(String userId, FoodHistoryResult history) async {
    cache = HistoryCacheSnapshot(
      history: history,
      cachedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<ApiResult<FoodLogEntry>> update({
    required String logId,
    String? foodNameTr,
    double? portionValue,
    String portionUnit = 'gram',
    String? mealType,
  }) async {
    updateCount += 1;
    lastPortionUnit = portionUnit;
    final payload = remote.toJson();
    final day = (payload['daily_logs'] as List).single as Map<String, dynamic>;
    final food = (day['foods'] as List).single as Map<String, dynamic>;
    if (foodNameTr != null) food['food_name_tr'] = foodNameTr;
    if (mealType != null) food['meal_type'] = mealType;
    if (portionValue != null) {
      food
        ..['portion_g'] = portionValue
        ..['portion_value'] = portionValue
        ..['portion_unit'] = portionUnit
        ..['calories'] = 52 * portionValue / 100;
    }
    food['is_corrected'] = true;
    remote = FoodHistoryResult.fromJson(payload);
    return ApiResult.success(remote.dailyLogs.single.foods.single);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> delete(String logId) async {
    deleteCount += 1;
    _deleted = remote;
    remote = _emptyHistory(remote);
    return const ApiResult.success({'deleted': true});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> restore(String logId) async {
    restoreCount += 1;
    if (_deleted != null) remote = _deleted!;
    return const ApiResult.success({'restored': true});
  }
}

class _FakeSttService extends SttService {
  _FakeSttService(this.results);

  final List<SttResult> results;
  int startCount = 0;

  @override
  Future<void> startListening({
    required void Function(SttResult) onResult,
    void Function(String)? onError,
    void Function()? onListeningStarted,
    void Function()? onListeningStopped,
    String? locale,
    Duration listenFor = const Duration(seconds: 30),
  }) async {
    startCount += 1;
    onListeningStarted?.call();
    if (results.isNotEmpty) onResult(results.removeAt(0));
    onListeningStopped?.call();
  }

  @override
  Future<void> cancelListening() async {}

  @override
  void dispose() {}
}

FoodHistoryResult _withRange(
  FoodHistoryResult source,
  DateTime fromDate,
  DateTime toDate,
  int pageSize,
) {
  return FoodHistoryResult(
    userId: source.userId,
    fromDate: fromDate,
    toDate: toDate,
    totalDays: toDate.difference(fromDate).inDays + 1,
    averageDailyCalories: source.averageDailyCalories,
    totalCalories: source.totalCalories,
    totalLogCount: source.totalLogCount,
    totalDateCount: source.totalDateCount,
    page: 1,
    pageSize: pageSize,
    hasMore: source.hasMore,
    dailyLogs: source.dailyLogs,
  );
}
