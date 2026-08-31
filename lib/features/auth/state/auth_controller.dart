import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/auth_model.dart';
import '../../../shared/services/api_service.dart';
import '../../history/data/history_cache_store.dart';

enum AuthStatus {
  unknown,
  loading,
  unauthenticated,
  authenticated,
  locked,
}

class AuthState {
  final AuthStatus status;
  final UserProfile? user;
  final String? message;

  const AuthState(this.status, {this.user, this.message});
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._api, this._historyCache)
      : super(const AuthState(AuthStatus.unknown)) {
    unawaited(bootstrap());
  }

  final ApiService _api;
  final HistoryCacheStore _historyCache;

  Future<void> bootstrap() async {
    state = const AuthState(AuthStatus.loading);
    await _api.initialize();
    if (!_api.isAuthenticated) {
      state = const AuthState(AuthStatus.unauthenticated);
      return;
    }

    final profile = await _api.getCurrentUser();
    if (profile.isSuccess && profile.data?.isActive == true) {
      state = AuthState(AuthStatus.authenticated, user: profile.data);
      return;
    }

    state = const AuthState(
      AuthStatus.locked,
      message:
          'Oturumunuzun süresi doldu. Güvenliğiniz için yeniden giriş yapın.',
    );
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final result = await _api.login(email: email, password: password);
    if (!result.isSuccess) {
      state = const AuthState(AuthStatus.unauthenticated);
      return result.errorMessage ?? 'Giriş tamamlanamadı.';
    }
    return _loadAuthenticatedProfile();
  }

  Future<String?> loginDietitian({
    required String email,
    required String password,
  }) async {
    final result = await _api.login(email: email, password: password);
    if (!result.isSuccess) {
      state = const AuthState(AuthStatus.unauthenticated);
      return result.errorMessage ?? 'Diyetisyen girişi tamamlanamadı.';
    }
    return _loadAuthenticatedProfile(requiredAccountType: 'dietitian');
  }

  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final result = await _api.register(
      email: email,
      password: password,
      fullName: fullName,
    );
    if (!result.isSuccess) {
      state = const AuthState(AuthStatus.unauthenticated);
      return result.errorMessage ?? 'Hesap oluşturulamadı.';
    }
    return _loadAuthenticatedProfile();
  }

  Future<String?> registerDietitian({
    required String fullName,
    required String email,
    required String password,
    required String specialization,
    String? phone,
  }) async {
    final result = await _api.registerDietitian(
      email: email,
      password: password,
      fullName: fullName,
      specialization: specialization,
      phone: phone,
    );
    if (!result.isSuccess) {
      state = const AuthState(AuthStatus.unauthenticated);
      return result.errorMessage ?? 'Diyetisyen hesabı oluşturulamadı.';
    }
    return _loadAuthenticatedProfile(requiredAccountType: 'dietitian');
  }

  Future<String?> _loadAuthenticatedProfile(
      {String? requiredAccountType}) async {
    final profile = await _api.getCurrentUser();
    if (!profile.isSuccess || profile.data?.isActive != true) {
      await _api.logout();
      await _historyCache.clearAll();
      state = const AuthState(AuthStatus.unauthenticated);
      return profile.errorMessage ?? 'Kullanıcı profili doğrulanamadı.';
    }
    if (requiredAccountType != null &&
        profile.data!.accountType != requiredAccountType) {
      await _api.logout();
      state = const AuthState(AuthStatus.unauthenticated);
      return 'Bu hesap bir diyetisyen hesabı değil.';
    }

    // Önce loading durumuna geçir — bu LoginScreen'deki TextFormField'ların
    // odağını kaybetmesini ve render objelerinin temizlenmesini sağlar.
    state = const AuthState(AuthStatus.loading);

    // Bir frame bekle: TextFormField'ın zamanlanmış imleç callback'leri
    // (scheduleShowCaretOnScreen) bu frame'de çalışıp tamamlansın.
    // Bu olmadan Flutter'ın _dependents.isEmpty assertion hatası oluşuyor.
    await Future.delayed(const Duration(milliseconds: 300));

    state = AuthState(AuthStatus.authenticated, user: profile.data);
    return null;
  }

  Future<void> logout() async {
    state = const AuthState(AuthStatus.loading);
    await _api.logout();
    await _historyCache.clearAll();
    state = const AuthState(AuthStatus.unauthenticated);
  }

  Future<String?> deleteAccount(String password) async {
    final result = await _api.deleteAccount(password: password);
    if (!result.isSuccess) {
      return result.errorMessage ?? 'Hesap silinemedi.';
    }
    await _historyCache.clearAll();
    state = const AuthState(AuthStatus.unauthenticated);
    return null;
  }

  Future<void> unlockToLogin() async {
    await _api.logout();
    await _historyCache.clearAll();
    state = const AuthState(AuthStatus.unauthenticated);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.read(apiServiceProvider),
    ref.read(historyCacheStoreProvider),
  );
});
