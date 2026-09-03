import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';

import '../support/platform_channel_mocks.dart';

/// TalkBack açıkken mesajın kaybolmadığını doğrular.
///
/// Uygulama kendi sesiyle konuşmaz (üst üste binme olur), fakat susmak da
/// doğru değildir: kullanıcı tarama sonucunu hiç duymayabilir. Mesaj ekran
/// okuyucunun kendi duyuru kanalına verilir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> announced;

  setUp(() {
    mockSecureStorage();
    announced = [];
    // TTS eklentisi test ortamında yok; taklit edilmezse servis başlatma
    // hatası kaydeder ve speak() daha ilk kontrolde geri döner.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async {
        if (call.method == 'isLanguageAvailable') return true;
        return 1;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (dynamic message) async {
        if (message is Map && message['type'] == 'announce') {
          final data = message['data'] as Map;
          announced.add(data['message'] as String);
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility, null);
  });

  test('ekran okuyucu açıkken mesaj duyuru kanalına gider', () async {
    final service = AccessibilityService();
    await service.initialize();
    service.setScreenReaderActive(true);

    await service.speak('Baklava tanındı. Güven yüzde doksan.');

    expect(announced, contains('Baklava tanındı. Güven yüzde doksan.'));
  });

  test('ekran okuyucu kapalıyken duyuru kanalı kullanılmaz', () async {
    final service = AccessibilityService();
    await service.initialize();
    service.setScreenReaderActive(false);

    await service.speak('Baklava tanındı.');

    // Kapalıyken uygulamanın kendi sesi çalışır; duyuru kanalına
    // kopyalanması çift okumaya yol açardı.
    expect(announced, isEmpty);
  });

  test('boş metin duyurulmaz', () async {
    final service = AccessibilityService();
    await service.initialize();

    await service.announceToScreenReader('');

    expect(announced, isEmpty);
  });
}
