import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

enum OfflineRecognitionStatus { success, unavailable, rejected, error }

class OfflineRecognitionOutcome {
  final OfflineRecognitionStatus status;
  final String message;

  /// Model kapsamındaki sınıfın Türkçe adı. Yalnız [status] success ise dolu.
  final String? foodNameTr;

  /// Softmax güveni. Yalnız [status] success ise dolu.
  final double? confidence;

  const OfflineRecognitionOutcome(
    this.status,
    this.message, {
    this.foodNameTr,
    this.confidence,
  });
}

/// Cihaz üstü tanıma, doğrulanmış model + etiket + eşik üçlüsü olmadan
/// kapalı kalır.
abstract interface class OfflineFoodRecognizer {
  bool get isAvailable;
  Future<OfflineRecognitionOutcome> recognize(Uint8List rgbJpegBytes);
  Future<void> dispose();
}

class UnavailableOfflineFoodRecognizer implements OfflineFoodRecognizer {
  const UnavailableOfflineFoodRecognizer();

  @override
  bool get isAvailable => false;

  @override
  Future<OfflineRecognitionOutcome> recognize(Uint8List rgbJpegBytes) async {
    return const OfflineRecognitionOutcome(
      OfflineRecognitionStatus.unavailable,
      'Doğrulanmış çevrimdışı model yüklü değil. Manuel giriş kullanın.',
    );
  }

  @override
  Future<void> dispose() async {}
}

/// Uygulamayla paketlenen TFLite modelini çalıştırır.
///
/// Model yalnız sınıf önerir. Kalori ve besin değeri üretmez; bunlar
/// doğrulanmış kaynaktan gelmelidir. Eşiğin altındaki tahmin sonuç olarak
/// sunulmaz, manuel onaya düşer.
class TfliteFoodRecognizer implements OfflineFoodRecognizer {
  TfliteFoodRecognizer({
    this.modelAsset = 'assets/models/nutrisense_food.tflite',
    this.labelsAsset = 'assets/models/labels.txt',
    this.manifestAsset = 'assets/models/model_manifest.json',
  });

  final String modelAsset;
  final String labelsAsset;
  final String manifestAsset;

  static const _inputSize = 224;

  Interpreter? _interpreter;
  List<String> _labels = const [];
  Map<String, String> _turkishNames = const {};
  double _threshold = 1.0;
  bool _loadFailed = false;

  @override
  bool get isAvailable => _interpreter != null;

  Future<void> _ensureLoaded() async {
    if (_interpreter != null || _loadFailed) return;
    try {
      final manifest = jsonDecode(await rootBundle.loadString(manifestAsset))
          as Map<String, dynamic>;
      final decision = manifest['decision'] as Map<String, dynamic>;
      final threshold = (decision['threshold'] as num).toDouble();
      if (threshold <= 0 || threshold > 1) {
        throw StateError('Model eşiği geçersiz: $threshold');
      }
      _threshold = threshold;
      _turkishNames = (manifest['labels_tr'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value as String));

      _labels = (await rootBundle.loadString(labelsAsset))
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      if (_labels.isEmpty) {
        throw StateError('Etiket dosyası boş');
      }

      final interpreter = await Interpreter.fromAsset(modelAsset);
      final outputShape = interpreter.getOutputTensor(0).shape;
      if (outputShape.last != _labels.length) {
        interpreter.close();
        throw StateError(
          'Model çıkışı ${outputShape.last} sınıf, etiket dosyası '
          '${_labels.length} satır; sözleşme uyuşmuyor.',
        );
      }
      _interpreter = interpreter;
    } on Object {
      // Yükleme başarısızsa kapalı kalınır; yanlış sonuç üretmektense
      // manuel girişe yönlendirmek doğrudur.
      _loadFailed = true;
    }
  }

  /// Görüntüyü modelin beklediği 224x224 RGB [0,255] float tensörüne çevirir.
  ///
  /// Model `include_preprocessing` ile eğitildiği için ayrıca /255
  /// normalizasyonu yapılmaz.
  List<List<List<List<double>>>>? _prepare(Uint8List jpegBytes) {
    final decoded = img.decodeImage(jpegBytes);
    if (decoded == null) return null;
    final square = decoded.width == decoded.height
        ? decoded
        : img.copyResizeCropSquare(decoded, size: _inputSize);
    final resized = square.width == _inputSize && square.height == _inputSize
        ? square
        : img.copyResize(
            square,
            width: _inputSize,
            height: _inputSize,
            interpolation: img.Interpolation.linear,
          );

    return [
      List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r.toDouble(),
            pixel.g.toDouble(),
            pixel.b.toDouble(),
          ];
        }),
      ),
    ];
  }

  @override
  Future<OfflineRecognitionOutcome> recognize(Uint8List rgbJpegBytes) async {
    await _ensureLoaded();
    final interpreter = _interpreter;
    if (interpreter == null) {
      return const OfflineRecognitionOutcome(
        OfflineRecognitionStatus.unavailable,
        'Cihaz üstü model yüklenemedi. Manuel giriş kullanın.',
      );
    }

    final input = _prepare(rgbJpegBytes);
    if (input == null) {
      return const OfflineRecognitionOutcome(
        OfflineRecognitionStatus.error,
        'Görüntü çözülemedi. Lütfen yeniden çekin.',
      );
    }

    final output = [List<double>.filled(_labels.length, 0)];
    try {
      interpreter.run(input, output);
    } on Object {
      return const OfflineRecognitionOutcome(
        OfflineRecognitionStatus.error,
        'Cihaz üstü tanıma çalıştırılamadı. Manuel giriş kullanın.',
      );
    }

    final probabilities = output.first;
    var bestIndex = 0;
    for (var index = 1; index < probabilities.length; index++) {
      if (probabilities[index] > probabilities[bestIndex]) bestIndex = index;
    }
    final confidence = probabilities[bestIndex];
    if (confidence < _threshold) {
      return const OfflineRecognitionOutcome(
        OfflineRecognitionStatus.rejected,
        'Yiyecek güvenilir biçimde tanınamadı. Yeniden çekin veya manuel '
        'giriş kullanın.',
      );
    }

    final label = _labels[bestIndex];
    final turkish = _turkishNames[label] ?? label;
    return OfflineRecognitionOutcome(
      OfflineRecognitionStatus.success,
      '$turkish olarak tanındı.',
      foodNameTr: turkish,
      confidence: confidence,
    );
  }

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}

final offlineFoodRecognizerProvider = Provider<OfflineFoodRecognizer>((ref) {
  final recognizer = TfliteFoodRecognizer();
  ref.onDispose(recognizer.dispose);
  return recognizer;
});
