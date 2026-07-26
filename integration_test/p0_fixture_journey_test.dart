import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nutrisense/core/time/app_clock.dart';
import 'package:nutrisense/features/dietitian/screens/send_report_wizard.dart';
import 'package:nutrisense/features/food_scan/models/camera_state.dart';
import 'package:nutrisense/features/food_scan/screens/camera_screen.dart';
import 'package:nutrisense/features/history/data/history_cache_store.dart';
import 'package:nutrisense/features/history/data/history_repository.dart';
import 'package:nutrisense/features/history/screens/food_history_screen.dart';
import 'package:nutrisense/features/history/state/history_controller.dart';
import 'package:nutrisense/shared/models/food_analysis_model.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';
import 'package:nutrisense/shared/services/api_service.dart';

import '../test/support/synthetic_factories.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'P0 sentetik yol: auth -> tarama onayı -> geçmiş -> rapor önizleme',
    (tester) async {
      final transport = _JourneyTransport();
      final tokens = _MemoryTokenStore();
      final api = ApiService(
        dio: Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api/v1'))
          ..httpClientAdapter = transport,
        tokenStore: tokens,
      );

      final login = await api.login(
        email: 'fixture.user@nutrisense.invalid',
        password: 'Synthetic-Only-123!',
      );
      expect(login.isSuccess, isTrue);
      expect(api.isAuthenticated, isTrue);

      final repository = _JourneyHistoryRepository();
      final cameraContainer = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(api),
          accessibilityServiceProvider.overrideWithValue(
            _SilentAccessibilityService(),
          ),
          appClockProvider.overrideWithValue(
            FixedAppClock(DateTime.parse('2026-07-26T12:30:00+03:00')),
          ),
          historyControllerProvider.overrideWith(
            (ref) => HistoryController(
              repository,
              SyntheticFactories.userId,
              clock: ref.read(appClockProvider),
            ),
          ),
        ],
      );
      addTearDown(cameraContainer.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: cameraContainer,
          child: const MaterialApp(
            home: CameraScreen(initializeHardware: false),
          ),
        ),
      );
      cameraContainer
          .read(cameraStateProvider.notifier)
          .setAnalysis(SyntheticFactories.foodAnalysis(), medium: false);
      await tester.pump();

      expect(find.text('Elma'), findsOneWidget);
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(transport.decisionCalls, 1);
      expect(find.text('Geçmişe Dön'), findsOneWidget);

      final historyContainer = ProviderContainer(
        overrides: [
          historyRepositoryProvider.overrideWithValue(repository),
          historyUserIdProvider.overrideWithValue(SyntheticFactories.userId),
          accessibilityServiceProvider.overrideWithValue(
            _SilentAccessibilityService(),
          ),
          appClockProvider.overrideWithValue(
            FixedAppClock(DateTime.parse('2026-07-26T12:30:00+03:00')),
          ),
        ],
      );
      addTearDown(historyContainer.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: historyContainer,
          child: const MaterialApp(home: FoodHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Elma'), findsOneWidget);
      expect(find.text('78 kcal'), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(api),
            accessibilityServiceProvider.overrideWithValue(
              _SilentAccessibilityService(),
            ),
          ],
          child: const MaterialApp(
            home: SendReportWizard(
              assignment: SyntheticFactories.approvedDietitian,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report_preview_button')));
      await tester.pumpAndSettle();
      expect(transport.previewCalls, 1);
      expect(find.text('3 kullanıcı onaylı kayıt'), findsOneWidget);
    },
  );
}

class _SilentAccessibilityService extends AccessibilityService {
  @override
  Future<void> speak(
    String text, {
    TtsPriority priority = TtsPriority.normal,
    bool allowWhileScreenReaderActive = false,
  }) async {}
}

class _MemoryTokenStore implements TokenStore {
  AuthSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession value) async => session = value;
}

class _JourneyTransport implements HttpClientAdapter {
  int decisionCalls = 0;
  int previewCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/auth/login')) {
      return _json({
        'access_token': 'synthetic-access-token',
        'refresh_token': 'synthetic-refresh-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_expires_in': 86400,
        'user_id': SyntheticFactories.userId,
        'full_name': 'Sentetik Kullanıcı',
      });
    }
    if (options.path.contains('/food-analysis/') &&
        options.path.endsWith('/decision')) {
      decisionCalls++;
      return _json({
        'analysis_id': SyntheticFactories.logId,
        'action': 'confirm',
        'status': 'confirmed',
        'log_id': SyntheticFactories.logId,
      });
    }
    if (options.path.endsWith('/dietitian-reports/preview')) {
      previewCalls++;
      return _json({
        'report_type': 'weekly',
        'from_date': '2026-07-20',
        'to_date': '2026-07-26',
        'record_count': 3,
        'total_calories': 780.0,
        'average_daily_calories': 111.4,
        'estimated_portion_count': 2,
        'dietitian_name': 'Sandbox Diyetisyen',
        'recipients': const {
          'email': 's****************@nutrisense.invalid',
          'sms': '+*******0006',
        },
        'channels': const ['email', 'sms'],
        'consent_context_hash':
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'accessibility_summary':
            '3 kullanıcı onaylı kayıt Sandbox Diyetisyene gönderilecek.',
      });
    }
    return _json({}, status: 404);
  }

  ResponseBody _json(Map<String, dynamic> body, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

class _JourneyHistoryRepository implements HistoryRepository {
  final history = SyntheticFactories.foodHistory();
  HistoryCacheSnapshot? cache;

  @override
  Future<ApiResult<FoodHistoryResult>> fetch({
    required DateTime fromDate,
    required DateTime toDate,
    required int page,
    required int pageSize,
  }) async =>
      ApiResult.success(history);

  @override
  Future<HistoryCacheSnapshot?> readCache(String userId) async => cache;

  @override
  Future<void> writeCache(String userId, FoodHistoryResult history) async {
    cache = HistoryCacheSnapshot(
      history: history,
      cachedAt: DateTime.parse('2026-07-26T09:30:00Z'),
    );
  }

  @override
  Future<ApiResult<FoodLogEntry>> update({
    required String logId,
    String? foodNameTr,
    double? portionGrams,
    String? mealType,
  }) async =>
      ApiResult.success(history.dailyLogs.single.foods.single);

  @override
  Future<ApiResult<Map<String, dynamic>>> delete(String logId) async =>
      const ApiResult.success({'status': 'deleted'});

  @override
  Future<ApiResult<Map<String, dynamic>>> restore(String logId) async =>
      const ApiResult.success({'status': 'restored'});
}
