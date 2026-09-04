import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';

import '../support/platform_channel_mocks.dart';

/// Kullanıcı yeni bir eyleme geçtiğinde eski duyuru kesilmelidir.
///
/// Eski cümle sonuna kadar okunursa görme engelli kullanıcı, artık yapmadığı
/// bir işi anlatan bir cümle dinler; bu karışıklığa ve yanlış işleme yol açar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;

  setUp(() {
    mockSecureStorage();
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') calls.add('speak:${call.arguments}');
        if (call.method == 'stop') calls.add('stop');
        return 1;
      },
    );
  });

  test('yüksek öncelik çalan sesi keser', () async {
    final service = AccessibilityService();
    await service.initialize();

    await service.speak('birinci', priority: TtsPriority.high);
    await service.speak('ikinci', priority: TtsPriority.high);

    // Her yüksek öncelikli duyurudan önce durdurma gelmeli.
    expect(calls.where((c) => c == 'stop').length, greaterThanOrEqualTo(2));
    expect(calls.last, contains('ikinci'));
  });

  test('kritik öncelik de keser', () async {
    final service = AccessibilityService();
    await service.initialize();

    await service.speak('hata', priority: TtsPriority.critical);

    expect(calls, contains('stop'));
    expect(calls.last, contains('hata'));
  });

  test('normal öncelik kesmez, sırayla okunur', () async {
    final service = AccessibilityService();
    await service.initialize();

    await service.speak('birinci');
    await service.speak('ikinci');

    // Sıralı bilgi mesajları birbirini kesmemeli; ikisi de okunmalı.
    expect(calls.where((c) => c.startsWith('speak:')).length, 2);
    expect(calls.contains('stop'), isFalse);
  });
}
