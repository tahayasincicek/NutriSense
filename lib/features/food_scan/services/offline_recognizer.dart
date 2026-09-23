import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../shared/models/food_analysis_model.dart';

enum OfflineRecognitionStatus {
  success,
  suggestion,
  unavailable,
  rejected,
  error,
}

class OfflineRecognitionOutcome {
  final OfflineRecognitionStatus status;
  final String message;

  /// Model kapsamındaki sınıfın Türkçe adı. Başarı veya kullanıcı onayı
  /// gerektiren öneri durumunda doludur.
  final String? foodNameTr;

  /// Softmax güveni. Başarı veya öneri durumunda doludur.
  final double? confidence;

  /// En yüksek olasılıklı seçenekler. Kullanıcı özellikle düşük güvenli
  /// sonuçlarda doğru besini ilk üç aday arasından seçebilir.
  final List<FoodCandidate> candidates;

  const OfflineRecognitionOutcome(
    this.status,
    this.message, {
    this.foodNameTr,
    this.confidence,
    this.candidates = const [],
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

  // Manifest eşiği yüksek kesinlikte otomatik öneri içindir. Bu daha düşük
  // eşik, tahmini açıkça "olası" olarak sunup kullanıcı onayı istemek için
  // kullanılır; tanımayı tamamen işlevsiz bırakacak kadar yükseltilmemelidir.
  static const _suggestionThreshold = 0.20;

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
      debugPrint(
        'NutriSense model loaded: labels=${_labels.length}, '
        'acceptThreshold=${_threshold.toStringAsFixed(4)}, '
        'suggestionThreshold=$_suggestionThreshold',
      );
    } on Object catch (error, stackTrace) {
      // Yükleme başarısızsa kapalı kalınır; yanlış sonuç üretmektense
      // manuel girişe yönlendirmek doğrudur.
      debugPrint('NutriSense model load failed: $error\n$stackTrace');
      _loadFailed = true;
    }
  }

  /// Görüntüyü modelin beklediği 224x224 RGB [0,255] float tensörüne çevirir.
  ///
  /// Model `include_preprocessing` ile eğitildiği için ayrıca /255
  /// normalizasyonu yapılmaz.
  List<List<img.Image>>? _prepareViewGroups(Uint8List jpegBytes) {
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

    img.Image crop(double fraction) {
      if (fraction == 1) return resized;
      final cropSize = (_inputSize * fraction).round();
      final cropInset = ((_inputSize - cropSize) / 2).round();
      return img.copyResize(
        img.copyCrop(
          resized,
          x: cropInset,
          y: cropInset,
          width: cropSize,
          height: cropSize,
        ),
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.linear,
      );
    }

    // İlk iki ölçek mevcut hızlı yol. Bu iki ölçek farklı sınıflar önerirse
    // veya birleşik güven düşük kalırsa nesne kadrajda küçük ya da çevresi
    // dikkat dağıtıcı olabilir; daha yakın üç merkez görünümü çalıştırılır.
    return [1.0, 0.9, 0.75, 0.6, 0.5].map((fraction) {
      final view = crop(fraction);
      return [view, img.flipHorizontal(view)];
    }).toList(growable: false);
  }

  int _argMax(List<double> values) {
    var best = 0;
    for (var index = 1; index < values.length; index++) {
      if (values[index] > values[best]) best = index;
    }
    return best;
  }

  double _maxAveragedConfidence(List<double> first, List<double> second) {
    var best = 0.0;
    for (var index = 0; index < first.length; index++) {
      final value = (first[index] + second[index]) / 2;
      if (value > best) best = value;
    }
    return best;
  }

  List<List<List<List<double>>>> _toTensor(img.Image image) {
    return [
      List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = image.getPixel(x, y);
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

    final viewGroups = _prepareViewGroups(rgbJpegBytes);
    if (viewGroups == null) {
      return const OfflineRecognitionOutcome(
        OfflineRecognitionStatus.error,
        'Görüntü çözülemedi. Lütfen yeniden çekin.',
      );
    }

    final scaleProbabilities = <List<double>>[];
    var usedDeepCrops = false;
    try {
      List<double> evaluateScale(List<img.Image> views) {
        final scale = List<double>.filled(_labels.length, 0);
        for (final image in views) {
          final output = [List<double>.filled(_labels.length, 0)];
          interpreter.run(_toTensor(image), output);
          for (var index = 0; index < scale.length; index++) {
            scale[index] += output.first[index] / views.length;
          }
        }
        return scale;
      }

      // Tam ve %90 merkez görünümü aynı sınıfta yüksek güvenle uzlaşırsa dört
      // çıkarımlı hızlı yol korunur. Uyuşmazlıkta veya düşük güvende
      // %75/%60/%50 görünüm eklenir.
      scaleProbabilities
        ..add(evaluateScale(viewGroups[0]))
        ..add(evaluateScale(viewGroups[1]));
      final initialViewsDisagree =
          _argMax(scaleProbabilities[0]) != _argMax(scaleProbabilities[1]);
      final initialConfidence = _maxAveragedConfidence(
        scaleProbabilities[0],
        scaleProbabilities[1],
      );
      if (initialViewsDisagree || initialConfidence < 0.70) {
        usedDeepCrops = true;
        for (final group in viewGroups.skip(2)) {
          scaleProbabilities.add(evaluateScale(group));
        }
      }
    } on Object catch (error, stackTrace) {
      debugPrint('NutriSense inference failed: $error\n$stackTrace');
      return const OfflineRecognitionOutcome(
        OfflineRecognitionStatus.error,
        'Cihaz üstü tanıma çalıştırılamadı. Manuel giriş kullanın.',
      );
    }

    final probabilities = List<double>.filled(_labels.length, 0);
    for (final scale in scaleProbabilities) {
      for (var index = 0; index < probabilities.length; index++) {
        probabilities[index] += scale[index] / scaleProbabilities.length;
      }
    }

    final rankedIndexes = List<int>.generate(probabilities.length, (i) => i)
      ..sort((a, b) => probabilities[b].compareTo(probabilities[a]));
    final rawBestIndex = rankedIndexes.first;
    final bestIndex = rawBestIndex;
    final confidence = probabilities[bestIndex];
    final rawBestConfidence = probabilities[rawBestIndex];
    final label = _labels[bestIndex];
    final turkish = _turkishNames[label] ?? label;
    final candidates = rankedIndexes.take(3).map((index) {
      final candidateLabel = _labels[index];
      return FoodCandidate(
        foodName: candidateLabel,
        foodNameTr: _turkishNames[candidateLabel] ?? candidateLabel,
        confidence: probabilities[index],
      );
    }).toList(growable: false);
    final topScores = rankedIndexes.take(3).map((index) {
      return '${_labels[index]}=${probabilities[index].toStringAsFixed(4)}';
    }).join(', ');
    debugPrint(
      'NutriSense inference: top3=[$topScores], '
      'selected=$label(${confidence.toStringAsFixed(4)}), '
      'deepCrops=$usedDeepCrops, '
      'acceptThreshold=${_threshold.toStringAsFixed(4)}',
    );

    if (rawBestConfidence < _suggestionThreshold) {
      return const OfflineRecognitionOutcome(
        OfflineRecognitionStatus.rejected,
        'Yiyecek güvenilir biçimde tanınamadı. Yeniden çekin veya manuel '
        'giriş kullanın.',
      );
    }

    if (confidence < _threshold) {
      return OfflineRecognitionOutcome(
        OfflineRecognitionStatus.suggestion,
        'Olası tahmin $turkish. Güven yüzde '
        '${(confidence * 100).round()}; kaydetmeden önce kontrol edin.',
        foodNameTr: turkish,
        confidence: confidence,
        candidates: candidates,
      );
    }

    return OfflineRecognitionOutcome(
      OfflineRecognitionStatus.success,
      '$turkish olarak tanındı.',
      foodNameTr: turkish,
      confidence: confidence,
      candidates: candidates,
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
