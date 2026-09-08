# iOS Devir Notu — Mac'te ne yapılacak

Bu belge, projeyi Mac'te ilk kez açacak kişi içindir. Windows'ta yapılabilecek
her şey tamamlanmıştır; kalan işler yalnız macOS gerektiren adımlardır.

## Durum

Kaynak tarafı hazır ve otomatik kapıdan geçiyor
(`python3 scripts/qa/ios_release_checks.py` → `IOS_SOURCE_CHECK=PASS`).
Xcode projesi, merkezi yapılandırma, izin metinleri, ağ politikası, plugin
kayıtları, uygulama simgeleri ve açılış ekranı yerinde. Proje **hiç
derlenmemiştir**, çünkü iOS derlemesi Windows'ta mümkün değildir.

## Gereken

- macOS ve Xcode (App Store'dan)
- Flutter SDK: https://docs.flutter.dev/get-started/install/macos
- CocoaPods: `sudo gem install cocoapods`

## Tek komut

Depo kökünde:

```bash
bash ios/scripts/mac_setup.sh
```

Betik sırayla şunları yapar ve her adımı ✓/✗ olarak bildirir:

1. Ön koşulları denetler (Xcode, Flutter, CocoaPods)
2. `flutter pub get`
3. `cd ios && pod install --repo-update`
4. iOS kaynak doğrulama kapısını çalıştırır
5. `flutter build ios --no-codesign` ile imzasız derler
6. Bağlı bir iPhone veya simülatör varsa P0 uçtan uca testini koşar

Beklenen sonuç: **"Kaynak doğrulaması tamam."**

## Uygulamayı çalıştırmak

Backend'i ayrı bir terminalde ayağa kaldırın (Docker Desktop gerekir):

```bash
docker compose -f backend/docker-compose.yml up -d
```

Sonra simülatörde veya cihazda:

```bash
flutter run --dart-define=APP_ENV=dev
```

> Android komutlarındaki `--flavor dev` iOS'ta kullanılmaz: iOS projesinde
> flavor şeması tanımlı değildir, yalnız `Runner` şeması vardır.

> Simülatörde kamera yoktur. Besin tanımayı denemek için uygulamada
> **Ayarlar → Cihaz Üstü Model** anahtarını açın, ardından tarama ekranındaki
> **"Galeriden fotoğraf seç"** düğmesiyle bir yemek fotoğrafı seçin. Bu yol
> sunucuya gitmez, modeli doğrudan cihazda çalıştırır.

## Sorun çıkarsa

| Belirti | Yapılacak |
|---|---|
| `pod install` mimari hatası veriyor | Apple Silicon'da: `cd ios && arch -x86_64 pod install` |
| `CocoaPods could not find compatible versions` | `cd ios && pod repo update` sonra tekrar |
| `Generated.xcconfig must exist` | Depo kökünde önce `flutter pub get` |
| Derleme imzalama hatası veriyor | `--no-codesign` ile derlediğinizden emin olun |
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
