import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/food_scan/services/turkish_portion_parser.dart';

void main() {
  group('Türkçe porsiyon ayrıştırma', () {
    test('rakam, virgül ve birim eş anlamlarını ayrıştırır', () {
      expect(parseTurkishPortion('150 gram')?.value, 150);
      expect(parseTurkishPortion('1,5 tane')?.value, 1.5);
      expect(parseTurkishPortion('1,5 tane')?.unit, 'adet');
    });

    test('Türkçe sayı sözcüklerini ayrıştırır', () {
      expect(parseTurkishPortion('yüz elli gram')?.value, 150);
      expect(parseTurkishPortion('iki yüz gram')?.value, 200);
      expect(parseTurkishPortion('iki dilim')?.value, 2);
    });

    test('sıfır, negatif, aşırı, NaN ve birimsiz girişi reddeder', () {
      expect(parseTurkishPortion('0 gram'), isNull);
      expect(parseTurkishPortion('-10 gram'), isNull);
      expect(parseTurkishPortion('2001 gram'), isNull);
      expect(parseTurkishPortion('21 adet'), isNull);
      expect(parseTurkishPortion('NaN gram'), isNull);
      expect(parseTurkishPortion('150'), isNull);
    });
  });
}
