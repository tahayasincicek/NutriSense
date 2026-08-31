# Android release runbook

Durum: **release yapılandırması hazırlanıyor; signed AAB kullanıcı girdileri
olmadan bilinçli olarak bloke**

Kurum/ürün sahibine ait application ID, upload key, production HTTPS URL,
gizlilik politikası URL'si ve mağaza yetkisi verilmedi. Bu değerler
uydurulmamıştır ve hiçbir secret repoya eklenmemiştir.

## Merkezi release sözleşmesi

| Alan | Kanonik kaynak | Karar |
|---|---|---|
| Uygulama adı | flavor manifest placeholder | dev/staging suffix; prod `NutriSense` |
| Version | `pubspec.yaml` | Her mağaza yüklemesinde versionName/versionCode artırılır |
| Application ID | Gradle `NUTRISENSE_APPLICATION_ID` property | `com.example.*` release blocker |
| Namespace | `android/app/build.gradle.kts` | Kod namespace'i; mağaza ID'sinden ayrı tutulur |
| compile SDK | `android/app/build.gradle.kts` | 36 |
| min SDK | `android/app/build.gradle.kts` | 24 |
| target SDK | `android/app/build.gradle.kts` | 36 |
| Ortam URL'si | `AppConfig` + `--dart-define` | dev yerel HTTP; staging/prod yalnız HTTPS |
| Tanılama logu | `AppConfig.diagnosticLoggingEnabled` + `kDebugMode` | Yalnız dev/test debug |

SDK değerleri sabittir; Flutter SDK yükseltmesi release uyumluluk sözleşmesini
sessizce değiştiremez. SDK değişikliği ayrı cihaz matrisi ve Play politika
incelemesi gerektirir.

## Flavor komutları

```powershell
# Yerel backend / Android emulator
flutter run --flavor dev `
  --dart-define=APP_ENV=dev

# Staging; URL public config'dir, secret değildir
flutter run --flavor staging `
  --dart-define=APP_ENV=staging `
  --dart-define=API_BASE_URL=https://STAGING_HOST/api/v1

# Production; aşağıdaki kimlik ve imza kapıları tamamlanmadan başarısız olur
flutter build appbundle --release --flavor prod `
  --dart-define=APP_ENV=prod `
  --dart-define=API_BASE_URL=https://PRODUCTION_HOST/api/v1
```

`devDebug` yalnız `10.0.2.2`, `127.0.0.1` ve `localhost` için cleartext tanır.
Main/staging/prod ağ ilkesi cleartext'i reddeder ve Android sistem sertifika
deposunu kullanır. Riskli custom certificate bypass yoktur. API, Google,
Nutritionix, Twilio veya SMTP anahtarları flavor ya da `dart-define` içine
konmaz; mobil binary secret saklama yeri değildir.

## Application ID ve imza kapısı

1. Üniversite/ürün sahibi benzersiz reverse-domain application ID'yi yazılı
   kararla belirler.
2. Değer yerel/CI Gradle property olarak
   `NUTRISENSE_APPLICATION_ID=...` biçiminde sağlanır.
3. Yetkili kişi upload keystore'u güvenli kurum cihazında oluşturur. Gerçek
   anahtar Codex tarafından üretilmez.
4. `android/key.properties` yalnız yerel/CI ortamında aşağıdaki alanları taşır:

```properties
storeFile=upload-keystore.jks
storePassword=<secret>
keyAlias=<alias>
keyPassword=<secret>
```

`android/key.properties`, `*.jks` ve `*.keystore` Git tarafından dışlanır.
Release task placeholder ID veya eksik key properties ile hata verir ve debug
key'e düşmez. CI secret değerlerini loglamamalı; geçici key dosyası job sonunda
runner ile imha edilmelidir. Play App Signing kullanılıyorsa upload key ve app
signing key sorumluları kurum kayıtlarında ayrı belirtilmelidir.

## Manifest, izin ve veri koruması

Main manifest yalnız doğrudan kullanılan izinleri ister:

- `INTERNET`: backend ve cihaz konuşma servisleri.
- `CAMERA`: yiyecek tarama.
- `RECORD_AUDIO`: kullanıcı başlattığında sesli komut.

Android bildirim özelliği/runtime akışı bulunmadığı için
`POST_NOTIFICATIONS` yoktur. Özellik eklenirse manifest ve erişilebilir runtime
gerekçesi aynı değişiklikte eklenmelidir.

Kamera akışı geçici rette tekrar deneme/manuel giriş, kalıcı rette sistem
Ayarları eylemi sunar. Mikrofon reddinde dokunmatik/klavye alternatifi korunur.
Fiziksel cihaz kanıtı cihaz kabul raporunda tamamlanmalıdır.

`allowBackup=false`, legacy backup exclusions ve Android 12+ data extraction
exclusions; token, tercih ve yerel cache'in cloud backup/device transfer ile
taşınmasını engeller. Release manifestinde cleartext kapalıdır.

## Yerel preflight

Her commit veya push kararından önce aşağıdaki sıra tamamlanır; başarısız sonuç
gizlenmez:

```powershell
py -3 scripts/qa/android_release_checks.py
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev
```

Android lint doğrudan çalıştırılacaksa Windows sistemindeki eski Java 8 yerine
Android Studio JBR kullanılmalıdır:

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:Path=(Join-Path $env:JAVA_HOME 'bin')+';'+$env:Path
Push-Location android
.\gradlew.bat lintDevDebug --no-daemon --console=plain
Pop-Location
```

Flutter'ın Git'e alınmayan `android/local.properties` dosyasını Windows yol
biçimiyle yeniden üretmesi Android Lint `PropertyEscape` yanlış pozitifine yol
açar. `android/app/lint.xml` yalnız bu generated dosyayı istisna eder; proje
genelinde lint baseline veya hata bastırma yoktur.

Staging public URL ile ayrıca başlatma/config testi yapılır. Kurum kimliği ve
upload key sağlandıktan sonra:

```powershell
flutter build appbundle --release --flavor prod `
  --dart-define=APP_ENV=prod `
  --dart-define=API_BASE_URL=https://PRODUCTION_HOST/api/v1

bundletool validate --bundle build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

Release artefaktında ayrıca şunlar kontrol edilir:

- Signer fingerprint ve Play internal-track kurulum sonucu.
- R8 sonrası auth, secure storage, kamera, geçmiş, TTS/STT ve rapor smoke.
- `.env`, provider key, test token, localhost ve debug endpoint taraması.
- Logcat'te token, parola, e-posta, telefon, base64 veya görüntü yolu olmaması.
- Debug menüsü/test endpointinin prod navigasyonunda ve binary davranışında
  erişilememesi.

## Release checklist

- [ ] Kurum application ID kararı kayda geçti.
- [ ] Version name/code artırıldı.
- [ ] Upload key güvenli üretildi ve kurtarma sorumlusu belirlendi.
- [ ] Production HTTPS API ve provider sandbox doğrulandı.
- [ ] Static checker, analyze ve tüm testler geçti.
- [ ] İmzalı AAB validate edildi ve internal track'ten kuruldu.
- [ ] İki fiziksel cihaz matrisi tamamlandı.
- [ ] TalkBack, %200 font, koyu/yüksek kontrast ve izin retleri geçti.
- [ ] Yavaş ağ/uçak modu/background-kill/kamera lifecycle geçti.
- [ ] Release log/artefakt secret ve PII taraması geçti.
- [ ] Gizlilik politikası ve Data Safety hukuk/KVKK onayı aldı.
- [ ] Mağaza metni yalnız kanıtlı özellikleri içeriyor.

## Rollback

1. Dağıtımı durdur ve staged rollout oranını sıfırla.
2. Güvenli son sürümün kodunu yeni ve daha yüksek versionCode ile forward-fix
   olarak yayınla; eski versionCode yeniden yüklenemez.
3. API geriye uyumluluğunu doğrula; production DB'de plansız migration
   downgrade çalıştırma.
4. Secret/PII olayıysa `SECURITY.md` incident akışını başlat, ilgili anahtarı
   döndür ve etkilenen alıcı/log kapsamını belirle.
5. Cihaz matrisi ve P0 smoke yeniden geçmeden rollout'u açma.

## Mağaza iddiaları ve Data Safety

Kanıtsız “TÜBİTAK destekli”, “WCAG uyumlu”, “800.000 besin”, “tam AI”,
“klinik doğruluk” veya “KVKK uyum garantisi” ifadeleri kullanılamaz. Ürün
tahmini, klinik karar vermeyen besin bilgisi sunar.

Teknik Data Safety taslağı
`docs/play_store_data_safety_draft.md` dosyasındadır. Gerçek gizlilik
politikası URL'si, veri sorumlusu, yurtdışı aktarım değerlendirmesi, retention
ve production sağlayıcıları üniversite hukuk/KVKK birimince onaylanmadan mağaza
yayını yapılamaz.
