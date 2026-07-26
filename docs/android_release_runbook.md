# Android release runbook

Durum: **release adayı yapılandırması hazır; signed AAB bloke**. Kuruma ait
application ID, upload key, production HTTPS URL, gizlilik politikası URL'si ve
mağaza yetkisi verilmedi. Bunlar uydurulmamış ve repoya secret eklenmemiştir.

## Merkezi kararlar

| Alan | Kaynak | Mevcut karar |
|---|---|---|
| Uygulama adı | flavor manifest placeholder | Dev/Staging suffix; prod `NutriSense` |
| Version | `pubspec.yaml` | `1.0.0+1`; her mağaza sürümünde artır |
| Application ID | `android/gradle.properties` | `com.example.nutrisense` placeholder; release blocker |
| Namespace | `android/app/build.gradle.kts` | Kaynak kod namespace'i `com.example.nutrisense`; mağaza ID'sinden bağımsız |
| min/target/compile SDK | Flutter SDK | doğrulanan debug APK: min 24, target/compile 36 |
| Ortam URL'si | `AppConfig` + `--dart-define` | dev emulator HTTP; staging/prod yalnız HTTPS |

## Flavor komutları

```powershell
# Yerel backend / Android emulator
flutter run --flavor dev `
  --dart-define=APP_ENV=dev

# Staging: URL public config'dir, secret değildir
flutter run --flavor staging `
  --dart-define=APP_ENV=staging `
  --dart-define=API_BASE_URL=https://STAGING_HOST/api/v1

# Production signed AAB
flutter build appbundle --release --flavor prod `
  --dart-define=APP_ENV=prod `
  --dart-define=API_BASE_URL=https://PRODUCTION_HOST/api/v1
```

`devDebug` network security config yalnız `10.0.2.2`, `127.0.0.1` ve
`localhost` için cleartext tanır. Main/release config cleartext'i reddeder ve
yalnız sistem CA deposunu kullanır. Custom certificate bypass/pinning yoktur.
API/Twilio/SMTP/Nutritionix/Google anahtarları hiçbir flavor veya
`dart-define` içine konmaz.

## Application ID ve imza kapısı

1. Üniversite/ürün sahibi benzersiz reverse-domain ID'yi yazılı kararla seçer.
2. `NUTRISENSE_APPLICATION_ID` yerel/CI Gradle property olarak verilir.
3. Yetkili kişi upload keystore'u güvenli kurum cihazında üretir. Codex bu
   işlemde gerçek key üretmez.
4. `android/key.properties` aşağıdaki adları içerir; gerçek değerler parola
   yöneticisi/CI secret store'da kalır:

```properties
storeFile=upload-keystore.jks
storePassword=<secret>
keyAlias=<alias>
keyPassword=<secret>
```

`android/key.properties`, `*.jks` ve `*.keystore` Git tarafından dışlanır.
Release task; placeholder application ID veya `key.properties` yoksa hata
verir. Release build debug key'e düşmez.

CI'da keystore base64 değerini loglamadan geçici dosyaya açın, job bitiminde
runner ile birlikte imha edin. Play App Signing kullanılıyorsa upload key ile
app signing key ayrımını ve kurtarma yetkililerini kurum kaydında tutun.

## İzin ve Android davranışı

Doğrudan ürün manifesti `INTERNET`, `CAMERA`, `RECORD_AUDIO` ister.
`VIBRATE`, kullanılan haptic eklentisinden; Android 28 ve altındaki
`WRITE_EXTERNAL_STORAGE`, CameraX eklentisinden `maxSdkVersion=28` ile birleşir.
Bildirim özelliği/runtime akışı olmadığı için `POST_NOTIFICATIONS` yoktur.

Kamera ekranı geçici rette tekrar deneme/manuel giriş, kalıcı rette Ayarlar
eylemi sunar. Mikrofon reddinde dokunmatik/klavye alternatifi korunur. Bu
durumların fiziksel cihaz kanıtı cihaz raporunda tamamlanmalıdır.

## Release doğrulama

```powershell
python scripts/qa/android_release_checks.py
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev

# Yetkili app ID + key sağlandıktan sonra:
flutter build appbundle --release --flavor prod `
  --dart-define=APP_ENV=prod `
  --dart-define=API_BASE_URL=https://PRODUCTION_HOST/api/v1
```

AAB için ayrıca:

- `bundletool validate --bundle <aab>`
- Play internal track kurulum testi ve signer fingerprint kontrolü
- R8 sonrası auth, kamera, secure storage, TTS/STT ve paylaşım smoke
- APK/AAB içinde `.env`, provider key, test token ve debug endpoint taraması
- logcat'te token, parola, e-posta/telefon, base64 veya görüntü yolu olmaması

Mevcut `debugPrint` çağrıları `kDebugMode` korumasındadır. Release Crashlytics
adaptörü/credential'ı yoktur; crash verisi gönderiliyor diye beyan edilmez.

## Rollback

1. Dağıtımı durdur, Play staged rollout oranını sıfırla.
2. Güvenli son versionCode'a yeni ve daha yüksek versionCode ile dön; Play
   aynı versionCode'un tekrar yüklenmesine izin vermez.
3. API uyumluluğunu ve migration forward-fix'i doğrula; production DB'de
   plansız downgrade çalıştırma.
4. Secret/PII olayıysa `SECURITY.md` incident akışını başlat, anahtarı döndür,
   log/rapor alıcı kapsamını belirle.
5. Cihaz matrisi ve P0 smoke yeniden geçmeden rollout'u açma.

## Mağaza iddia ve Data Safety taslağı

Kanıtsız `TÜBİTAK destekli`, `WCAG uyumlu`, `800.000 besin`, `tam AI`,
`klinik doğruluk` ve `tıbbi öneri` ifadeleri yasaktır. Uygulama tahmini ve
klinik karar vermeyen besin bilgisi sunar.

Data Safety formu yayımdan önce gerçek production konfigürasyonuyla yeniden
onaylanmalıdır:

- Hesap: e-posta, ad, auth/audit verisi.
- Beslenme: kullanıcı onaylı besin, porsiyon, zaman ve makrolar.
- Kamera: analiz için işlenir; varsayılan kalıcı saklama yoktur; cloud aktarım
  seçimi gizlilik metninde açıklanır.
- Diyetisyen: yalnız atanmış/doğrulanmış alıcıya her gönderimde açık onam.
- Araştırma: ürün UUID'sinden ayrı pseudonym ve etik/protokol kapısı.
- Crash/analytics: production SDK yapılandırılmadığı için şu anda toplanıyor
  diye işaretlenmez.

Gizlilik politikası URL'si, veri sorumlusu, yurtdışı aktarım değerlendirmesi ve
silme/retention metni üniversite hukuk/KVKK birimi tarafından onaylanmadan
mağaza yayını yapılamaz.
