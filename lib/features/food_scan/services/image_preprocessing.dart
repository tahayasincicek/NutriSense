// =============================================================================
// lib/features/food_scan/services/image_preprocessing.dart
// NutriSense — Görüntü Ön İşleme (Isolate Tabanlı)
//
// Kameradan yakalanan frame'i backend'e göndermeden önce:
//   1. 224×224 piksel boyutuna yeniden örnekleme (MobileNetV3 input)
//   2. JPEG kalitesini %85'e sıkıştırma (bant genişliği tasarrufu)
//   3. Base64 kodlama (API gönderimi için)
//   4. Parlaklık ve bulanıklık analizi (erişilebilirlik geri bildirimi)
//
// Tüm ağır işlemler compute() ile ayrı isolate'te çalışır — UI donmaz.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Ön işleme sonucu — işlenmiş görüntü ve kalite metrikleri
class PreprocessingResult {
  /// Base64 kodlanmış JPEG verisi (API'ye gönderilecek)
  final String base64Image;

  /// İşlenmiş görüntünün byte verisi
  final Uint8List processedBytes;

  /// Ortalama parlaklık değeri (0.0 - 255.0)
  /// < 50 → çok karanlık, > 200 → çok parlak
  final double brightness;

  /// Bulanıklık skoru (Laplacian varyansı)
  /// < 100 → bulanık, > 100 → net
  final double blurScore;

  /// Görüntü yeterli kalitede mi
  final bool isAcceptableQuality;

  /// Düşük kalite nedeni (varsa)
  final String? qualityIssue;

  /// İşleme süresi (ms)
  final int processingTimeMs;

  const PreprocessingResult({
    required this.base64Image,
    required this.processedBytes,
    required this.brightness,
    required this.blurScore,
    required this.isAcceptableQuality,
    this.qualityIssue,
    required this.processingTimeMs,
  });
}

/// Görüntü ön işleme servisi
class ImagePreprocessor {
  ImagePreprocessor._();

  // ---------------------------------------------------------------------------
  // ANA İŞLEME METODLARİ
  // ---------------------------------------------------------------------------

  /// Ham kamera verisini işleyerek backend'e gönderime hazır hale getirir.
  /// compute() ile ayrı isolate'te çalışır — ana thread'i bloklamaz.
  ///
  /// [imageBytes] — Kameradan gelen ham JPEG/PNG byte verisi
  /// [targetWidth] — Hedef genişlik (varsayılan: 224)
  /// [targetHeight] — Hedef yükseklik (varsayılan: 224)
  /// [jpegQuality] — JPEG sıkıştırma kalitesi (varsayılan: 85)
  static Future<PreprocessingResult> processImage({
    required Uint8List imageBytes,
    int targetWidth = 224,
    int targetHeight = 224,
    int jpegQuality = 85,
  }) async {
    // Isolate'e gönderilecek parametreleri tek map'te topla
    final params = _ProcessingParams(
      imageBytes: imageBytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      jpegQuality: jpegQuality,
    );

    // compute() ile ayrı isolate'te çalıştır
    return await compute(_processInIsolate, params);
  }

  /// Sadece kalite kontrolü yap (resize/encode yapmadan).
  /// Otomatik yakalama döngüsünde her frame'de hızlıca çağrılabilir.
  static Future<ImageQualityCheck> checkQuality(Uint8List imageBytes) async {
    return await compute(_checkQualityInIsolate, imageBytes);
  }

  // ---------------------------------------------------------------------------
  // ISOLATE İŞLEVLERİ (Üst düzey fonksiyonlar — isolate gereksinimi)
  // ---------------------------------------------------------------------------

  /// Isolate'te çalışan ana işleme fonksiyonu
  static PreprocessingResult _processInIsolate(_ProcessingParams params) {
    final stopwatch = Stopwatch()..start();

    // 1. Görüntüyü decode et
    final originalImage = img.decodeImage(params.imageBytes);
    if (originalImage == null) {
      return PreprocessingResult(
        base64Image: '',
        processedBytes: Uint8List(0),
        brightness: 0,
        blurScore: 0,
        isAcceptableQuality: false,
        qualityIssue: 'Görüntü çözümlenemedi',
        processingTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    // 2. Parlaklık analizi (orijinal görüntü üzerinde — daha doğru)
    final brightness = _calculateBrightness(originalImage);

    // 3. Bulanıklık analizi (Laplacian varyansı)
    final blurScore = _calculateLaplacianVariance(originalImage);

    // 4. Kalite kontrolü
    String? qualityIssue;
    bool isAcceptable = true;

    if (brightness < 40) {
      qualityIssue = 'Ortam çok karanlık. Daha fazla ışık gerekiyor.';
      isAcceptable = false;
    } else if (brightness > 220) {
      qualityIssue = 'Ortam çok parlak. Kamerayı gölgeye çevirin.';
      isAcceptable = false;
    }

    if (blurScore < 100) {
      qualityIssue = qualityIssue != null
          ? '$qualityIssue Ayrıca kamerayı sabit tutun.'
          : 'Görüntü bulanık. Kamerayı sabit tutun.';
      isAcceptable = false;
    }

    // 5. 224×224'e yeniden boyutlandır (bilinear interpolasyon)
    final resized = img.copyResize(
      originalImage,
      width: params.targetWidth,
      height: params.targetHeight,
      interpolation: img.Interpolation.linear,
    );

    // 6. JPEG'e sıkıştır
    final jpegBytes = Uint8List.fromList(
      img.encodeJpg(resized, quality: params.jpegQuality),
    );

    // 7. Base64'e kodla
    final base64String = base64Encode(jpegBytes);

    stopwatch.stop();

    return PreprocessingResult(
      base64Image: base64String,
      processedBytes: jpegBytes,
      brightness: brightness,
      blurScore: blurScore,
      isAcceptableQuality: isAcceptable,
      qualityIssue: qualityIssue,
      processingTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Isolate'te çalışan kalite kontrol fonksiyonu
  static ImageQualityCheck _checkQualityInIsolate(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      return const ImageQualityCheck(
        brightness: 0,
        blurScore: 0,
        isTooDark: true,
        isTooBright: false,
        isBlurry: true,
        isAcceptable: false,
        message: 'Görüntü çözümlenemedi',
      );
    }

    final brightness = _calculateBrightness(image);
    final blurScore = _calculateLaplacianVariance(image);

    final isTooDark = brightness < 40;
    final isTooBright = brightness > 220;
    final isBlurry = blurScore < 100;

    String? message;
    if (isTooDark) {
      message = 'Daha fazla ışık gerekiyor';
    } else if (isTooBright) {
      message = 'Ortam çok parlak';
    } else if (isBlurry) {
      message = 'Kamerayı sabit tutun';
    }

    return ImageQualityCheck(
      brightness: brightness,
      blurScore: blurScore,
      isTooDark: isTooDark,
      isTooBright: isTooBright,
      isBlurry: isBlurry,
      isAcceptable: !isTooDark && !isTooBright && !isBlurry,
      message: message,
    );
  }

  // ---------------------------------------------------------------------------
  // GÖRÜNTÜ ANALİZ YARDIMCILARI
  // ---------------------------------------------------------------------------

  /// Ortalama parlaklık hesaplama (luminance ortalaması).
  /// Her pikselin Y = 0.299R + 0.587G + 0.114B formülüyle parlaklığı hesaplanır.
  ///
  /// Performans için her 4. piksel örneklenir (çözünürlükten bağımsız hız).
  static double _calculateBrightness(img.Image image) {
    double totalLuminance = 0;
    int sampleCount = 0;
    final step = 4; // Her 4. piksel — performans optimizasyonu

    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < image.width; x += step) {
        final pixel = image.getPixel(x, y);
        // ITU-R BT.601 luminance formülü
        final luminance = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        totalLuminance += luminance;
        sampleCount++;
      }
    }

    return sampleCount > 0 ? totalLuminance / sampleCount : 0;
  }

  /// Laplacian varyansı ile bulanıklık tespiti.
  ///
  /// Laplacian filtresi kenar yoğunluğunu ölçer.
  /// Düşük varyans = az kenar = bulanık görüntü
  /// Yüksek varyans = çok kenar = net görüntü
  ///
  /// Eşik değeri: 100 (altı bulanık kabul edilir)
  static double _calculateLaplacianVariance(img.Image image) {
    // Performans için küçültülmüş kopya üzerinde çalış
    final small = img.copyResize(image, width: 128);
    final grayscale = img.grayscale(small);

    double sum = 0;
    double sumSq = 0;
    int count = 0;

    // 3×3 Laplacian kernel: [0, 1, 0], [1, -4, 1], [0, 1, 0]
    for (int y = 1; y < grayscale.height - 1; y++) {
      for (int x = 1; x < grayscale.width - 1; x++) {
        final center = grayscale.getPixel(x, y).r.toDouble() * 4;
        final top = grayscale.getPixel(x, y - 1).r.toDouble();
        final bottom = grayscale.getPixel(x, y + 1).r.toDouble();
        final left = grayscale.getPixel(x - 1, y).r.toDouble();
        final right = grayscale.getPixel(x + 1, y).r.toDouble();

        final laplacian = (top + bottom + left + right) - center;
        sum += laplacian;
        sumSq += laplacian * laplacian;
        count++;
      }
    }

    if (count == 0) return 0;

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return variance.abs();
  }
}

// =============================================================================
// VERİ MODELLERİ
// =============================================================================

/// Isolate'e gönderilen parametre paketi
class _ProcessingParams {
  final Uint8List imageBytes;
  final int targetWidth;
  final int targetHeight;
  final int jpegQuality;

  const _ProcessingParams({
    required this.imageBytes,
    required this.targetWidth,
    required this.targetHeight,
    required this.jpegQuality,
  });
}

/// Kalite kontrol sonucu
class ImageQualityCheck {
  final double brightness;
  final double blurScore;
  final bool isTooDark;
  final bool isTooBright;
  final bool isBlurry;
  final bool isAcceptable;
  final String? message;

  const ImageQualityCheck({
    required this.brightness,
    required this.blurScore,
    required this.isTooDark,
    required this.isTooBright,
    required this.isBlurry,
    required this.isAcceptable,
    this.message,
  });
}
