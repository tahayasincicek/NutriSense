enum AppEnvironment { dev, test, prod }

/// Compile-time application configuration.
///
/// Non-secret values are provided with `--dart-define`. API keys and service
/// credentials must never be embedded in the mobile binary.
abstract final class AppConfig {
  static const String _environmentValue = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Firebase packages and platform credentials are intentionally not bundled.
  /// Enabling this flag fails fast until the optional adapter is implemented.
  static const bool firebaseCrashlyticsRequested = bool.fromEnvironment(
    'ENABLE_FIREBASE_CRASHLYTICS',
    defaultValue: false,
  );

  static AppEnvironment get environment => switch (_environmentValue) {
        'dev' => AppEnvironment.dev,
        'test' => AppEnvironment.test,
        'prod' => AppEnvironment.prod,
        _ => throw StateError(
            'Unsupported APP_ENV "$_environmentValue". Use dev, test, or prod.',
          ),
      };

  /// API root including `/api/v1`, without a trailing slash.
  static String get apiBaseUrl {
    final configured = _apiBaseUrlOverride.trim();
    final value = configured.isNotEmpty
        ? configured
        : switch (environment) {
            AppEnvironment.dev => 'http://10.0.2.2:8000/api/v1',
            AppEnvironment.test => 'http://127.0.0.1:8000/api/v1',
            AppEnvironment.prod => throw StateError(
                'Production requires --dart-define=API_BASE_URL=https://.../api/v1',
              ),
          };

    final normalized =
        value.endsWith('/') ? value.substring(0, value.length - 1) : value;
    final uri = Uri.tryParse(normalized);
    final validScheme = uri?.scheme == 'http' || uri?.scheme == 'https';

    if (uri == null || !uri.hasAuthority || !validScheme) {
      throw StateError('API_BASE_URL must be an absolute HTTP(S) URL.');
    }
    if (environment == AppEnvironment.prod && uri.scheme != 'https') {
      throw StateError('Production API_BASE_URL must use HTTPS.');
    }
    if (uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw StateError(
          'API_BASE_URL must not contain credentials, query, or fragment.');
    }

    return normalized;
  }

  static void validate() {
    apiBaseUrl;
    if (firebaseCrashlyticsRequested) {
      throw StateError(
        'Firebase Crashlytics is disabled: platform credentials and the '
        'optional adapter are not part of this repository.',
      );
    }
  }
}
