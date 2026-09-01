import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Sallama hareketini ivmeölçer örneklerinden tanır.
///
/// Saf mantık olarak ayrıldı: sensör akışı olmadan test edilebilir.
///
/// Tek bir sarsıntı tetiklemez. Kullanıcının telefonu cebinde yürürken ya da
/// masaya bırakırken komut başlatmaması için, kısa bir pencere içinde birden
/// çok belirgin sarsıntı aranır.
class ShakeAnalyzer {
  ShakeAnalyzer({
    this.threshold = 22.0,
    this.requiredShakes = 2,
    this.window = const Duration(milliseconds: 900),
    this.cooldown = const Duration(seconds: 2),
  });

  /// Yerçekimi dahil toplam ivme eşiği (m/s²). Durgun telefon ~9.8 okur.
  final double threshold;

  /// Tetikleme için pencere içinde gereken sarsıntı sayısı.
  final int requiredShakes;

  /// Sarsıntıların sayılacağı süre.
  final Duration window;

  /// Tetikleme sonrası yeni tetiklemenin engellendiği süre.
  final Duration cooldown;

  final List<DateTime> _hits = [];
  DateTime? _lastTrigger;

  /// Aynı sarsıntının birden çok örnekte sayılmaması için asgari aralık.
  static const _minGapBetweenHits = Duration(milliseconds: 150);

  /// Yeni bir örnek ekler; sallama tamamlandıysa true döner.
  bool addSample(double x, double y, double z, DateTime at) {
    if (_lastTrigger != null && at.difference(_lastTrigger!) < cooldown) {
      return false;
    }

    final magnitude = sqrt(x * x + y * y + z * z);
    if (magnitude < threshold) return false;

    if (_hits.isNotEmpty && at.difference(_hits.last) < _minGapBetweenHits) {
      return false;
    }

    _hits.add(at);
    _hits.removeWhere((hit) => at.difference(hit) > window);

    if (_hits.length < requiredShakes) return false;

    _hits.clear();
    _lastTrigger = at;
    return true;
  }

  /// Durumu sıfırlar; ekran değişimi veya devre dışı bırakma sonrası kullanılır.
  void reset() {
    _hits.clear();
    _lastTrigger = null;
  }
}

/// İvmeölçer akışını dinleyip sallama olduğunda geri çağırır.
class ShakeDetector {
  ShakeDetector({ShakeAnalyzer? analyzer})
      : _analyzer = analyzer ?? ShakeAnalyzer();

  final ShakeAnalyzer _analyzer;
  StreamSubscription<AccelerometerEvent>? _subscription;

  bool get isRunning => _subscription != null;

  /// Dinlemeye başlar. [onShake] her tetiklemede çağrılır.
  void start(void Function() onShake) {
    if (_subscription != null) return;
    _analyzer.reset();
    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((event) {
      if (_analyzer.addSample(event.x, event.y, event.z, DateTime.now())) {
        onShake();
      }
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _analyzer.reset();
  }
}
