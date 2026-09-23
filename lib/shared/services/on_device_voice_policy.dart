// =============================================================================
// lib/shared/services/on_device_voice_policy.dart
// NutriSense — Ses ve metin okumanın cihazda kalması için kurallar
//
// Konuşma tanıma ve metin okuma işletim sisteminin servisleriyle yapılır. Bu
// servisler bazı durumlarda sesi veya okunacak metni sağlayıcının sunucusuna
// gönderir. Aşağıdaki kurallar mümkün olduğunda işin cihazda kalmasını sağlar
// ve cihaz desteklemediğinde uygulamanın bozulmamasını garanti eder.
// =============================================================================

import 'package:flutter/foundation.dart';

/// Konuşma tanımada önce cihaz üstü (internetsiz) tanıma istenir mi.
///
/// Bulut tanımaya sessiz geçiş yapılmaz. Cihazda Türkçe paket yoksa kullanıcı
/// dokunmatik veya klavye ile devam eder.
bool preferOnDeviceSpeechByDefault() =>
    defaultTargetPlatform == TargetPlatform.android;

/// Desteklenen Android sürümlerinde cihaz üstü istek zorunludur.
bool preferOnDeviceSpeechForAndroidSdk(int sdkInt) => sdkInt >= 21;

Future<bool> resolveOnDeviceSpeechPreference() async =>
    preferOnDeviceSpeechByDefault();

/// Cihaz üstü tanıma başarısız olursa bulut tanımaya yeniden denenmez.
bool shouldRetryWithoutOnDevice(
  String errorMsg, {
  required bool preferOnDevice,
}) =>
    false;

/// Cihazda kurulu, internet gerektirmeyen bir Türkçe metin okuma sesi seçer.
///
/// Google metin okuma motoru sunucuda üretilen seslerin adına "network"
/// yazar; bu seslerle okunan besin ve sağlık metni cihazdan çıkar. Adında
/// "local" geçen ses önceliklidir. Uygun ses yoksa `null` döner ve cihazın
/// varsayılan sesi kullanılmaya devam eder.
Map<String, String>? selectOfflineTurkishVoice(List<dynamic> voices) {
  final candidates = <Map<String, String>>[];
  for (final raw in voices) {
    if (raw is! Map) continue;
    final name = raw['name']?.toString() ?? '';
    final locale = raw['locale']?.toString() ?? '';
    if (name.isEmpty || !locale.toLowerCase().startsWith('tr')) continue;
    if (name.toLowerCase().contains('network')) continue;
    candidates.add({'name': name, 'locale': locale});
  }
  if (candidates.isEmpty) return null;
  return candidates.firstWhere(
    (voice) => voice['name']!.toLowerCase().contains('local'),
    orElse: () => candidates.first,
  );
}
