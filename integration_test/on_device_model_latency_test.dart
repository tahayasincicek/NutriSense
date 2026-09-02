import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:nutrisense/features/food_scan/services/offline_recognizer.dart';

/// Cihaz üstü modelin gerçek donanımdaki çıkarım süresini ölçer.
///
/// Model kartındaki `target_device_latency_ms` alanı bu ölçüm olmadan
/// `not_run` kalır. Ölçümün hangi donanımda yapıldığı raporlanmalıdır;
/// emülatör ölçümü fiziksel telefon ölçümü yerine geçmez.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cihaz üstü model çıkarım süresi ölçülür', (tester) async {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/models/model_manifest.json'),
    ) as Map<String, dynamic>;

    final recognizer = TfliteFoodRecognizer();
    addTearDown(recognizer.dispose);

    // Sentetik ama gerçekçi boyutta bir görsel; ölçülen şey modelin
    // çıkarım süresidir, tanıma doğruluğu değil.
    final canvas = img.Image(width: 640, height: 480);
    img.fill(canvas, color: img.ColorRgb8(180, 140, 90));
    final jpeg = Uint8List.fromList(img.encodeJpg(canvas, quality: 90));

    // İlk çağrı modeli yükler; ısınma ölçüme katılmaz.
    await recognizer.recognize(jpeg);
    expect(recognizer.isAvailable, isTrue,
        reason: 'Model paketten yüklenemedi; ölçüm anlamsız olur.');

    const runs = 20;
    final samples = <int>[];
    for (var index = 0; index < runs; index++) {
      final watch = Stopwatch()..start();
      await recognizer.recognize(jpeg);
      watch.stop();
      samples.add(watch.elapsedMicroseconds);
    }
    samples.sort();

    double percentile(double fraction) {
      final position = ((samples.length - 1) * fraction).round();
      return samples[position] / 1000.0;
    }

    // ignore: avoid_print
    print(
      'ON_DEVICE_LATENCY '
      'model=${manifest["model_file"]} '
      'format=${manifest["model_format"]} '
      'runs=$runs '
      'p50_ms=${percentile(0.50).toStringAsFixed(2)} '
      'p95_ms=${percentile(0.95).toStringAsFixed(2)} '
      'min_ms=${(samples.first / 1000).toStringAsFixed(2)} '
      'max_ms=${(samples.last / 1000).toStringAsFixed(2)}',
    );

    expect(samples, hasLength(runs));
  });
}
