import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/config/app_config.dart';

void main() {
  test('varsayılan geliştirme ortamı geçerli ve secretsızdır', () {
    expect(AppConfig.environment, AppEnvironment.dev);
    expect(AppConfig.apiBaseUrl, 'http://10.0.2.2:8000/api/v1');
    expect(AppConfig.firebaseCrashlyticsRequested, isFalse);
    expect(AppConfig.validate, returnsNormally);
  });
}
