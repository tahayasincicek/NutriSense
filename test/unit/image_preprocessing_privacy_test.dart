import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nutrisense/features/food_scan/services/image_preprocessing.dart';

/// Galeriden seçilen fotoğraf konum ve cihaz bilgisi taşıyabilir. Analize
/// giden JPEG bu alanları içermemelidir.
void main() {
  test('işlenen fotoğrafta kaynağın EXIF alanları kalmaz', () async {
    final source = img.Image(width: 320, height: 240);
    img.fill(source, color: img.ColorRgb8(180, 120, 60));
    source.exif.imageIfd.make = 'NutriSenseTestPhone';
    final bytes = Uint8List.fromList(img.encodeJpg(source));
    expect(img.decodeJpg(bytes)!.exif.imageIfd.make, 'NutriSenseTestPhone');

    final result = await ImagePreprocessor.processImage(imageBytes: bytes);

    expect(result.processedBytes, isNotEmpty);
    final processed = img.decodeJpg(result.processedBytes)!;
    expect(processed.exif.imageIfd.make, isNull);
  });
}
