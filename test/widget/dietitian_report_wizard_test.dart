import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/dietitian/screens/send_report_wizard.dart';
import 'package:nutrisense/shared/models/auth_model.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';
import 'package:nutrisense/shared/services/api_service.dart';
import 'package:nutrisense/shared/widgets/accessible_button.dart';

const _assignment = DietitianAssignmentInfo(
  assignmentId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  status: 'approved',
  dietitianId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  dietitianName: 'Sandbox Diyetisyen',
  emailVerified: true,
  phoneVerified: true,
  emailMasked: 's****************@nutrisense.invalid',
  phoneMasked: '+*******0006',
);

void main() {
  testWidgets(
      'gerçek wizard maskeli önizleme, açık onay ve partial sonucu gösterir',
      (tester) async {
    final adapter = _ReportAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    expect(find.text('s****************@nutrisense.invalid'), findsOneWidget);
    expect(find.text('+*******0006'), findsOneWidget);
    expect(find.textContaining('E-posta ve SMS yalnız yeni rapor'), findsOneWidget);

    await tester.tap(find.byKey(const Key('report_channel_sms')));
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('report_selection_step')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report_preview_button')));
    await tester.pumpAndSettle();

    expect(adapter.previewCalls, 1);
    expect(find.text('3 kullanıcı onaylı kayıt'), findsOneWidget);
    expect(find.textContaining('2 tahmini porsiyon'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label?.contains(
                  '3 onaylı kayıt',
                ) ==
                true,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('report_continue_to_consent')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('report_voice_command_button')), findsOneWidget);
    final sendButton = find.byKey(const Key('report_send_button'));
    expect(tester.widget<AccessibleButton>(sendButton).onPressed, isNull);

    await tester.tap(find.byKey(const Key('report_explicit_consent')));
    await tester.pump();
    expect(tester.widget<AccessibleButton>(sendButton).onPressed, isNotNull);
    await tester.tap(sendButton);
    await tester.pump();
    expect(tester.widget<AccessibleButton>(sendButton).onPressed, isNull);
    await tester.pumpAndSettle();

    expect(adapter.sendCalls, 1);
    expect(adapter.sentConsent, isTrue);
    expect(adapter.sentContextHash, 'a' * 64);
    expect(adapter.idempotencyKey, isNotEmpty);
    expect(find.textContaining('Bazı kanallar kabul edildi'), findsOneWidget);
    expect(find.text('E-posta: sent'), findsOneWidget);
    expect(find.text('SMS: failed'), findsOneWidget);
    expect(find.textContaining('nihai teslimi kanıtlamaz'), findsOneWidget);
  });

  testWidgets(
      'gerçek rapor wizard yüzde 200 metinde kritik kontrolleri taşırmaz',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 500);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_app(_ReportAdapter(), textScale: 2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('report_selection_step')), findsOneWidget);
  });
}

Widget _app(_ReportAdapter adapter, {double textScale = 1}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://contract.test/api/v1'))
    ..httpClientAdapter = adapter;
  final api = ApiService(
    dio: dio,
    tokenStore: _MemoryTokenStore(),
  );
  return ProviderScope(
    overrides: [
      apiServiceProvider.overrideWithValue(api),
      accessibilityServiceProvider.overrideWithValue(
        _SilentAccessibilityService(),
      ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: const SendReportWizard(assignment: _assignment),
    ),
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

class _ReportAdapter implements HttpClientAdapter {
  int previewCalls = 0;
  int sendCalls = 0;
  bool? sentConsent;
  String? sentContextHash;
  String? idempotencyKey;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/dietitian-reports/preview')) {
      previewCalls += 1;
      final data = Map<String, dynamic>.from(options.data as Map);
      expect(data['channels'], ['email', 'sms']);
      return _json(_fixture('dietitian_report_preview_success.json'));
    }
    if (options.path.endsWith('/send-to-dietitian')) {
      sendCalls += 1;
      final data = Map<String, dynamic>.from(options.data as Map);
      sentConsent = data['consent'] as bool?;
      sentContextHash = data['consent_context_hash'] as String?;
      idempotencyKey = options.headers['Idempotency-Key'] as String?;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return _json(_fixture('dietitian_report_partial_failed.json'));
    }
    return _json({}, status: 404);
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

Map<String, dynamic> _fixture(String name) => jsonDecode(
      File('contracts/fixtures/$name').readAsStringSync(),
    ) as Map<String, dynamic>;
