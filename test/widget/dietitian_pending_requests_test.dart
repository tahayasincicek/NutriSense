import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/dietitian/screens/dietitian_dashboard_screen.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';
import 'package:nutrisense/shared/services/api_service.dart';

void main() {
  // Panel uzun bir liste; kısa test penceresinde alt bölümler tembel kaldığı
  // için gerçek cihaz yüksekliğine yakın bir yüzey veriyoruz.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1080, 3200);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('panel bekleyen isteği listeler ve kabul çağrısını yapar',
      (tester) async {
    final adapter = _DashboardAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    expect(find.text('Bekleyen eşleşme istekleri'), findsOneWidget);
    // Aynı danışan hem bekleyen istekte hem gelen raporda görünebilir.
    expect(find.text('Ayşe Yılmaz'), findsWidgets);
    // Hasta e-postası yalnız maskeli görünür.
    expect(find.text('a***@example.com'), findsOneWidget);
    expect(find.textContaining('ayse.yilmaz@example.com'), findsNothing);

    await tester.tap(find.text('Kabul Et'));
    await tester.pumpAndSettle();

    expect(adapter.acceptedId, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc');
    expect(find.textContaining('artık danışanınız'), findsOneWidget);
  });

  testWidgets('ret onay diyaloğu ister ve vazgeçilince istek atılmaz',
      (tester) async {
    final adapter = _DashboardAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reddet'));
    await tester.pumpAndSettle();
    expect(find.text('İsteği reddet'), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(adapter.rejectedId, isNull);
  });

  testWidgets('gelen rapor kartı rapor alanlarını gösterir', (tester) async {
    final adapter = _DashboardAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    expect(find.text('Gelen beslenme raporları'), findsOneWidget);
    expect(find.text('Haftalık · 24 Ağustos - 30 Ağustos'), findsOneWidget);
    expect(find.text('12 besin kaydı'), findsOneWidget);
    expect(find.text('9 öğün'), findsOneWidget);
    expect(find.text('1850 kcal'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
  });

  testWidgets('bekleyen istek yoksa bölüm hiç çizilmez', (tester) async {
    final adapter = _DashboardAdapter(withPending: false);
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    expect(find.text('Bekleyen eşleşme istekleri'), findsNothing);
    expect(find.text('Kabul Et'), findsNothing);
  });
}

Widget _app(_DashboardAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://contract.test/api/v1'))
    ..httpClientAdapter = adapter;
  return ProviderScope(
    overrides: [
      apiServiceProvider.overrideWithValue(
        ApiService(dio: dio, tokenStore: _MemoryTokenStore()),
      ),
      accessibilityServiceProvider.overrideWithValue(
        _SilentAccessibilityService(),
      ),
    ],
    child: const MaterialApp(home: DietitianDashboardScreen()),
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
  AuthSession? session = const AuthSession(
    accessToken: 'fixture-access',
    refreshToken: 'fixture-refresh',
    userId: '9e4e5356-b491-4575-a9dd-c5abbc777fe9',
    fullName: 'Fixture Diyetisyen',
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

class _DashboardAdapter implements HttpClientAdapter {
  _DashboardAdapter({this.withPending = true});

  final bool withPending;
  String? acceptedId;
  String? rejectedId;
  bool accepted = false;

  static const _assignmentId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/dietitian/dashboard')) {
      final showPending = withPending && !accepted;
      return _json({
        'dietitian_id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'full_name': 'Sandbox Diyetisyen',
        'specialization': 'Beslenme ve Diyet',
        'email_verified': true,
        'active_patients': 0,
        'pending_assignments': showPending ? 1 : 0,
        'reports_received': 0,
        'patients': const [],
        'recent_reports': [
          {
            'report_id': 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
            'patient_id': 'ffffffff-ffff-4fff-8fff-ffffffffffff',
            'patient_name': 'Ayşe Yılmaz',
            'report_type': 'weekly',
            'from_date': '2026-08-24',
            'to_date': '2026-08-30',
            'record_count': 12,
            'total_meals': 9,
            'total_calories': 1850.0,
            'status': 'sent',
            'created_at': '2026-08-30T10:00:00Z',
            'delivered_via_email': true,
            'delivered_via_sms': false,
          }
        ],
        'pending_requests': showPending
            ? [
                {
                  'assignment_id': _assignmentId,
                  'patient_name': 'Ayşe Yılmaz',
                  'patient_email_masked': 'a***@example.com',
                  'requested_at': DateTime.now()
                      .subtract(const Duration(hours: 2))
                      .toUtc()
                      .toIso8601String(),
                  'patient_approved': true,
                }
              ]
            : const [],
      });
    }
    if (options.path.endsWith('/accept')) {
      acceptedId = _assignmentId;
      accepted = true;
      return _json({
        'assignment_id': _assignmentId,
        'status': 'approved',
        'dietitian_id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'dietitian_name': 'Sandbox Diyetisyen',
        'email_verified': true,
        'phone_verified': false,
        'patient_approved': true,
        'dietitian_accepted': true,
      });
    }
    if (options.path.endsWith('/reject')) {
      rejectedId = _assignmentId;
      return _json({
        'assignment_id': _assignmentId,
        'status': 'rejected',
        'dietitian_id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'dietitian_name': 'Sandbox Diyetisyen',
        'email_verified': true,
        'phone_verified': false,
      });
    }
    return _json(const {}, status: 404);
  }

  ResponseBody _json(Map<String, dynamic> value, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}
