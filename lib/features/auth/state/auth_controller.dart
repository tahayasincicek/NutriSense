import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/auth_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/local_privacy_cleanup.dart';
import '../../food_scan/services/food_correction_sample_store.dart';
import '../../history/data/history_cache_store.dart';

enum AuthStatus {
  unknown,
  loading,
  unauthenticated,
  privacyNoticeRequired,
  authenticated,
  locked,
}

class AuthState {
  final AuthStatus status;
  final UserProfile? user;
  final String? message;

  const AuthState(this.status, {this.user, this.message});
}

typedef LocalAccountDataCleanup = Future<void> Function();

class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._api,
    this._historyCache, {
    LocalAccountDataCleanup? localAccountDataCleanup,
  })  : _localAccountDataCleanup = localAccountDataCleanup,
        super(const AuthState(AuthStatus.unknown)) {
    unawaited(bootstrap());
  }

  final ApiService _api;
  final HistoryCacheStore _historyCache;
  final LocalAccountDataCleanup? _localAccountDataCleanup;

  Future<void> _clearLocalAccountData() async {
    await _historyCache.clearAll();
    await _localAccountDataCleanup?.call();
  }

  Future<void> bootstrap() async {
    state = const AuthState(AuthStatus.loading);
    await _api.initialize();
    if (!_api.isAuthenticated) {
      await _clearLocalAccountData();
      state = const AuthState(AuthStatus.unauthenticated);
      return;
    }

    final profile = await _api.getCurrentUser();
    if (profile.isSuccess && profile.data?.isActive == true) {
      if (profile.data!.accountType != 'dietitian' &&
          !await _hasPrivacyNoticeAcknowledgement()) {
        state = AuthState(
          AuthStatus.privacyNoticeRequired,
          user: profile.data,
        );
        return;
      }
      state = AuthState(AuthStatus.authenticated, user: profile.data);
      return;
    }

    await _api.logout();
    await _clearLocalAccountData();
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

  /// Kaydı başlatır. Başarılıysa `null` döner; hesap e-postaya gelen kod
  /// [confirmRegistration] ile doğrulanınca açılır.
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
      return result.errorMessage ?? 'Kayıt başlatılamadı.';
    }
    return null;
  }

  /// E-postaya gelen kodla hesabı açar ve oturumu başlatır.
  Future<String?> confirmRegistration({
    required String email,
    required String code,
  }) async {
    final result = await _api.confirmRegistration(email: email, code: code);
    if (!result.isSuccess) {
      return result.errorMessage ?? 'Kod doğrulanamadı.';
    }
    return _loadAuthenticatedProfile();
  }

  /// Diyetisyen kaydını başlatır. Başarılıysa `null` döner; hesap e-postaya
  /// gelen kod [confirmRegistration] ile doğrulanınca açılır.
  Future<String?> registerDietitian({
    required String fullName,
    required String email,
    required String password,
    required String specialization,
    String? phone,
    required bool dataProcessingAgreementAccepted,
    required String dataProcessingAgreementVersion,
  }) async {
    final result = await _api.registerDietitian(
      email: email,
      password: password,
      fullName: fullName,
      specialization: specialization,
      phone: phone,
      dataProcessingAgreementAccepted: dataProcessingAgreementAccepted,
      dataProcessingAgreementVersion: dataProcessingAgreementVersion,
    );
    if (!result.isSuccess) {
      state = const AuthState(AuthStatus.unauthenticated);
      return result.errorMessage ?? 'Diyetisyen kaydı başlatılamadı.';
    }
    return null;
  }

  Future<String?> _loadAuthenticatedProfile(
      {String? requiredAccountType}) async {
    final profile = await _api.getCurrentUser();
    if (!profile.isSuccess || profile.data?.isActive != true) {
      await _api.logout();
      await _clearLocalAccountData();
      state = const AuthState(AuthStatus.unauthenticated);
      return profile.errorMessage ?? 'Kullanıcı profili doğrulanamadı.';
    }
    if (requiredAccountType != null &&
        profile.data!.accountType != requiredAccountType) {
      await _api.logout();
      await _clearLocalAccountData();
      state = const AuthState(AuthStatus.unauthenticated);
      return 'Bu hesap bir diyetisyen hesabı değil.';
    }
    if (profile.data!.accountType != 'dietitian' &&
        !await _hasPrivacyNoticeAcknowledgement()) {
      state = AuthState(
        AuthStatus.privacyNoticeRequired,
        user: profile.data,
      );
      return null;
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

  Future<bool> _hasPrivacyNoticeAcknowledgement() async {
    final result = await _api.getConsents();
    return result.isSuccess &&
        result.data?['privacy_notice_acknowledgement'] == true;
  }

  Future<bool> completePrivacyNoticeGate() async {
    final user = state.user;
    if (user == null || !await _hasPrivacyNoticeAcknowledgement()) {
      return false;
    }
    state = AuthState(AuthStatus.authenticated, user: user);
    return true;
  }

  Future<String?> confirmEmailChange(String code) async {
    final result = await _api.confirmEmailChange(code: code);
    if (!result.isSuccess) {
      return result.errorMessage ?? 'E-posta değiştirilemedi.';
    }
    return _loadAuthenticatedProfile(
      requiredAccountType:
          state.user?.accountType == 'dietitian' ? 'dietitian' : null,
    );
  }

  Future<void> logout() async {
    state = const AuthState(AuthStatus.loading);
    await _api.logout();
    await _clearLocalAccountData();
    state = const AuthState(AuthStatus.unauthenticated);
  }

  Future<String?> deleteAccount(String password) async {
    final result = await _api.deleteAccount(password: password);
    if (!result.isSuccess) {
      return result.errorMessage ?? 'Hesap silinemedi.';
    }
    await _clearLocalAccountData();
    state = const AuthState(AuthStatus.unauthenticated);
    return null;
  }

  Future<void> unlockToLogin() async {
    await _api.logout();
    await _clearLocalAccountData();
    state = const AuthState(AuthStatus.unauthenticated);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final privacyCleanup = LocalPrivacyCleanup(
    correctionSamples: ref.read(foodCorrectionSampleStoreProvider),
  );
  return AuthController(
    ref.read(apiServiceProvider),
    ref.read(historyCacheStoreProvider),
    localAccountDataCleanup: privacyCleanup.clearAccountData,
  );
});
