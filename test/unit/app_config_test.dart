import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/config/app_config.dart';

void main() {
  test('derleme ortamı geçerli, merkezi ve secretsızdır', () {
    final environment = AppConfig.environment;
    switch (environment) {
      case AppEnvironment.dev:
        expect(AppConfig.apiBaseUrl, 'http://10.0.2.2:8000/api/v1');
        expect(AppConfig.diagnosticLoggingEnabled, isTrue);
        break;
      case AppEnvironment.test:
        expect(AppConfig.apiBaseUrl, 'http://127.0.0.1:8000/api/v1');
        expect(AppConfig.diagnosticLoggingEnabled, isTrue);
        break;
      case AppEnvironment.staging:
      case AppEnvironment.prod:
        expect(Uri.parse(AppConfig.apiBaseUrl).scheme, 'https');
        expect(AppConfig.diagnosticLoggingEnabled, isFalse);
        break;
    }
    expect(AppConfig.firebaseCrashlyticsRequested, isFalse);
    expect(AppConfig.validate, returnsNormally);
  });
}
