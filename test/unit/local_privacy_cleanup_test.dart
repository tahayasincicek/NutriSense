import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/food_scan/services/food_correction_sample_store.dart';
import 'package:nutrisense/shared/services/local_privacy_cleanup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporaryDirectory;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_session_v1': 'token',
      'activity_state_v1': 'health',
      'food_history_cache_v1_user': 'history',
      'food_history_cache_index_v1': '["food_history_cache_v1_user"]',
      'research_withdrawal_code_v1': 'must-stay',
    });
    SharedPreferences.setMockInitialValues({
      'activity_state_v1': 'legacy-health',
      'activity_state_day': '2026-09-25',
      'dark_mode': true,
    });
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'nutrisense_privacy_cleanup_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('logout cleanup removes secure values and correction photos', () async {
    const storage = FlutterSecureStorage();
    final corrections = FoodCorrectionSampleStore(
      directoryProvider: () async => temporaryDirectory,
    );
    final sample = await corrections.save(
      processedJpeg: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      correctFoodName: 'Elma',
      predictedFoodName: 'Şeftali',
      confidence: 0.55,
      captureId: 'cleanup-test',
    );
    final cleanup = LocalPrivacyCleanup(
      storage: storage,
      correctionSamples: corrections,
    );

    await cleanup.clearAccountData();

    expect(await storage.read(key: 'auth_session_v1'), isNull);
    expect(await storage.read(key: 'activity_state_v1'), isNull);
    expect(await storage.read(key: 'food_history_cache_v1_user'), isNull);
    expect(
      await storage.read(key: 'research_withdrawal_code_v1'),
      'must-stay',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('activity_state_v1'), isNull);
    expect(preferences.getString('activity_state_day'), isNull);
    expect(preferences.getBool('dark_mode'), isTrue);
    expect(await sample.image.exists(), isFalse);
    expect(await sample.metadata.exists(), isFalse);
  });
}
