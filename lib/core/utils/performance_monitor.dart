// =============================================================================
// lib/core/utils/performance_monitor.dart
// NutriSense — Performans İzleyici
//
// Ölçümler:
//   - Kamera frame → API yanıt süresi  (hedef < 3sn)
//   - Bellek kullanımı izleme
//   - ResizeImage ile görüntü boyutu optimizasyonu
//   - VAD (Voice Activity Detection) pil optimizasyonu
//   - CameraController dispose doğrulama
// =============================================================================

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANS İZLEYİCİ
// ═══════════════════════════════════════════════════════════════════════════════

class PerformanceMonitor {
  PerformanceMonitor._();
  static final instance = PerformanceMonitor._();

  final Map<String, _TimedOperation> _activeTimers = {};
  final List<PerformanceRecord> _history = [];

  static const maxAnalysisTimeMs = 3000; // 3 saniye hedef
  static const maxImageSizeBytes = 1024 * 1024; // 1 MB
  static const maxMemoryWarningMb = 150; // 150 MB uyarı eşiği

  // ─────────────────────────────────────────────────────────────────────────
  // ZAMANLAMA
  // ─────────────────────────────────────────────────────────────────────────

  /// İşlem süre ölçümünü başlat
  void startTimer(String operationName) {
    _activeTimers[operationName] = _TimedOperation(
      name: operationName,
      startTime: DateTime.now(),
    );

    if (kDebugMode) {
      developer.Timeline.startSync(operationName);
    }
  }

  /// İşlem süre ölçümünü bitir ve kaydet
  PerformanceRecord? stopTimer(String operationName) {
    final timer = _activeTimers.remove(operationName);
    if (timer == null) return null;

    if (kDebugMode) {
      developer.Timeline.finishSync();
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(timer.startTime);
    final record = PerformanceRecord(
      operation: operationName,
      durationMs: duration.inMilliseconds,
      timestamp: endTime,
      withinTarget: duration.inMilliseconds <= maxAnalysisTimeMs,
    );

    _history.add(record);

    // Hedef aşıldıysa uyar
    if (!record.withinTarget && kDebugMode) {
      debugPrint(
        '⚠️ PERFORMANS UYARISI: $operationName '
        '${duration.inMilliseconds}ms sürdü (hedef: ${maxAnalysisTimeMs}ms)',
      );
    }

    return record;
  }

  /// Son N kaydı döner
  List<PerformanceRecord> getHistory([int count = 20]) {
    return _history.reversed.take(count).toList();
  }

  /// Ortalama süre (belirli işlem tipi)
  double averageDuration(String operationName) {
    final records = _history.where((r) => r.operation == operationName);
    if (records.isEmpty) return 0;
    return records.map((r) => r.durationMs).reduce((a, b) => a + b) /
        records.length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BESIN TARAMA PIPELINE ÖLÇÜMÜ
  // ─────────────────────────────────────────────────────────────────────────

  /// Kamera frame → API yanıt → TTS akışının tamamını ölç
  void startScanPipeline() => startTimer('scan_pipeline');
  PerformanceRecord? stopScanPipeline() => stopTimer('scan_pipeline');

  /// Görüntü ön işleme süresi
  void startImagePreprocessing() => startTimer('image_preprocessing');
  PerformanceRecord? stopImagePreprocessing() =>
      stopTimer('image_preprocessing');

  /// API çağrı süresi
  void startApiCall() => startTimer('api_call');
  PerformanceRecord? stopApiCall() => stopTimer('api_call');

  /// TTS konuşma süresi
  void startTtsSpeech() => startTimer('tts_speech');
  PerformanceRecord? stopTtsSpeech() => stopTimer('tts_speech');

  // ─────────────────────────────────────────────────────────────────────────
  // BELLEK & GÖRÜNTÜ
  // ─────────────────────────────────────────────────────────────────────────

  /// Büyük görüntülerin yeniden boyutlandırılması gerektiğini kontrol et
  bool shouldResizeImage(int imageSizeBytes) {
    return imageSizeBytes > maxImageSizeBytes;
  }

  /// Önerilen boyut (en/boy)
  Map<String, int> recommendedImageSize(int width, int height) {
    const maxDimension = 800;
    if (width <= maxDimension && height <= maxDimension) {
      return {'width': width, 'height': height};
    }

    final ratio = width / height;
    if (width > height) {
      return {'width': maxDimension, 'height': (maxDimension / ratio).round()};
    } else {
      return {'width': (maxDimension * ratio).round(), 'height': maxDimension};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PİL OPTİMİZASYONU — VAD
  // ─────────────────────────────────────────────────────────────────────────

  /// VAD yapılandırması: ses seviyesi eşiği
  static const vadSilenceThreshold = 0.02; // RMS ses eşiği
  static const vadSilenceTimeoutMs = 1500; // Sessizlik zaman aşımı

  /// Ses seviyesi eşiğinin üstünde mi? (VAD)
  bool isVoiceActive(double rmsLevel) => rmsLevel > vadSilenceThreshold;

  // ─────────────────────────────────────────────────────────────────────────
  // DEVTOOLS ENTEGRASYONU
  // ─────────────────────────────────────────────────────────────────────────

  /// Timeline olayı logla (Dart DevTools)
  void logTimelineEvent(String name, {Map<String, dynamic>? args}) {
    if (kDebugMode) {
      developer.Timeline.instantSync(name, arguments: args);
    }
  }

  /// Performans raporunu konsola yazdır
  void printReport() {
    if (!kDebugMode) return;

    debugPrint('\n═══ NutriSense Performans Raporu ═══');
    debugPrint('Toplam kayıt: ${_history.length}');

    final groups = <String, List<PerformanceRecord>>{};
    for (final r in _history) {
      groups.putIfAbsent(r.operation, () => []).add(r);
    }

    for (final entry in groups.entries) {
      final records = entry.value;
      final avg = records.map((r) => r.durationMs).reduce((a, b) => a + b) /
          records.length;
      final max =
          records.map((r) => r.durationMs).reduce((a, b) => a > b ? a : b);
      final success =
          records.where((r) => r.withinTarget).length / records.length * 100;

      debugPrint('  ${entry.key}:');
      debugPrint('    Ortalama: ${avg.toStringAsFixed(0)}ms');
      debugPrint('    Maksimum: ${max}ms');
      debugPrint('    Hedef içi: %${success.toStringAsFixed(0)}');
    }
    debugPrint('═══════════════════════════════════\n');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VERİ MODELLERİ
// ═══════════════════════════════════════════════════════════════════════════════

class _TimedOperation {
  final String name;
  final DateTime startTime;
  const _TimedOperation({required this.name, required this.startTime});
}

class PerformanceRecord {
  final String operation;
  final int durationMs;
  final DateTime timestamp;
  final bool withinTarget;

  const PerformanceRecord({
    required this.operation,
    required this.durationMs,
    required this.timestamp,
    required this.withinTarget,
  });

  @override
  String toString() =>
      '$operation: ${durationMs}ms ${withinTarget ? "✅" : "⚠️"}';
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISPOSE DOĞRULAMASI (CameraController)
// ═══════════════════════════════════════════════════════════════════════════════

/// CameraController dispose doğrulama mixin'i
mixin DisposeVerifier {
  final _disposedResources = <String>{};
  bool _isDisposed = false;

  /// Kaynak dispose edildi olarak işaretle
  void markDisposed(String resourceName) {
    _disposedResources.add(resourceName);
    if (kDebugMode) {
      debugPrint('♻️ Dispose edildi: $resourceName');
    }
  }

  /// Tüm beklenen kaynaklar dispose edildi mi?
  bool verifyAllDisposed(List<String> expectedResources) {
    final missing = expectedResources
        .where((r) => !_disposedResources.contains(r))
        .toList();

    if (missing.isNotEmpty && kDebugMode) {
      debugPrint('⚠️ DİSPOSE UYARISI: Şu kaynaklar dispose edilmedi: $missing');
    }

    return missing.isEmpty;
  }

  /// Genel dispose durumu
  void setDisposed() => _isDisposed = true;
  bool get isProperlyDisposed => _isDisposed;
}
