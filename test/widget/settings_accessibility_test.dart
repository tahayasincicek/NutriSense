import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/auth/state/auth_controller.dart';
import 'package:nutrisense/features/history/data/history_cache_store.dart';
import 'package:nutrisense/features/settings/screens/settings_screen.dart';
import 'package:nutrisense/shared/models/auth_model.dart';
import 'package:nutrisense/shared/services/api_service.dart';
import 'package:nutrisense/shared/services/stt_service.dart';

void main() {
  testWidgets('profil başlığında oturumdaki kullanıcı adı gösterilir',
      (tester) async {
    final auth = _FakeAuthController();
    auth.state = const AuthState(
      AuthStatus.authenticated,
      user: UserProfile(
        id: 'user-1',
        email: 'ayse@example.com',
        fullName: 'Ayşe Yılmaz',
        isActive: true,
      ),
    );

    await tester.pumpWidget(
      _app(auth: auth, stt: _FakeSttService(const [])),
    );
    await tester.pump();

    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('Kullanıcı Profili'), findsNothing);
    expect(find.text('Premium Üye'), findsNothing);
  });

  testWidgets('tek başına çıkış komutu oturumu kapatmaz, onay ister',
      (tester) async {
    final auth = _FakeAuthController();
    // Yalnız komut var, onay yok: oturum kapanmamalı.
    final stt = _FakeSttService([
      const SttResult(text: 'çıkış yap', confidence: 1, isFinal: true),
    ]);
    await tester.pumpWidget(_app(auth: auth, stt: stt));
    await tester.pumpAndSettle();

    _invokeVoiceButton(tester);
    await tester.pumpAndSettle();

    expect(auth.logoutCount, 0);
    expect(find.textContaining('evet deyin'), findsOneWidget);
    // Kullanıcıya göremediği bir düğme tarif edilmemeli.
    expect(find.textContaining('Mikrofon düğmesine'), findsNothing);
  });

  testWidgets('komuttan sonra söylenen evet oturumu kapatır', (tester) async {
    final auth = _FakeAuthController();
    // Onay için mikrofon kendiliğinden yeniden açıldığından ikinci bir
    // düğmeye basış gerekmez; ayrı bir "evet" söylenmesi hâlâ zorunludur.
    final stt = _FakeSttService([
      const SttResult(text: 'çıkış yap', confidence: 1, isFinal: true),
      const SttResult(text: 'evet', confidence: 1, isFinal: true),
    ]);
    await tester.pumpWidget(_app(auth: auth, stt: stt));
    await tester.pumpAndSettle();

    _invokeVoiceButton(tester);
    await tester.pumpAndSettle();

    expect(auth.logoutCount, 1);
  });

  testWidgets('kısmi çıkış transkripti oturumu kapatmaz', (tester) async {
    final auth = _FakeAuthController();
    final stt = _FakeSttService([
      const SttResult(text: 'çıkış yap', confidence: 1, isFinal: false),
    ]);
    await tester.pumpWidget(_app(auth: auth, stt: stt));
    await tester.pumpAndSettle();

    _invokeVoiceButton(tester);
    await tester.pumpAndSettle();

    expect(auth.logoutCount, 0);
    expect(find.textContaining('Komut henüz çalıştırılmadı'), findsOneWidget);
  });

  testWidgets('Ayarlar yüzde 200 yazıda kaydırılabilir ve taşmaz',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      _app(
        auth: _FakeAuthController(),
        stt: _FakeSttService(const []),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byKey(const Key('settings_voice_action')), findsOneWidget);
  });
}

Widget _app({
  required _FakeAuthController auth,
  required SttService stt,
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith((ref) => auth),
      sttServiceProvider.overrideWithValue(stt),
    ],
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SettingsScreen(),
      ),
    ),
  );
}

void _invokeVoiceButton(WidgetTester tester) {
  final button = tester.widget<IconButton>(
    find.byKey(const Key('settings_voice_action')),
  );
  expect(button.onPressed, isNotNull);
  button.onPressed!.call();
}

class _FakeSttService extends SttService {
  _FakeSttService(this.results);

  final List<SttResult> results;

  @override
  Future<void> startListening({
    required void Function(SttResult) onResult,
    void Function(String)? onError,
    void Function()? onListeningStarted,
    void Function()? onListeningStopped,
    String? locale,
    Duration listenFor = const Duration(seconds: 30),
  }) async {
    onListeningStarted?.call();
    if (results.isNotEmpty) onResult(results.removeAt(0));
    onListeningStopped?.call();
  }

  @override
  Future<void> cancelListening() async {}

  @override
  void dispose() {}
}

class _FakeAuthController extends AuthController {
  _FakeAuthController()
      : super(
          ApiService(dio: Dio(), tokenStore: _MemoryTokenStore()),
          _MemoryHistoryCache(),
        );

  int logoutCount = 0;

  @override
  Future<void> bootstrap() async {}

  @override
  Future<void> logout() async {
    logoutCount += 1;
    state = const AuthState(AuthStatus.unauthenticated);
  }
}

class _MemoryTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> write(AuthSession session) async {}
}

class _MemoryHistoryCache implements HistoryCacheStore {
  @override
  Future<void> clear(String userId) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<HistoryCacheSnapshot?> read(String userId) async => null;

  @override
  Future<void> write(String userId, history) async {}
}
