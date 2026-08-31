import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';

/// TalkBack açıkken uygulamanın kendi TTS'i ile ekran okuyucunun sesi üst üste
/// binmemeli; ama kritik duyurular (hatalar) her durumda duyulmalı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> spoken;

  setUp(() {
    spoken = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async {
        if (call.method == 'speak') spoken.add(call.arguments as String);
        // Türkçe ses mevcut sayılmalı; aksi hâlde servis TTS'i arızalı
        // işaretleyip tüm duyuruları susturur.
        if (call.method == 'isLanguageAvailable') return true;
        return 1;
      },
    );
    // AccessibilityService başlarken kayıtlı tercihleri okur.
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : null,
    );
  });

  Future<AccessibilityService> ready() async {
    final service = AccessibilityService();
    await service.initialize();
    return service;
  }

  test('ekran okuyucu kapalıyken normal duyurular okunur', () async {
    final service = await ready();
    service.setScreenReaderActive(false);
    await service.speak('merhaba');
    expect(spoken, contains('merhaba'));
  });

  test('ekran okuyucu açıkken normal duyurular susar', () async {
    final service = await ready();
    service.setScreenReaderActive(true);
    spoken.clear();
    await service.speak('bu okunmamalı');
    expect(spoken, isEmpty, reason: 'TalkBack ile çift konuşma oluşuyor');
  });

  test('ekran okuyucu açıkken hatalar yine de duyulur', () async {
    final service = await ready();
    service.setScreenReaderActive(true);
    spoken.clear();
    await service.speakError('kayıt başarısız');
    expect(
      spoken.any((text) => text.contains('kayıt başarısız')),
      isTrue,
      reason: 'Kritik hata TalkBack açıkken susturuluyor; kullanıcı '
          'işlemin başarısız olduğunu öğrenemez',
    );
  });

  test('açıkça izin verilen duyurular ekran okuyucuya rağmen okunur', () async {
    final service = await ready();
    service.setScreenReaderActive(true);
    spoken.clear();
    await service.speak(
      'yardım metni',
      allowWhileScreenReaderActive: true,
    );
    expect(spoken, contains('yardım metni'));
  });
}
