import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/turkish_number_parser.dart';

void main() {
  // Tam görme kaybı olan kullanıcı sayıları konuşarak giriyor; ayrıştırıcı
  // yanlış okursa yanlış veri kaydedilir, bu yüzden kapsam geniş tutuldu.
  group('parseTurkishNumber', () {
    test('rakamları okur', () {
      expect(parseTurkishNumber('7'), 7);
      expect(parseTurkishNumber('7.5'), 7.5);
      expect(parseTurkishNumber('7,5'), 7.5);
      expect(parseTurkishNumber('75 kilo'), 75);
    });

    test('sözcükle söylenen sayıları okur', () {
      expect(parseTurkishNumber('yedi'), 7);
      expect(parseTurkishNumber('yetmiş dört'), 74);
      expect(parseTurkishNumber('yüz yirmi'), 120);
      expect(parseTurkishNumber('seksen beş'), 85);
    });

    test('buçuk ve çeyrek ifadelerini anlar', () {
      expect(parseTurkishNumber('yedi buçuk'), 7.5);
      expect(parseTurkishNumber('yarım'), 0.5);
      expect(parseTurkishNumber('sekiz çeyrek'), 8.25);
    });

    test('nokta ve virgül ile ondalık okur', () {
      expect(parseTurkishNumber('yetmiş dört nokta iki'), 74.2);
      expect(parseTurkishNumber('yetmiş dört virgül iki'), 74.2);
    });

    test('komut cümlesinin içinden sayıyı çıkarır', () {
      expect(parseTurkishNumber('kilomu kaydet yetmiş dört buçuk'), 74.5);
      expect(parseTurkishNumber('uyku kaydet sekiz saat'), 8);
      expect(parseTurkishNumber('dokuz saat uyudum'), 9);
    });

    test('sayı yoksa null döner', () {
      expect(parseTurkishNumber(''), isNull);
      expect(parseTurkishNumber('merhaba'), isNull);
      expect(parseTurkishNumber('kilomu kaydet'), isNull);
    });
  });

  group('speakableNumber', () {
    test('tam sayıları ondalıksız yazar', () {
      expect(speakableNumber(8), '8');
      expect(speakableNumber(74), '74');
    });

    test('ondalıkları virgülle yazar', () {
      // Türkçe TTS "7,5" ifadesini "yedi virgül beş" diye doğru okur.
      expect(speakableNumber(7.5), '7,5');
      expect(speakableNumber(74.2), '74,2');
    });
  });
}
