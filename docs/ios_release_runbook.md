# iOS release runbook

Durum: **kaynak hazırlığı tamam, iOS tamamlanmadı**

Bu kaynaklar Flutter 3.41.4 stable şablonuyla Windows 11 üzerinde hazırlandı.
Windows ortamında Xcode, CocoaPods, iOS Simulator, codesign veya gerçek iPhone
çalıştırılamadığı için iOS build/archive başarısı iddia edilmez.

## Windows kaynak doğrulama sonucu

27 Temmuz 2026 tarihinde:

| Kontrol | Sonuç |
|---|---|
| `flutter doctor -v` | Flutter 3.41.4 stable, Dart 3.11.1; Windows 11 |
| `flutter pub get` | PASS |
| `python scripts/qa/ios_release_checks.py` | PASS — `SOURCE_READY_NOT_IOS_COMPLETE` |
| `flutter analyze --no-fatal-infos` | PASS — 0 error, 0 warning; 68 info |
| `flutter test` | PASS — 128/128 |
| Release guard davranış testi | PASS — normal build açık; `com.example.*` Archive ve Apple Team'siz Archive bloke |
| `xcodebuild` / CocoaPods `pod` | NOT AVAILABLE |
| Bağlı iOS cihaz/simülatör | YOK |
| `flutter build ios` | BLOKE — Windows Flutter aracında iOS build alt komutu yok |

68 info; mevcut Flutter API deprecation ve stil temizliği bulgularıdır. Bunlar
hata/warning değildir, ancak release bakım backlog'unda tutulmalıdır. Kaynak
kontrolü Xcode projesinin gerçekten derlendiğini, signing'i veya VoiceOver
kullanılabilirliğini kanıtlamaz.

## Merkezi yapılandırma

| Karar | Kaynak | Mevcut değer/durum |
|---|---|---|
| Bundle identifier | `ios/Config/Project.xcconfig` | `com.example.nutrisense` açık placeholder |
| Display name | aynı dosya | `NutriSense` |
| Deployment target | aynı dosya ve Podfile | iOS 13.0 |
| Version/build | `pubspec.yaml` | `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` |
| Swift | Xcode projesi | Swift 5 |
| Apple Team | Xcode signing ayarı | Bilinmiyor; kaynakta yok |

`com.example.*` mağaza kimliği değildir. Xcode Archive sırasında
`ios/scripts/release_guard.sh`, kurum bundle ID'si veya yetkili Apple Team
yoksa işlemi durdurur. `flutter build ios --no-codesign` kaynak derleme
kontrolü olduğu için placeholder ile çalıştırılabilir; bu bir yayın artefaktı
değildir.

## İzin ve ağ politikası

Production `Info.plist` yalnız kullanılan üç izni açıklar:

- Kamera: kullanıcı taramayı başlattığında yiyecek görüntüsü.
- Mikrofon: kullanıcı sesli komutu başlattığında ses girişi.
- Speech recognition: sesli komutun Türkçe metne dönüştürülmesi.

Fotoğraf kitaplığı, konum, bildirim, tracking ve background audio izni yoktur.
`permission_handler_apple` yalnız kamera, mikrofon ve speech recognizer
stratejilerini derler.

Production plist'inde ATS gevşetmesi yoktur. Sadece Debug plist'i
`NSAllowsLocalNetworking=true` içerir; `NSAllowsArbitraryLoads` hiçbir
konfigürasyonda yoktur. iOS Simulator yerel backend örneği:

```powershell
flutter run -d <IOS_SIMULATOR_ID> `
  --dart-define=APP_ENV=dev `
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

Staging ve production `AppConfig` tarafından HTTPS kullanmaya zorlanır.
Provider secret'ları plist, xcconfig veya `dart-define` içine konmaz.

## Plugin uyumluluk envanteri

`flutter pub get` sonrasında iOS uygulaması bulunan kritik pluginler:

| İşlev | iOS plugin | Kaynak durumu | Mac doğrulaması |
|---|---|---|---|
| Kamera | `camera_avfoundation` | Registrant oluştu | Pod compile + gerçek cihaz bekliyor |
| Token/cache kasası | `flutter_secure_storage_darwin` | Keychain adaptörü var | Keychain lock/logout testi bekliyor |
| TTS | `flutter_tts` | iOS audio category kodu var | Türkçe voice/interruption testi bekliyor |
| STT | `speech_to_text` | Gerçek locale seçimi eklendi | Apple izinleri ve cihaz testi bekliyor |
| İzin | `permission_handler_apple` | Yalnız 3 strateji açık | Pod compile bekliyor |
| Paylaşım | `share_plus` | Registrant oluştu | Share sheet smoke bekliyor |
| Dosya/tercih | foundation pluginleri | Registrant oluştu | Pod compile bekliyor |

CocoaPods podspec kaynakları Windows'ta statik olarak incelendi. Kritik
pluginlerin görülen minimum iOS hedefleri kamera ve paylaşım için 12.0,
secure storage için 12.0, TTS/permission handler için 8.0 ve speech-to-text
için 13.0'dır. Bu nedenle merkezi iOS 13.0 hedefi kaynak düzeyinde tutarlıdır.
Bu inceleme Pod çözümleme veya Swift derleme kanıtı değildir.

CocoaPods `Podfile` hazırdır; `Podfile.lock` ve Pods klasörü Windows'ta
üretilmemiştir. Mac'te çözülen sürümler incelendikten sonra `Podfile.lock`
commitlenmelidir. Pods klasörü commitlenmez.

## Mac kaynak/build doğrulaması

Desteklenen bir Mac ve güncel Xcode'da:

```bash
flutter doctor -v
flutter --version
dart --version
flutter pub get
python3 scripts/qa/ios_release_checks.py

cd ios
pod --version
pod install
cd ..

flutter analyze --no-fatal-infos
flutter test
flutter test test/accessibility/ios_voiceover_semantics_test.dart
flutter build ios --release --no-codesign \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL=https://GERCEK_PRODUCTION_HOST/api/v1
```

Kabul kanıtına Xcode/Swift/CocoaPods sürümleri, build log özeti, app checksum ve
commit SHA eklenir. `--no-codesign` geçmeden signing çalışmasına başlanmaz.

## Signing ve Archive

1. Kurum/ürün sahibi Apple Developer hesabı ve benzersiz bundle ID kararını
   verir.
2. `ios/Config/Project.xcconfig` içindeki placeholder bu kimlikle değiştirilir.
3. Xcode Runner target Signing & Capabilities altında yetkili Team seçilir.
4. Development/distribution sertifikaları ve private key yalnız macOS Keychain
   veya CI secret store'da tutulur; repoya aktarılmaz.
5. İlk doğrulama TestFlight/internal testing ile sentetik hesapta yapılır.
6. Archive organizer logu, signing certificate fingerprint'i ve App Store
   validation sonucu kişisel/secret değer göstermeden kaydedilir.

`keychain`, `.p12`, provisioning profile ve App Store API anahtarları Git'e
konmaz. Bu çalışma Apple hesabı/signing/publish işlemi yapmamıştır.

## TTS, STT ve audio session kabulü

- Cihazın sunduğu `tr_TR`, `tr-TR` veya başka Türkçe locale gerçek değeri
  kullanılır; Türkçe yoksa dokunmatik/klavye alternatifi gösterilir.
- TTS yalnız iOS'ta playback/voicePrompt category ve Bluetooth seçeneklerini
  yapılandırır.
- STT başlamadan TTS ve kuyruğu durdurulur.
- Uygulama inactive/background olduğunda TTS durur; background audio capability
  yoktur.
- Telefon çağrısı/Siri, alarm, Bluetooth bağlantı değişimi ve kulaklık
  çıkarılması gerçek cihazda ayrıca test edilmelidir.

Bu davranışların cihaz kanıtı yoktur; yalnız kaynak politikası hazırdır.

## Kamera kabulü

Kamera medium çözünürlük, ses kapalı ve JPEG formatıyla açılır. Ön işleme EXIF
orientation'ı `bakeOrientation` ile uygular. Mac/iPhone testinde:

- ön/arka kamera ve tüm yönler;
- HEIC giriş oluşursa decode/reddetme davranışı;
- background/foreground, ekran kilidi ve telefon çağrısı;
- tekrar çekimde geçici dosya temizliği;
- 20 taramada bellek artışı, cold/warm latency ve crash/ANR

ölçülmelidir. TFLite modeli paketlenmediği için offline model/latency iddiası
yoktur.

## App Store ve privacy kapıları

- App icon hâlâ Flutter şablon ikonudur; kurum onaylı ikonla değiştirilmelidir.
- Gerçek support ve privacy URL'leri sağlanmamıştır.
- Privacy Nutrition Labels; production backend, görüntü sağlayıcısı, besin
  sağlayıcısı, e-posta/SMS ve barındırma ülkeleri netleşmeden tamamlanamaz.
- Crashlytics/analytics yapılandırılmamıştır; kullanılıyor diye beyan edilmez ve
  ilgili SDK privacy manifest/consent eklenmez.
- Hesap silme, dışa aktarma ve diyetisyen paylaşım onayı gerçek iPhone'da
  doğrulanmalıdır.
- Kanıtsız TÜBİTAK, WCAG, sınıf/besin sayısı ve klinik doğruluk ifadeleri
  mağazada kullanılamaz.

## Rollback

1. TestFlight/App Store rollout durdurulur.
2. Güvenli son kod yeni ve daha yüksek build number ile forward-fix edilir.
3. Backend/API geriye uyumluluğu doğrulanır; plansız DB downgrade yapılmaz.
4. Signing/secret olayıysa `SECURITY.md` incident akışı uygulanır.
5. Archive, iPhone P0 ve VoiceOver matrisi yeniden geçmeden dağıtım açılmaz.

## iOS tamamlandı demek için kalan kapılar

- [ ] Mac'te CocoaPods kurulumu ve `flutter build ios --no-codesign` geçti.
- [ ] Kurum bundle ID'si ve Apple Team kararı verildi.
- [ ] İmzalı Archive/TestFlight kurulumu geçti.
- [ ] Gerçek iPhone P0 auth–kamera–sonuç–history–rapor akışı geçti.
- [ ] VoiceOver manuel raporu tamamlandı.
- [ ] Kamera/audio interruption/bellek/latency ölçüldü.
- [ ] Gerçek app icon, support/privacy URL ve Privacy Labels onaylandı.
