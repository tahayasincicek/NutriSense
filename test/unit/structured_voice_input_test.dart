import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/structured_voice_input.dart';

void main() {
  test('Türkçe bir ile beş arasındaki sesli sayıları çözer', () {
    expect(spokenOneToFive('beş yıldız'), 5);
    expect(spokenOneToFive('Seçeneğim 3'), 3);
    expect(spokenOneToFive('altı'), isNull);
  });

  test('seçeneği adı veya sırasıyla bulur', () {
    const options = ['Evet', 'Hayır', 'Belki'];
    expect(matchSpokenOption('hayır diyorum', options), 'Hayır');
    expect(matchSpokenOption('üçüncü seçenek', options), 'Belki');
  });

  test('söylenen Türkçe e-posta adresini yazılabilir adrese çevirir', () {
    expect(
      spokenEmailToAddress('uzman nokta beslenme et example nokta com'),
      'uzman.beslenme@example.com',
    );
  });
}
