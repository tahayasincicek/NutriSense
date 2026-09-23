enum AppEnvironment { dev, test, staging, prod }

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

  static const String privacyNoticeVersion = String.fromEnvironment(
    'PRIVACY_NOTICE_VERSION',
    defaultValue: 'taslak-yayinlanmadi',
  );
  static const String dataControllerName = String.fromEnvironment(
    'DATA_CONTROLLER_NAME',
  );
  static const String dataControllerContactEmail = String.fromEnvironment(
    'DATA_CONTROLLER_CONTACT_EMAIL',
  );
  static const String dataControllerPostalAddress = String.fromEnvironment(
    'DATA_CONTROLLER_POSTAL_ADDRESS',
  );
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
  );
  static const String accountDeletionUrl = String.fromEnvironment(
    'ACCOUNT_DELETION_URL',
  );

  /// Firebase packages and platform credentials are intentionally not bundled.
  /// Enabling this flag fails fast until the optional adapter is implemented.
  static const bool firebaseCrashlyticsRequested = bool.fromEnvironment(
    'ENABLE_FIREBASE_CRASHLYTICS',
    defaultValue: false,
  );

  /// Console diagnostics are available only in non-release environments.
  ///
  /// `kDebugMode` is still checked at each log call, so this public flag
  /// cannot enable logging in an optimized release binary.
  static bool get diagnosticLoggingEnabled =>
      {AppEnvironment.dev, AppEnvironment.test}.contains(environment);

  static AppEnvironment get environment => switch (_environmentValue) {
        'dev' => AppEnvironment.dev,
        'test' => AppEnvironment.test,
        'staging' => AppEnvironment.staging,
        'prod' => AppEnvironment.prod,
        _ => throw StateError(
            'Unsupported APP_ENV "$_environmentValue". '
            'Use dev, test, staging, or prod.',
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
            AppEnvironment.staging => throw StateError(
                'Staging requires '
                '--dart-define=API_BASE_URL=https://.../api/v1',
              ),
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
    if ({AppEnvironment.staging, AppEnvironment.prod}.contains(environment) &&
        uri.scheme != 'https') {
      throw StateError('Staging and production API_BASE_URL must use HTTPS.');
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
    if (environment == AppEnvironment.prod) {
      final requiredLegalValues = {
        'PRIVACY_NOTICE_VERSION': privacyNoticeVersion,
        'DATA_CONTROLLER_NAME': dataControllerName,
        'DATA_CONTROLLER_CONTACT_EMAIL': dataControllerContactEmail,
        'DATA_CONTROLLER_POSTAL_ADDRESS': dataControllerPostalAddress,
        'PRIVACY_POLICY_URL': privacyPolicyUrl,
        'ACCOUNT_DELETION_URL': accountDeletionUrl,
      };
      final missing = requiredLegalValues.entries
          .where((entry) =>
              entry.value.trim().isEmpty ||
              entry.value.toLowerCase().contains('taslak') ||
              entry.value.toUpperCase().contains('REPLACE'))
          .map((entry) => entry.key)
          .toList();
      if (missing.isNotEmpty) {
        throw StateError(
          'Production legal configuration is incomplete: ${missing.join(', ')}',
        );
      }
      if (!dataControllerContactEmail.contains('@')) {
        throw StateError(
            'DATA_CONTROLLER_CONTACT_EMAIL must be an email address.');
      }
      for (final entry in {
        'PRIVACY_POLICY_URL': privacyPolicyUrl,
        'ACCOUNT_DELETION_URL': accountDeletionUrl,
      }.entries) {
        final uri = Uri.tryParse(entry.value);
        if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
          throw StateError('${entry.key} must be a public HTTPS URL.');
        }
      }
    }
    if (firebaseCrashlyticsRequested) {
      throw StateError(
        'Firebase Crashlytics is disabled: platform credentials and the '
        'optional adapter are not part of this repository.',
      );
    }
  }
}
