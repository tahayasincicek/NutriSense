import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageQualityConfig {
  final double minimumBrightness;
  final double maximumBrightness;
  final double minimumBlurScore;
  final int minimumShortEdge;

  const ImageQualityConfig({
    this.minimumBrightness = 40,
    this.maximumBrightness = 220,
    this.minimumBlurScore = 100,
    this.minimumShortEdge = 224,
  });

  factory ImageQualityConfig.fromEnvironment() => ImageQualityConfig(
        minimumBrightness: double.tryParse(const String.fromEnvironment(
              'QUALITY_MIN_BRIGHTNESS',
              defaultValue: '40',
            )) ??
            40,
        maximumBrightness: double.tryParse(const String.fromEnvironment(
              'QUALITY_MAX_BRIGHTNESS',
              defaultValue: '220',
            )) ??
            220,
        minimumBlurScore: double.tryParse(const String.fromEnvironment(
              'QUALITY_MIN_BLUR_SCORE',
              defaultValue: '100',
            )) ??
            100,
        minimumShortEdge: int.tryParse(const String.fromEnvironment(
              'QUALITY_MIN_SHORT_EDGE',
              defaultValue: '224',
            )) ??
            224,
      );
}

class PreprocessingResult {
  final Uint8List processedBytes;
  final double brightness;
  final double blurScore;
  final bool isAcceptableQuality;
  final String? qualityIssue;
  final int processingTimeMs;

  const PreprocessingResult({
    required this.processedBytes,
    required this.brightness,
    required this.blurScore,
    required this.isAcceptableQuality,
    this.qualityIssue,
    required this.processingTimeMs,
  });
}

class ImageQualityCheck {
  final double brightness;
  final double blurScore;
  final bool isTooDark;
  final bool isTooBright;
  final bool isBlurry;
  final bool isTooSmall;
  final bool isAcceptable;
  final String? message;

  const ImageQualityCheck({
    required this.brightness,
    required this.blurScore,
    required this.isTooDark,
    required this.isTooBright,
    required this.isBlurry,
    this.isTooSmall = false,
    required this.isAcceptable,
    this.message,
  });
}

class ImagePreprocessor {
  ImagePreprocessor._();

  static Future<PreprocessingResult> processImage({
    required Uint8List imageBytes,
    int targetWidth = 224,
    int targetHeight = 224,
    int jpegQuality = 85,
    ImageQualityConfig qualityConfig = const ImageQualityConfig(),
  }) =>
      compute(
        _processInIsolate,
        _ProcessingParams(
          imageBytes: imageBytes,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
          jpegQuality: jpegQuality,
          qualityConfig: qualityConfig,
        ),
      );

  static Future<ImageQualityCheck> checkQuality(
    Uint8List imageBytes, {
    ImageQualityConfig config = const ImageQualityConfig(),
  }) =>
      compute(
        _checkQualityInIsolate,
        _QualityParams(imageBytes: imageBytes, config: config),
      );
}

PreprocessingResult _processInIsolate(_ProcessingParams params) {
  final stopwatch = Stopwatch()..start();
  final decoded = img.decodeImage(params.imageBytes);
  if (decoded == null) {
    return PreprocessingResult(
      processedBytes: Uint8List(0),
      brightness: 0,
      blurScore: 0,
      isAcceptableQuality: false,
      qualityIssue: 'Görüntü çözümlenemedi.',
      processingTimeMs: stopwatch.elapsedMilliseconds,
    );
  }
  final oriented = img.bakeOrientation(decoded);
  final quality = _quality(oriented, params.qualityConfig);
  final cropSize =
      oriented.width < oriented.height ? oriented.width : oriented.height;
  final cropped = img.copyCrop(
    oriented,
    x: (oriented.width - cropSize) ~/ 2,
    y: (oriented.height - cropSize) ~/ 2,
    width: cropSize,
    height: cropSize,
  );
  final resized = img.copyResize(
    cropped,
    width: params.targetWidth,
    height: params.targetHeight,
    interpolation: img.Interpolation.linear,
  );
  final bytes = Uint8List.fromList(
    img.encodeJpg(resized, quality: params.jpegQuality),
  );
  stopwatch.stop();
  return PreprocessingResult(
    processedBytes: bytes,
    brightness: quality.brightness,
    blurScore: quality.blurScore,
    isAcceptableQuality: quality.isAcceptable,
    qualityIssue: quality.message,
    processingTimeMs: stopwatch.elapsedMilliseconds,
  );
}

ImageQualityCheck _checkQualityInIsolate(_QualityParams params) {
  final decoded = img.decodeImage(params.imageBytes);
  if (decoded == null) {
    return const ImageQualityCheck(
      brightness: 0,
      blurScore: 0,
      isTooDark: true,
      isTooBright: false,
      isBlurry: true,
      isAcceptable: false,
      message: 'Görüntü çözümlenemedi.',
    );
  }
  return _quality(img.bakeOrientation(decoded), params.config);
}

ImageQualityCheck _quality(img.Image image, ImageQualityConfig config) {
  final brightness = _brightness(image);
  final blur = _laplacianVariance(image);
  final tooDark = brightness < config.minimumBrightness;
  final tooBright = brightness > config.maximumBrightness;
  final blurry = blur < config.minimumBlurScore;
  final tooSmall = image.width < config.minimumShortEdge ||
      image.height < config.minimumShortEdge;
  String? message;
  if (tooDark) {
    message = 'Daha aydınlık bir yere geçin.';
  } else if (tooBright) {
    message = 'Işığı azaltın veya kamerayı gölgeye çevirin.';
  } else if (blurry) {
    message = 'Telefonu sabit tutun.';
  } else if (tooSmall) {
    message = 'Besine biraz yaklaşın.';
  }
  return ImageQualityCheck(
    brightness: brightness,
    blurScore: blur,
    isTooDark: tooDark,
    isTooBright: tooBright,
    isBlurry: blurry,
    isTooSmall: tooSmall,
    isAcceptable: !tooDark && !tooBright && !blurry && !tooSmall,
    message: message,
  );
}

double _brightness(img.Image image) {
  double total = 0;
  var count = 0;
  for (var y = 0; y < image.height; y += 4) {
    for (var x = 0; x < image.width; x += 4) {
      final pixel = image.getPixel(x, y);
      total += 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      count++;
    }
  }
  return count == 0 ? 0 : total / count;
}

double _laplacianVariance(img.Image image) {
  final small = img.grayscale(img.copyResize(image, width: 128));
  double sum = 0;
  double sumSquared = 0;
  var count = 0;
  for (var y = 1; y < small.height - 1; y++) {
    for (var x = 1; x < small.width - 1; x++) {
      final center = small.getPixel(x, y).r.toDouble() * 4;
      final laplacian = small.getPixel(x, y - 1).r +
          small.getPixel(x, y + 1).r +
          small.getPixel(x - 1, y).r +
          small.getPixel(x + 1, y).r -
          center;
      sum += laplacian;
      sumSquared += laplacian * laplacian;
      count++;
    }
  }
  if (count == 0) return 0;
  final mean = sum / count;
  return ((sumSquared / count) - mean * mean).abs();
}

class _ProcessingParams {
  final Uint8List imageBytes;
  final int targetWidth;
  final int targetHeight;
  final int jpegQuality;
  final ImageQualityConfig qualityConfig;

  const _ProcessingParams({
    required this.imageBytes,
    required this.targetWidth,
    required this.targetHeight,
    required this.jpegQuality,
    required this.qualityConfig,
  });
}

class _QualityParams {
  final Uint8List imageBytes;
  final ImageQualityConfig config;

  const _QualityParams({required this.imageBytes, required this.config});
}
