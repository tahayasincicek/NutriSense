# iOS Devir Notu — Mac'te ne yapılacak

Bu belge, projeyi Mac'te ilk kez açacak geliştirici içindir. Yerel kurulum ve cihaz doğrulama adımlarını açıklar.

## Durum

Kaynak tarafı hazır ve otomatik kapıdan geçiyor
(`python3 scripts/qa/ios_release_checks.py` → `IOS_SOURCE_CHECK=PASS`).
Xcode projesi, merkezi yapılandırma, izin metinleri, ağ politikası, plugin
kayıtları, uygulama simgeleri ve açılış ekranı yerinde. 8 Eylül 2026 doğrulaması: [GitHub koşusu 33510763349](https://github.com/tahayasincicek/NutriSense/actions/runs/33510763349) içindeki **iOS Derleme** işi başarılıdır. Koşunun tamamı iptal edilmiştir; bu başarı yalnız ilgili iOS işine aittir. İmzalı Archive, TestFlight ve gerçek iPhone/VoiceOver testleri ayrıca doğrulanmalıdır.

## Gereken

- macOS ve Xcode (App Store'dan)
- Flutter SDK: https://docs.flutter.dev/get-started/install/macos
- CocoaPods: `sudo gem install cocoapods`

## Tek komut

Önce [ortak geliştirme kurulumunu](developer_setup.md) tamamlayın; bu adım backend `.env` dosyasını ve ilk veritabanı tablolarını hazırlar. Flutter 3.41.4 kullanın.

Depo kökünde:

```bash
bash ios/scripts/mac_setup.sh
```

Betik sırayla şunları yapar ve her adımı ✓/✗ olarak bildirir:

1. Ön koşulları denetler (Xcode, Flutter, CocoaPods)
2. `flutter pub get`
3. `cd ios && pod install --repo-update`
4. iOS kaynak doğrulama kapısını çalıştırır
5. `flutter build ios --debug --no-codesign` ile imzasız derler
6. Bağlı bir iPhone veya simülatör varsa P0 uçtan uca testini koşar

Beklenen sonuç: **"Kaynak doğrulaması tamam."**

## Uygulamayı çalıştırmak

Backend'i ayrı bir terminalde ayağa kaldırın (Docker Desktop gerekir):

```bash
docker compose -f backend/docker-compose.yml up -d
```

Sonra simülatörde veya cihazda:

```bash
flutter run -d <IOS_CIHAZ_ID> --debug --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

> Android komutlarındaki `--flavor dev` iOS'ta kullanılmaz: iOS projesinde
> flavor şeması tanımlı değildir, yalnız `Runner` şeması vardır.

Yukarıdaki adres simülatör içindir. Fiziksel iPhone'da `127.0.0.1` yerine aynı ağdaki Mac'in IP adresini kullanın.

> Simülatörde kamera yoktur. Besin tanımayı denemek için uygulamada
> **Ayarlar → Cihaz Üstü Model** anahtarını açın, ardından tarama ekranındaki
> **"Galeriden fotoğraf seç"** düğmesiyle bir yemek fotoğrafı seçin. Bu yol
> sunucuya gitmez, modeli doğrudan cihazda çalıştırır.

## Gerçek bir iPhone'a kurmak isterseniz

Simülatör için hiçbir ek adım gerekmez. Fiziksel cihaza kurmak isterseniz
Xcode bir geliştirici takımı ister:

1. `open ios/Runner.xcworkspace`
2. Sol panelde **Runner** hedefi → **Signing & Capabilities**
3. **Team**: kendi Apple kimliğinizi seçin (ücretsiz hesap yeter; imza 7 gün
   geçerlidir, geliştirme için sorun değil)
4. Bundle ID `com.example.nutrisense` reddedilirse (başkası almış olabilir),
   `ios/Config/Project.xcconfig` içindeki `NUTRISENSE_BUNDLE_ID` değerini
   **yalnız kendi makinenizde** benzersiz bir şeyle değiştirin, örneğin
   `com.adiniz.nutrisense`. **Bu değişikliği commit etmeyin.**

> Neden commit edilmiyor: `com.example.` yer tutucusu bilinçli bir güvenlik
> kapısıdır. Depoda kaldığı sürece kimse yanlışlıkla yer tutucu kimlikle
> imzalı Archive üretemez (`ios/scripts/release_guard.sh` ve
> `scripts/qa/ios_release_checks.py` bunu zorunlu tutar). Kurumun gerçek
> kimliği belirlendiğinde bu değer ve ilgili kapı birlikte güncellenir.

## Sorun çıkarsa

| Belirti | Yapılacak |
|---|---|
| `pod install` mimari hatası veriyor | Flutter, Ruby ve CocoaPods'un aynı mimaride çalıştığını kontrol edin; Apple Silicon'da önce yerel arm64 kurulumu kullanın |
| `CocoaPods could not find compatible versions` | `cd ios && pod repo update` sonra tekrar |
| `Generated.xcconfig must exist` | Depo kökünde önce `flutter pub get` |
| Derleme imzalama hatası veriyor | `--no-codesign` ile derlediğinizden emin olun |
| Cihaza kurarken `bundle identifier is not available` | Yukarıdaki "Gerçek bir iPhone'a kurmak" adımına bakın |
| `You cannot use the --flavor option` | iOS'ta flavor şeması yoktur; komutlarda `--flavor` kullanmayın (Android'e özgüdür) |

## Bilerek yapılmayan, karar gerektiren adımlar

Bunlar teknik eksiklik değil, kurumsal karar bekleyen işlerdir:

1. **Bundle ID ve Apple Team.** `ios/Config/Project.xcconfig` içindeki
   `NUTRISENSE_BUNDLE_ID` hâlâ `com.example.nutrisense`. Archive bu değerle
   **bilerek engellenir** (`ios/scripts/release_guard.sh`); imzalı çıktı almak
   için kurumun sahip olduğu bir kimlik yazılmalıdır.
2. **İmzalı Archive / TestFlight.**
3. **Gerçek iPhone'da VoiceOver ile elle erişilebilirlik testi.** Android
   tarafında TalkBack testi yapıldı; VoiceOver karşılığı yapılmadı ve
   `docs/accessibility_conformance_report.md` içinde `NOT RUN` olarak
   işaretlidir.
4. **Kamera/ses kesintisi, bellek ve cihaz gecikmesi ölçümleri.** Model
   kartındaki gecikme alanı gerçek donanımda ölçülene kadar `not_run` kalır.

Adım adım anlatım: `docs/ios_release_runbook.md`, "iOS tamamlandı demek için
kalan kapılar" başlığı.
