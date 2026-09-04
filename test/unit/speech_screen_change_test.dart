import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';

import '../support/platform_channel_mocks.dart';

/// Ekran değişiminde eski konuşma susmalı, yeni ekranınki başlamalıdır.
///
/// Gerçek akış: gezinme gözlemcisi `stop()` çağırır ve beklemez; yeni ekran
/// hemen ardından kendi duyurusunu ister. Bu istek, durdurma tamamlanmadan
/// geldiği için kuyrukta unutulabiliyordu. Sonuç, kullanıcının eski ekranın
/// cümlesini dinlemeye devam etmesi ve yeni ekranı hiç duymamasıydı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late Completer<void> speakGate;
  late Completer<void> stopGate;

  setUp(() {
    mockSecureStorage();
    calls = [];
    speakGate = Completer<void>();
    stopGate = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') {
          final text = '${call.arguments}';
          calls.add('speak:$text');
          // Motor eski cümlede takılı kalır; durdurma bunu çözmez. Gerçek
          // cihazda görülen durum budur: eski ses sürer, kuyruk ilerlemez.
          if (text.contains('eski') && !speakGate.isCompleted) {
            await speakGate.future;
          }
        }
        if (call.method == 'stop') {
          calls.add('stop');
          // Motorun durdurmayı geç tamamlaması taklit edilir.
          if (!stopGate.isCompleted) await stopGate.future;
        }
        return 1;
      },
    );
  });

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('durdurma sürerken istenen duyuru kaybolmaz', () async {
    final service = AccessibilityService();
    await service.initialize();

    // Eski ekranın konuşması sürüyor (motor henüz bitirmedi).
    unawaited(service.speak('eski ekran'));
    await settle();

    // Gezinme: gözlemci durdurur ve beklemez.
    unawaited(service.stop());
    await settle();

    // Yeni ekran kendi duyurusunu ister.
    unawaited(service.speak('yeni ekran'));
    await settle();

    // Motor durdurmayı şimdi tamamlar.
    stopGate.complete();
    await settle();

    expect(
      calls.any((c) => c.contains('yeni ekran')),
      isTrue,
      reason: 'Yeni ekranın duyurusu kuyrukta unutuldu: $calls',
    );
  });
}
