import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/on_device_voice_policy.dart';

void main() {
  group('cihaz üstü konuşma tanıma', () {
    test('dil paketi yoksa bir kez standart tanımaya dönülür', () {
      expect(
        shouldRetryWithoutOnDevice('error_language_unavailable',
            preferOnDevice: true),
        isTrue,
      );
      expect(
        shouldRetryWithoutOnDevice('error_language_not_supported',
            preferOnDevice: true),
        isTrue,
      );
    });

    test('standart tanımaya dönüldükten sonra tekrar denenmez', () {
      expect(
        shouldRetryWithoutOnDevice('error_language_unavailable',
            preferOnDevice: false),
        isFalse,
      );
    });

    test('dil paketi dışındaki hatalar geri dönüş sebebi değildir', () {
      expect(
        shouldRetryWithoutOnDevice('error_no_match', preferOnDevice: true),
        isFalse,
      );
    });
  });

  group('yerel metin okuma sesi', () {
    test('ağ sesi yerine cihazdaki Türkçe ses seçilir', () {
      final voice = selectOfflineTurkishVoice([
        {'name': 'tr-tr-x-cfs-network', 'locale': 'tr-TR'},
        {'name': 'en-us-x-sfg-local', 'locale': 'en-US'},
        {'name': 'tr-tr-x-mfm-local', 'locale': 'tr-TR'},
      ]);
      expect(voice, {'name': 'tr-tr-x-mfm-local', 'locale': 'tr-TR'});
    });

    test('yalnız ağ sesi varsa ses değiştirilmez', () {
      expect(
        selectOfflineTurkishVoice([
          {'name': 'tr-tr-x-cfs-network', 'locale': 'tr-TR'},
        ]),
        isNull,
      );
    });

    test('beklenmeyen ses listesi uygulamayı kilitlemez', () {
      expect(selectOfflineTurkishVoice([1, 'ses', null]), isNull);
    });
  });
}
