import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/food_scan/services/food_correction_sample_store.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'nutrisense_corrections_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('stores sanitized processed image and anonymous correction metadata',
      () async {
    final store = FoodCorrectionSampleStore(
      directoryProvider: () async => temporaryDirectory,
    );

    final sample = await store.save(
      processedJpeg: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      correctFoodName: 'Adana Kebap',
      predictedFoodName: 'Levrek',
      confidence: 0.7873,
      captureId: 'capture/one',
    );

    expect(await sample.image.readAsBytes(), [0xff, 0xd8, 0xff, 0xd9]);
    expect(sample.image.parent.path, endsWith('adana_kebap'));
    expect(sample.image.path, endsWith('capture_one.jpg'));

    final metadata = jsonDecode(await sample.metadata.readAsString())
        as Map<String, dynamic>;
    expect(metadata['correct_label'], 'adana_kebap');
    expect(metadata['predicted_label'], 'levrek');
    expect(metadata['confidence'], 0.7873);
    expect(metadata['contains_original_metadata'], isFalse);
    expect(metadata, isNot(contains('user_id')));
  });

  test('rejects empty image data', () async {
    final store = FoodCorrectionSampleStore(
      directoryProvider: () async => temporaryDirectory,
    );

    expect(
      () => store.save(
        processedJpeg: Uint8List(0),
        correctFoodName: 'Muz',
        predictedFoodName: 'Kavun',
        confidence: 0.5,
        captureId: 'capture-two',
      ),
      throwsArgumentError,
    );
  });

  test('clearAll removes retained images and metadata', () async {
    final store = FoodCorrectionSampleStore(
      directoryProvider: () async => temporaryDirectory,
    );
    final sample = await store.save(
      processedJpeg: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      correctFoodName: 'Pirinç Pilavı',
      predictedFoodName: 'Patlamış Mısır',
      confidence: 0.62,
      captureId: 'privacy-cleanup',
    );

    await store.clearAll();

    expect(await sample.image.exists(), isFalse);
    expect(await sample.metadata.exists(), isFalse);
  });
}
