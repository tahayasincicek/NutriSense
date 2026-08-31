# Android cihaz kabul raporu

Rapor tarihi: 2026-07-27

Durum: **REJECT / STORE'A HAZIR DEĞİL**

Bu dosya yerel build veya emulator sonucunu fiziksel cihaz sonucu gibi
göstermez. Production model/sağlayıcıları, kurum application ID'si, upload key
ve iki fiziksel cihaz henüz sağlanmadığı için release kabulü verilmemiştir.

## Otomatik ve yerel kanıt

Aşağıdaki sonuçlar 2026-07-27 tarihinde yerel Windows 11 ortamında üretildi.
Önceden yazılmış başarı sayıları kullanılmadı.

| Kontrol | Sonuç | Kanıt |
|---|---|---|
| Static release boundaries | GEÇTİ | İzin, cleartext, SDK, flavor, backup, signing, Git ignore ve TLS bypass kontrolleri |
| Redacted secret scan | GEÇTİ | Takip edilen ağaç ve Git geçmişi; eşleşen değer yazdırılmaz |
| Android lint devDebug | GEÇTİ | JDK 21, 0 error; generated local.properties için dar istisna |
| Flutter analyze | GEÇTİ | 0 error, 0 warning; 68 mevcut deprecation/style info |
| Flutter test | GEÇTİ | 122/122 test |
| Staging/prod config testleri | GEÇTİ | HTTPS zorunlu; tanılama logu kapalı |
| Dev debug APK | GEÇTİ | `app-dev-debug.apk`; package `com.example.nutrisense.dev` |
| Staging debug APK | GEÇTİ | `app-staging-debug.apk`; birleşmiş manifestte cleartext `false` |
| SDK/izin merge | GEÇTİ | min 24, target/compile 36; INTERNET/CAMERA/RECORD_AUDIO, notification yok |
| Signed prod AAB | BEKLENEN BLOCKER GEÇTİ | Placeholder kurum ID'si release'i fail-closed durdurdu |
| Android emulator P0 E2E | DOĞRULANMADI | Release kanıtı sayılmaz |

Yerel APK checksum'ları:

- dev SHA-256:
  `A181E79C625A9E8E8D059A5B3C7580F0EEFBA19A1FD4D853F44F51EA892CC4FF`
- staging SHA-256:
  `2E44F5CAB4E2360AEED3067D76F75BE821F2069D09CEAE9A4D25E4EF392E181C`

Bu APK'lar debug artefaktıdır; mağazaya yüklenemez ve fiziksel cihaz kabulü
yerine geçmez.

## Zorunlu fiziksel cihaz matrisi

Her hücreye cihaz modeli/build, tarih-saat, gözlemci ve kişisel veri içermeyen
kanıt referansı yazılmalıdır.

| Senaryo | Düşük sınıf API 24–28 | Orta sınıf API 33–36 |
|---|---|---|
| Temiz kurulum, login/register | NOT RUN | NOT RUN |
| Kamera geçici ret/tekrar | NOT RUN | NOT RUN |
| Kamera kalıcı ret/Ayarlar dönüşü | NOT RUN | NOT RUN |
| Mikrofon ret/dokunmatik alternatif | NOT RUN | NOT RUN |
| Yüksek/orta/düşük güven tarama | NOT RUN | NOT RUN |
| Porsiyon sesli/dokunmatik düzeltme | NOT RUN | NOT RUN |
| Onay ve geçmişte görünme | NOT RUN | NOT RUN |
| Rapor önizleme/açık onam/partial failure | NOT RUN | NOT RUN |
| TalkBack odak ve çift konuşma | NOT RUN | NOT RUN |
| %200 font, koyu/yüksek kontrast | NOT RUN | NOT RUN |
| Uçak modu/yavaş ağ/retry | NOT RUN | NOT RUN |
| Background, kill, kamera dönüşü | NOT RUN | NOT RUN |
| Türkçe TTS/STT, kulaklık | NOT RUN | NOT RUN |
| Logout/cache ve hesap silme | NOT RUN | NOT RUN |

## Ölçüm protokolü

- Cold/warm tarama latency: p50/p95; recognition ve nutrition süreleri ayrı.
- 20 ardışık fixture/sandbox taramada crash ve ANR sayısı; kanıtsız
  “crash-free” yüzdesi yok.
- Android Studio Profiler ile başlangıç, scan ve history sonrası bellek; tekrar
  taramada kalıcı büyüme kontrolü.
- Logcat PII taraması: token, parola, e-posta, telefon, base64, görüntü yolu.
- Kamera geçici dosyasının ekran kapanışı ve process lifecycle sonrası durumu.
- Tüm kayıtlar sentetik test hesabıyla; gerçek sağlık/katılımcı verisi yok.

## Release kabul kapıları

1. İki fiziksel cihaz sütunu kanıtla doldurulur.
2. Doğrulanmış staging API ve yalnız sandbox sağlayıcıları kullanılır.
3. Kurum application ID'si, upload key ve internal-track signed AAB sağlanır.
4. Gizlilik politikası/Data Safety üniversite hukuk/KVKK incelemesinden geçer.
5. Gerçek offline model yayınlanacaksa model kartı, checksum, parity ve cihaz
   latency kanıtı vardır; yoksa offline AI iddiası release metninde bulunmaz.
