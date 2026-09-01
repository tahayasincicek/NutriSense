import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/auth/screens/auth_gate.dart';
import 'package:nutrisense/features/auth/state/auth_controller.dart';
import 'package:nutrisense/features/history/data/history_cache_store.dart';
import 'package:nutrisense/shared/models/auth_model.dart';
import 'package:nutrisense/shared/services/api_service.dart';

import '../support/platform_channel_mocks.dart';

/// Ayarlar gibi ekranlar AuthGate'in üstüne push edilir. Oturum kapanınca
/// altta giriş ekranı kurulsa da bu sayfalar yığında kalırsa kullanıcı
/// hiçbir değişiklik görmez; görme engelli kullanıcı için bu, kapandığını
/// sandığı oturumda kalmak demektir.
void main() {
  setUp(mockSecureStorage);

  testWidgets('oturum kapanınca üste itilmiş ekranlar yığından kalkar',
      (tester) async {
    final auth = _FakeAuthController();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Ayarlar sayfası')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ayarlar sayfası'), findsOneWidget);

    auth.signOut();
    await tester.pumpAndSettle();

    expect(find.text('Ayarlar sayfası'), findsNothing);
  });

  testWidgets('oturum kilitlenince de yığın köke iner', (tester) async {
    final auth = _FakeAuthController();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Ayarlar sayfası')),
      ),
    );
    await tester.pumpAndSettle();

    auth.lock();
    await tester.pumpAndSettle();

    expect(find.text('Ayarlar sayfası'), findsNothing);
    expect(find.text('Yeniden Giriş Yap'), findsOneWidget);
  });

  testWidgets('oturum sürerken açılan ekran kendiliğinden kapanmaz',
      (tester) async {
    final auth = _FakeAuthController();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Ayarlar sayfası')),
      ),
    );
    await tester.pumpAndSettle();

    // Profil güncellemesi gibi oturum içi bir durum değişimi gezinmeyi
    // etkilememeli.
    auth.refreshProfile();
    await tester.pumpAndSettle();

    expect(find.text('Ayarlar sayfası'), findsOneWidget);
  });
}

Widget _app(_FakeAuthController auth) {
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith((ref) => auth)],
    child: const MaterialApp(home: AuthGate()),
  );
}

class _FakeAuthController extends AuthController {
  _FakeAuthController()
      : super(
          ApiService(dio: Dio(), tokenStore: _MemoryTokenStore()),
          _MemoryHistoryCache(),
        ) {
    state = AuthState(AuthStatus.authenticated, user: _user('Sentetik Hasta'));
  }

  /// Gerçek yapıcı bootstrap()'ı tetikler ve durumu unauthenticated'a
  /// çevirir; test oturumu açık başlatabilmek için devre dışı bırakılır.
  @override
  Future<void> bootstrap() async {}

  void signOut() => state = const AuthState(AuthStatus.unauthenticated);

  void lock() => state = const AuthState(
        AuthStatus.locked,
        message: 'Oturum kilitlendi.',
      );

  void refreshProfile() =>
      state = AuthState(AuthStatus.authenticated, user: _user('Yeni Ad'));
}

UserProfile _user(String name) => UserProfile(
      id: 'synthetic-user',
      email: 'sentetik@nutrisense.invalid',
      fullName: name,
      isActive: true,
    );

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
