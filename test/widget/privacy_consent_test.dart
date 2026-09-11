import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/auth/screens/privacy_consent_screen.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';
import 'package:nutrisense/shared/services/api_service.dart';

void main() {
  // Aydınlatma metni uzun; kısa test penceresinde alt bölümler tembel kalıyor.
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

  testWidgets('aydınlatma metni rıza anahtarlarından ayrı sunulur',
      (tester) async {
    final adapter = _ConsentAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    expect(find.text('Aydınlatma Metni'), findsOneWidget);
    expect(find.text('İzinleriniz'), findsOneWidget);
    // Her amaç için ayrı anahtar; tek kutucukta birleştirilmez.
    expect(find.byType(Switch), findsNWidgets(2));
  });

  testWidgets('izinler kapalı başlar ve sessiz kabul edilmez', (tester) async {
    final adapter = _ConsentAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    for (final widget in tester.widgetList<Switch>(find.byType(Switch))) {
      expect(widget.value, isFalse);
    }
  });

  testWidgets('her izin ayrı ayrı kaydedilir', (tester) async {
    final adapter = _ConsentAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    // Yalnız yurt dışı aktarımına izin verilir.
    await tester.tap(find.byKey(const Key('privacy_notice_acknowledgement')));
    await tester.pump();
    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    await tester.tap(find.text('Tercihlerimi Kaydet'));
    await tester.pumpAndSettle();

    expect(adapter.saved['privacy_notice_acknowledgement'], isTrue);
    expect(adapter.saved['health_data_processing'], isFalse);
    expect(adapter.saved['image_cross_border_transfer'], isTrue);
  });

  testWidgets('aydınlatma teyidi olmadan tercihler kaydedilmez',
      (tester) async {
    final adapter = _ConsentAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tercihlerimi Kaydet'));
    await tester.pump();

    expect(adapter.saved, isEmpty);
    expect(find.textContaining('aydınlatma metnini okuyup'), findsOneWidget);
  });

  testWidgets('zorunlu aydınlatma kapısı geri tuşuyla atlanamaz',
      (tester) async {
    final adapter = _ConsentAdapter();
    await tester.pumpWidget(_app(adapter, requiredForEntry: true));
    await tester.pumpAndSettle();

    expect(find.text('Kabul Etmeden Çıkış Yap'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Kişisel Verileriniz'), findsOneWidget);
  });

  testWidgets('taslak uyarısı kullanıcıdan gizlenmez', (tester) async {
    final adapter = _ConsentAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bu sürüm taslaktır'), findsOneWidget);
  });
}

Widget _app(_ConsentAdapter adapter, {bool requiredForEntry = false}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://contract.test/api/v1'))
    ..httpClientAdapter = adapter;
  return ProviderScope(
    overrides: [
      apiServiceProvider.overrideWithValue(
        ApiService(dio: dio, tokenStore: _MemoryTokenStore()),
      ),
      accessibilityServiceProvider.overrideWithValue(_SilentAccessibility()),
    ],
    child: MaterialApp(
      home: PrivacyConsentScreen(requiredForEntry: requiredForEntry),
    ),
  );
}

class _SilentAccessibility extends AccessibilityService {
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

class _ConsentAdapter implements HttpClientAdapter {
  final Map<String, bool> saved = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PUT' && options.path.endsWith('/consents')) {
      final data = Map<String, dynamic>.from(options.data as Map);
      saved[data['consent_type'] as String] = data['granted'] as bool;
    }
    return _json({
      'policy_version': 'taslak-yayinlanmadi',
      'consents': const [],
      'health_data_processing': saved['health_data_processing'] ?? false,
      'image_cross_border_transfer':
          saved['image_cross_border_transfer'] ?? false,
    });
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
