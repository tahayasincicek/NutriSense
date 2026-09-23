import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

typedef CorrectionStorageDirectory = Future<Directory> Function();

final foodCorrectionSampleStoreProvider = Provider<FoodCorrectionSampleStore>(
  (ref) => FoodCorrectionSampleStore(),
);

/// Stores user-confirmed recognition mistakes for later, local model training.
///
/// Only the already resized and re-encoded model input is stored. The original
/// camera/gallery file, EXIF metadata and user identity are never copied here.
class FoodCorrectionSampleStore {
  FoodCorrectionSampleStore({CorrectionStorageDirectory? directoryProvider})
      : _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory;

  final CorrectionStorageDirectory _directoryProvider;

  Future<FoodCorrectionSample> save({
    required Uint8List processedJpeg,
    required String correctFoodName,
    required String predictedFoodName,
    required double confidence,
    required String captureId,
  }) async {
    if (processedJpeg.isEmpty) {
      throw ArgumentError.value(processedJpeg, 'processedJpeg', 'Boş olamaz.');
    }
    final correctLabel = _safeLabel(correctFoodName);
    final predictedLabel = _safeLabel(predictedFoodName);
    if (correctLabel.isEmpty) {
      throw ArgumentError.value(
        correctFoodName,
        'correctFoodName',
        'Geçerli bir besin adı olmalıdır.',
      );
    }

    final root = await _directoryProvider();
    final classDirectory = Directory(
      '${root.path}${Platform.pathSeparator}food_corrections'
      '${Platform.pathSeparator}$correctLabel',
    );
    await classDirectory.create(recursive: true);

    final safeCaptureId = _safeFilePart(captureId);
    final stem = safeCaptureId.isEmpty
        ? DateTime.now().toUtc().microsecondsSinceEpoch.toString()
        : safeCaptureId;
    final image = File(
      '${classDirectory.path}${Platform.pathSeparator}$stem.jpg',
    );
    final metadata = File(
      '${classDirectory.path}${Platform.pathSeparator}$stem.json',
    );
    await image.writeAsBytes(processedJpeg, flush: true);
    await metadata.writeAsString(
      jsonEncode({
        'schema_version': 1,
        'image_file': image.uri.pathSegments.last,
        'correct_label': correctLabel,
        'correct_name_tr': correctFoodName.trim(),
        'predicted_label': predictedLabel,
        'predicted_name_tr': predictedFoodName.trim(),
        'confidence': confidence.clamp(0.0, 1.0),
        'captured_at_utc': DateTime.now().toUtc().toIso8601String(),
        'source': 'user_correction',
        'contains_original_metadata': false,
      }),
      flush: true,
    );
    return FoodCorrectionSample(image: image, metadata: metadata);
  }

  static String _safeLabel(String value) {
    const replacements = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
    };
    var normalized = value.trim().toLowerCase();
    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String _safeFilePart(String value) => value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

class FoodCorrectionSample {
  const FoodCorrectionSample({required this.image, required this.metadata});

  final File image;
  final File metadata;
}
