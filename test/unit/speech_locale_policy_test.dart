import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/speech_locale_policy.dart';

void main() {
  group('Türkçe konuşma locale politikası', () {
    test('Apple tr_TR değerini tercih eder', () {
      expect(
        selectTurkishSpeechLocale(['en_US', 'tr_TR', 'tr-CY']),
        'tr_TR',
      );
    });

    test('tireli locale kimliğini olduğu gibi korur', () {
      expect(
        selectTurkishSpeechLocale(['en-US', 'tr-TR']),
        'tr-TR',
      );
    });

    test('yalnız farklı Türkçe varyant varsa onu seçer', () {
      expect(
        selectTurkishSpeechLocale(['en_US', 'tr_CY']),
        'tr_CY',
      );
    });

    test('Türkçe yoksa başka dile sessizce düşmez', () {
      expect(selectTurkishSpeechLocale(['en_US', 'de_DE']), isNull);
    });
  });
}
