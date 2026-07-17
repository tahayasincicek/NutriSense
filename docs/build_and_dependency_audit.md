# NutriSense derleme ve bağımlılık denetimi

> **Sonraki değişiklik notu:** API istemci mimarisi bu denetimden sonra
> `docs/api_contract.md` ve ADR-001 kapsamında kanonikleştirildi;
> `FoodAnalysisService` kaldırıldı. Ağ sözleşmesi için güncel kaynak bu iki
> belgedir.

**Denetim tarihi:** 17 Temmuz 2026  
**Denetlenen proje:** `C:\Users\TAHA\Desktop\2209\nutrisense`  
**Amaç:** Yeni özellik eklemeden, mevcut Flutter istemcisini temiz bir ortamda çözümlenebilir, analiz edilebilir, temel düzeyde test edilebilir ve Android debug APK üretebilir hale getirmek.

## Sonuç özeti

| Kabul kapısı | Son durum | Kanıt |
|---|---|---|
| `flutter pub get` | **GEÇTİ** | Bağımlılıklar çözüldü; `intl 0.19.0` Flutter SDK tarafından transitif olarak seçildi. |
| Aktif `package:` importları | **GEÇTİ** | SDK/proje-içi importlar hariç kullanılan tüm paketler `pubspec.yaml` içinde. Firebase adları yalnızca yorum satırında; aktif import değil. |
| `flutter analyze --no-fatal-infos` | **GEÇTİ** | 0 error, 0 warning, 57 info. Info kayıtları aşağıdaki backlog'da. |
| Temel smoke/unit testleri | **GEÇTİ** | 62/62 test geçti. Varsayılan sayaç testi gerçek `NutriSenseApp` kabuğunu açıyor. |
| Bütün test paketi | **GEÇMEDİ — gizlenmedi** | 77 geçti, 2 test başarısız. İki hata da ürün ekranını import etmeyen `food_history_screen_test.dart` içindeki test-yerel sahte widget'larda. |
| Android debug build | **GEÇTİ** | `app-debug.apk`, 97.483.436 bayt, SHA-256 `E572E3F2E31CD6ADDB85FDD618048C5B9436F099EBC95BABA90A891DC91B1DF2`. |
| Android release | **BİLİNÇLİ OLARAK BLOKE** | Kuruma ait application ID ve release keystore yok. `com.example.*` ile release görevi fail-fast olur. |
| iOS build | **UYGULANAMAZ / EKSİK** | Projede `ios/` platform dizini yok; `GoogleService-Info.plist` de yok. |

## Araç zinciri ve ortam

Denetimde sistem PATH'ine güvenmek yerine projeyle birlikte bulunan şu Flutter çalıştırıcısı kullanıldı:

`C:\Users\TAHA\Desktop\2209\flutter_sdk\flutter\bin\flutter.bat`

- Flutter: **3.22.0 stable**
- Dart: **3.4.0**
- Android SDK: **36.1.0**
- Java: **21**
- Kurulu ve proje tarafından sabitlenen NDK: **28.2.13676358**
- `flutter doctor -v`: Android toolchain kullanılabilir. Android cihaz bağlı değil; yalnızca Windows/web hedefleri görüldü.
- Ortam sorunu: PATH, kullanılan bundled SDK yerine `C:\Users\TAHA\dev\flutter` konumunu işaret ediyor. Tekrar üretimde aşağıdaki mutlak Flutter yolu kullanılmalı veya PATH bilinçli biçimde düzeltilmeli.

## Başlangıç durumu ve kontrollü teşhis

İlk `flutter pub get`, `flutter analyze` ve `flutter test` çağrıları uygulama koduna başlamadan bağımlılık çözümünde durdu: proje `intl 0.20.2` isterken Flutter 3.22 içindeki `flutter_localizations`, `intl 0.19.0` sürümünü sabitliyordu. Kaynakta doğrudan `package:intl` importu olmadığı doğrulandığı için doğrudan `intl` girdisi kaldırıldı; SDK'nın transitif ve uyumlu sürümü kullanılıyor.

Android build sırasında bulunan uyumluluk sorunları ve çözümleri:

1. Kotlin DSL, Flutter 3.22 API'sine göre düzeltildi: `flutter.versionCode()` ve `flutter.versionName()` kullanıldı; Kotlin JVM hedefi yeni `compilerOptions` üzerinden ayarlandı.
2. Çözücünün seçtiği `flutter_tts 4.2.5`, minSdk 24 istiyordu. Uygulamanın minSdk 21 kararı korunarak Flutter 3.22 ile uyumlu `flutter_tts 4.0.2` sabitlendi.
3. Çözücünün seçtiği `camera_android_camerax 0.6.8+2`, Flutter 3.22'de bulunmayan bir `TextureRegistry` callback API'si kullanıyordu. Uyumlu platform paketi `0.6.5` olarak açıkça sabitlendi.
4. Eklentilerin NDK 27+ gereksinimi için makinede bulunan NDK `28.2.13676358` açıkça sabitlendi.

Bu sabitlemeler rastgele eski sürüm seçimi değildir; mevcut Flutter 3.22 araç zincirinin bilinen derleme sözleşmesini korur. Flutter yükseltildiğinde bu üç pin birlikte yeniden değerlendirilmelidir.

## Bağımlılık ve import denetimi

Aktif kaynak/test importlarından bulunan harici paketler:

`camera`, `device_info_plus`, `dio`, `equatable`, `flutter_riverpod`, `flutter_tts`, `image`, `path_provider`, `permission_handler`, `share_plus`, `shared_preferences`, `speech_to_text`, `uuid`, `vibration`.

Hepsi `pubspec.yaml` içinde tanımlıdır. Ayrıca `camera_android_camerax` Dart tarafından doğrudan import edilmez; Android kamera implementasyonunun Flutter 3.22 ile uyumlu sürümünü deterministik seçmek için bilinçli doğrudan pindir.

### Bilinen dört uyumsuzluğun kararı

| Paket | Karar | Gerekçe |
|---|---|---|
| `device_info_plus` | Eklendi | Kullanılabilirlik/araştırma dışa aktarımında gerçek cihaz metadatası okunuyor. |
| `share_plus` | Eklendi | Dışa aktarılan kullanılabilirlik verisini paylaşma akışında kullanılıyor. |
| `firebase_core` | Eklenmedi | Aktif import ve çalışan Firebase adaptörü yok; sadece `crash_reporter.dart` içinde yorum örneği vardı. |
| `firebase_crashlytics` | Eklenmedi | Gerçek platform kimlik bilgileri yok. Sahte `google-services.json` veya plist üretilmedi. |

Firebase/Crashlytics isteğe bağlıdır. `ENABLE_FIREBASE_CRASHLYTICS=true` verilirse uygulama, yarım entegrasyonla sessizce çalışmak yerine açıklayıcı hata ile durur. Firebase kullanılacaksa ayrı adaptör, gerçek Android/iOS platform dosyaları ve test kanıtı eklenmelidir. Depoda `android/app/google-services.json` yoktur; `ios/` dizini de yoktur.

### Kaldırılan kullanılmayan doğrudan bağımlılıklar

Aktif import/çalışan entegrasyon bulunmayan şu doğrudan bağımlılıklar kaldırıldı:

- `riverpod_annotation`, `image_picker`, `retrofit`, `hive_flutter`
- `flutter_local_notifications`, `google_fonts`, `flutter_svg`, `shimmer`
- doğrudan `json_annotation`, `logger`, `intl`
- kullanılmayan üretici/test araçları: `build_runner`, `riverpod_generator`, `json_serializable`, `retrofit_generator`, `hive_generator`, `accessibility_tools`, `mockito`, `integration_test`

`google_fonts` kaldırılırken tema sistem fontlarına geçirildi. Böylece çalışma anında font indirme davranışı yoktur.

## Uygulama girişi ve ortam yapılandırması

- Tek yürütülebilir giriş noktası `lib/main.dart` içindeki `main()` fonksiyonudur.
- Merkezi yapılandırma `lib/core/config/app_config.dart` içindedir.
- Desteklenen ortamlar: `dev`, `test`, `prod`.
- Geliştirme varsayılanı: `http://10.0.2.2:8000/api/v1`.
- Test varsayılanı: `http://127.0.0.1:8000/api/v1`.
- Production ortamında URL varsayılmaz. Mutlaka HTTPS bir `API_BASE_URL` verilmesi gerekir.
- URL içinde kullanıcı bilgisi, query veya fragment kabul edilmez; sondaki `/` normalize edilir.
- Eski gömülü `https://api.nutrisense.app/v1` varsayımı kaldırıldı.
- API anahtarları veya servis secret'ları Dart define'a ya da mobil binary'ye eklenmedi. `--dart-define` yalnızca secret olmayan ortam/URL seçimi içindir.

Ortam yapılandırması için birim testi eklendi. Test; varsayılan dev ortamını, merkezi URL'yi, Firebase'in kapalı olmasını ve doğrulamanın başarılı olmasını kontrol eder.

## Android izinleri ve dağıtım kapıları

Ana manifestte yalnızca mevcut çalışan akışlarla ilişkili izinler bulunur:

- `INTERNET`: backend/API çağrıları için.
- `CAMERA`: besin tarama ekranı için; `CameraScreen` runtime'da `Permission.camera.request()` çağırır.
- `RECORD_AUDIO`: STT/sesli komut için; hem `SttService` hem `VoiceCommandService` runtime mikrofon izni ister.

`POST_NOTIFICATIONS` bilinçli olarak eklenmedi. Uygulamada Android local/push notification üreten çalışan akış yok; yalnızca e-posta/SMS tercih alanları var. API 33+ bildirimi gerçekten eklendiğinde manifest izni ve runtime isteme akışı aynı değişiklikte eklenmelidir.

Release güvenlik kapıları:

- `NUTRISENSE_APPLICATION_ID=com.example.nutrisense` merkezi, açık bir placeholder'dır.
- Herhangi bir release Gradle görevi `com.example.*` kimliği ile fail-fast olur.
- Release yapı tipi debug anahtarıyla imzalanmaz.
- Kuruma ait ters alan adı application ID'si tahmin edilmedi.
- Kuruma ait keystore; dosya/şifreyi depoya koymadan CI secret mekanizmasıyla yapılandırılmalıdır.

## Asset, model ve font davranışı

- `assets/images`, `assets/icons`, `assets/sounds`, `assets/models` dizinlerinde gerçek asset yoktur; yalnızca boş tutucu dosyalar vardır.
- Bu dizinler `pubspec.yaml` altında bundle edilmez. Boş `models` dizini gerçek model varmış gibi sunulmaz.
- `assets/fonts` altında 14 dosya ve yaklaşık 16,5 MB veri vardır. Bunlar pubspec'te tanımlı değildir ve APK'ya bundle edilmez.
- Tema sistem fontlarını kullandığından bildirilmeyen özel font ailesine bağımlılık yoktur.
- Gerçek model ileride eklenecekse dosya hash'i, kaynak/lisans, input-output sözleşmesi ve yükleme testiyle birlikte ayrıca tanımlanmalıdır.

## Test dürüstlüğü

`test/widget_test.dart` içindeki varsayılan Flutter sayaç testi kaldırıldı. Yerine gerçek `NutriSenseApp` import edilip `ProviderScope` altında açılıyor; `MaterialApp` başlığı ve gerçek alt navigasyon öğeleri doğrulanıyor. Testte platform servislerinin başlatılması, eklenti kanallarını taklit etmeden yalnızca smoke testi yapabilmek için constructor seçeneğiyle kapatılıyor.

Hedefli güvenilir kapı:

```text
flutter test test\unit test\widget_test.dart --reporter compact
62 test geçti, 0 başarısız
```

Tam paket sonucu gizlenmemiştir:

```text
flutter test --reporter compact
77 test geçti, 2 test başarısız
```

Başarısız testler:

1. `test/widget/food_history_screen_test.dart` — “Yemek listesi doğru bilgileri göstermeli”: test `10:30` bekliyor, kendi ürettiği sahte tile zamanı ekrana basmıyor.
2. Aynı dosya — “Semantics label yemek bilgisi içermeli”: test-yerel widget beklenen semantics ağacını üretmiyor.

Bu dosya ürün `FoodHistoryScreen` sınıfını import etmez; yalnızca tema import edip `_buildMockFoodTile` ve test-yerel ekranlar kurar. `camera_screen_test.dart` da ürün kamera ekranını import etmeden test-yerel arayüz kurar. Erişilebilirlik testleri de büyük ölçüde izole örnek widget'ları sınar. Hiçbiri `skip` ile saklanmadı.

**QA-01 (P1):** Bu üç test grubu gerçek ürün widget'larını import etmeli; Riverpod bağımlılıkları sahte repository/provider ile enjekte edilmeli; kamera platform kanalı kontrollü fake ile sınanmalı. Kabul ölçütü: test-yerel ekran kopyası olmadan `flutter test` 0 başarısızlıkla biter ve geçmiş kartının saat/semantics sözleşmesi ürün kodu üzerinde doğrulanır.

Test çalışması ayrıca gerçek bir ürün hatası buldu: boş sesli komut tüm alias'larla eşleşebiliyordu. `VoiceCommandService.matchCommand` boş normalize edilmiş girdi için erken “tanınmadı” dönecek şekilde düzeltildi ve regresyon testi geçiyor.

## Analyzer info backlog'u

`flutter analyze --no-fatal-infos` sonucu: **0 error, 0 warning, 57 info**. Kabul ölçütü warning/info'ların gerekçeli backlog'a alınmasına izin verdiği için info seviyesi build engeli yapılmadı.

| Öncelik | Kayıt | Planlanan kabul ölçütü |
|---|---|---|
| P2 | `speech_to_text` eski `listenMode`, `cancelOnError`, `partialResults` parametreleri | Uyumlu paket yükseltmesinden sonra `SpeechListenOptions` kullanılır; STT testleri ve Android build geçer. |
| P2 | `textScaleFactorOf` deprecation | `MediaQuery.textScalerOf` geçişi yapılır; erişilebilirlik testleri geçer. |
| P3 | Çoğunlukla `prefer_const_*` lintleri | Davranış değişmeden dar kapsamlı const temizliği yapılır. |
| P3 | İki `unnecessary_import`, bir string interpolation ve bir braces linti | Dosya bazlı temizlik sonrası analyzer info sayısı azaltılır. |

## P0/P1 açık konular

| Öncelik | Konu | Etki | Çözülme kapısı |
|---|---|---|---|
| P0 (release) | Kuruma ait application ID yok | Store/release üretilemez | Yetkili kurum ID'si sağlanır; `NUTRISENSE_APPLICATION_ID` değiştirilir. |
| P0 (release) | Release keystore/CI signing yok | Güvenilir imzalı APK/AAB üretilemez | CI secret tabanlı signing ve imzalı artefakt doğrulaması. |
| P0 (iOS) | `ios/` platform dizini yok | IPA üretilemez; iOS izinleri/testleri yok | Uyumlu macOS/Xcode ortamında iOS platformu oluşturulur, mevcut bundle ID kararıyla incelenir ve gerçek cihaz/simülatör testi yapılır. |
| P1 | Tam test paketi 2 hata veriyor ve bazı widget testleri ürün kodunu sınamıyor | Yanlış güven üretir | QA-01 tamamlanır; tam suite yeşil olur. |
| P1 | Production API URL'si bilinçli olarak tanımsız | Prod uygulaması başlamaz | Kurumun doğrulanmış HTTPS endpoint'i verilerek sözleşme/integration testi geçer. |
| P1 (opsiyonel) | Firebase platform dosyaları/adaptörü yok | Crashlytics kapalı | Özellik gerçekten seçilirse gerçek platform konfigürasyonu, consent/policy ve sandbox kanıtı eklenir. |

## Değiştirilen dosyalar

Davranışsal/yapılandırma değişikliği yapılan ana dosyalar:

- `pubspec.yaml`, `pubspec.lock`
- `lib/main.dart`
- `lib/core/config/app_config.dart`
- `lib/core/constants/app_constants.dart`
- `lib/core/theme/app_theme.dart`
- `lib/shared/services/api_service.dart`
- `lib/shared/services/food_analysis_service.dart`
- `lib/shared/services/stt_service.dart`
- `lib/shared/services/voice_command_service.dart`
- `lib/features/survey/services/survey_service.dart`
- Android manifest, `android/gradle.properties`, `android/app/build.gradle.kts`
- `test/widget_test.dart`, `test/unit/app_config_test.dart`, `test/unit/voice_command_test.dart`
- Derleme/analyzer uyumluluğu için dar düzeltmeler yapılan accessibility, survey, history ve test dosyaları
- Bu denetim belgesi

`dart format lib test` bir kez geniş kapsamlı çalıştırıldığı için 28 dosyada ayrıca yalnızca mekanik biçimlendirme değişikliği oluştu. Projede Git deposu bulunmadığından önceki içerik güvenli biçimde geri alınamadı; bu durum saklanmamıştır. Kullanıcı verisi silinmedi veya değiştirilmedi.

Üretilen/yenilenen araç artefaktları arasında `.dart_tool`, `.flutter-plugins-dependencies` ve `build/` çıktıları bulunur.

## Kesin tekrar üretim komutları

PowerShell, proje kökünde:

```powershell
$nutriFlutter = 'C:\Users\TAHA\Desktop\2209\flutter_sdk\flutter\bin\flutter.bat'
$nutriDart = 'C:\Users\TAHA\Desktop\2209\flutter_sdk\flutter\bin\cache\dart-sdk\bin\dart.exe'

& $nutriFlutter doctor -v
& $nutriFlutter --version
& $nutriDart --version
& $nutriFlutter pub get
& $nutriFlutter analyze --no-fatal-infos
& $nutriFlutter test test\unit test\widget_test.dart --reporter compact
& $nutriFlutter test --reporter compact
& $nutriFlutter build apk --debug --dart-define=APP_ENV=dev
Get-FileHash build\app\outputs\flutter-apk\app-debug.apk -Algorithm SHA256
```

Tam test komutunun QA-01 tamamlanana kadar iki görünür hata ile çıkması beklenir. Debug build kapısı bundan bağımsız olarak geçmektedir.

Test ortamı örneği:

```powershell
& $nutriFlutter test --dart-define=APP_ENV=test
```

Production derleme biçimi; endpoint değeri repoya yazılmadan CI tarafından sağlanmalıdır:

```powershell
& $nutriFlutter build appbundle --release `
  --dart-define=APP_ENV=prod `
  --dart-define=API_BASE_URL=https://kuruma-ait-dogrulanmis-host/api/v1
```

Bu komut ayrıca kuruma ait application ID ve signing kurulmadığı sürece bilinçli olarak başarısız olur. Mobil binary içine secret verilmemelidir.

## 2026-07-17 son doğrulama güncellemesi

Bu bölüm, yukarıdaki eski test sayıları ve QA-01 durumunun güncel sonucudur:

- Flutter 3.41.4 / Dart 3.11.1 ile `flutter pub get` başarılıdır.
- `flutter test --no-pub` sonucu **90 test geçti, 0 başarısız**. QA-01 kapsamında geçmiş ekranı testleri artık test-yerel sahte ekran yerine gerçek `FoodHistoryScreen` ve kanonik JSON fixture kullanır.
- `flutter analyze --no-pub --no-fatal-infos` sonucu **0 error, 0 warning, 100 info**. Info kayıtları çoğunlukla Flutter API deprecation ve `prefer_const_*` temizlikleridir; release engeli değildir ve P2/P3 backlog olarak korunur.
- Temiz `flutter build apk --debug --no-pub` başarılıdır. Son kaynak değişikliğinden sonraki incremental build de başarılıdır.
- `backend\\venv\\Scripts\\python.exe -m pytest -q` sonucu **19 test geçti**.
- `backend\\venv\\Scripts\\python.exe scripts\\export_openapi.py --check` drift kontrolü başarılıdır. Google Vision kimliği bulunmadığına dair mesaj, opsiyonel dış sağlayıcının bilinçli olarak yapılandırılmadığını gösterir.

CI Flutter sürümü yerel doğrulamayla aynı olan 3.41.4'e sabitlenmiştir. Android debug artefaktı `build/app/outputs/flutter-apk/app-debug.apk` altında üretilir; `build/` Git'e alınmaz.
