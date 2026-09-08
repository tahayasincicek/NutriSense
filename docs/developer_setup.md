# Android ve iOS geliştirici başlangıcı

Bu belge yeni bir Git klonu içindir. Ortak sürüm: **Flutter 3.41.4 / Dart 3.11.1** (CI ile aynı). Python 3.11+, Git ve çalışan Docker Desktop / Compose v2 gerekir. Mobil uygulamayı çalıştırmak için model eğitimi gerekmez: TFLite modeli, etiketler ve besin kataloğu depodadır.

## 1. Depoyu ve yerel backend'i hazırlayın

```sh
git clone https://github.com/tahayasincicek/NutriSense.git
cd NutriSense
python scripts/dev_setup.py
flutter pub get
docker compose -f backend/docker-compose.yml up -d --build --wait
```

macOS'ta `python` yerine `python3` kullanın. Betik kişiye özel rastgele sırlarla `backend/.env` üretir; mevcut dosyayı değiştirmez. Yeni ortamda `MIGRATION_STARTUP_MODE=apply` tabloları Alembic ile oluşturur. Önceden üretilmiş yerel `.env` ile migration hatası alırsanız bu alanı `apply` yapıp Compose komutunu yeniden çalıştırın. Üretim ortamında ayrı migration süreci kullanılır.

Hazırlık kontrolü: `http://localhost:8000/health/ready`. API: `http://localhost:8000/docs`. Test e-postaları: `http://localhost:8025`.

## 2. Android

Android Studio, Android SDK Platform 36, JDK 17 ve NDK **28.2.13676358** kurulu olmalı. SDK Manager ile eksikleri yükleyin; `flutter doctor -v` ve `flutter doctor --android-licenses` çalıştırın. Android 7 / API 24 veya üstü gerekir.

Emülatörü açıp cihaz kimliğini `flutter devices` ile alın:

```sh
flutter run -d <ANDROID_CIHAZ_ID> --flavor dev --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

USB ile gerçek Android telefon için USB hata ayıklamayı açıp bilgisayarı telefonda onaylayın:

```sh
adb -s <ANDROID_CIHAZ_ID> reverse tcp:8000 tcp:8000
flutter run -d <ANDROID_CIHAZ_ID> --flavor dev --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Paylaşılabilir geliştirme APK'sı:

```sh
flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev
```

Çıktı: `build/app/outputs/flutter-apk/app-dev-debug.apk`. Bu APK varsayılan olarak emülatör adresini kullanır; fiziksel telefona dağıtırken erişilebilir `API_BASE_URL` ile yeniden derleyin. `--flavor dev` olmadan APK arama hatası alınabilir.

## 3. iOS

macOS, tam Xcode kurulumu, iOS Simulator runtime ve CocoaPods gerekir. `flutter doctor -v` ile kurulumu doğrulayın. Windows'ta iOS derlenemez.

```sh
bash ios/scripts/mac_setup.sh
open -a Simulator
flutter devices
flutter run -d <IOS_SIMULATOR_ID> --debug --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

iOS'ta `--flavor dev` kullanmayın. Fiziksel iPhone için `ios/Runner.xcworkspace` dosyasını Xcode'da açın, Runner hedefinde kendi Team'inizi seçin ve gerekirse `ios/Config/Project.xcconfig` içindeki bundle kimliğini yerelde değiştirin. Telefon ve Mac aynı ağda olmalı; `API_BASE_URL=http://<MAC_LAN_IP>:8000/api/v1` kullanın, yerel ağ iznini verin. Mac güvenlik duvarında yalnız gerekli yerel ağ erişimini açın. Kişisel imzalama değişikliklerini commit etmeyin.

iOS kaynak kontrolleri Windows'ta çalıştırılabilir; Xcode derlemesi ve gerçek iPhone testleri Mac'te ayrıca doğrulanmalıdır. İmzalı dağıtım için [iOS yayın rehberi](ios_release_runbook.md).

## 4. İlk kullanım ve özellikleri deneme

- Uygulamada **Hesap Aç** ile kendi test hesabınızı oluşturun. Başka geliştiricinin yerel kullanıcıları veya veritabanı klonla gelmez.
- Türkçe ses ve mikrofon/kamera izinlerini cihazda hazırlayın. Emülatör ses davranışı gerçek telefon testi yerine geçmez.
- Ayarlar → **Cihaz Üstü Model** seçin; tarama ekranında galeriden yemek fotoğrafı seçin. Simülatöre fotoğrafı sürükleyip bırakabilirsiniz. Model sonucu kullanıcı onayı ister; kalori sorgulama ve kayıt için backend açık olmalı.
- Varsayılan dış görüntü sağlayıcısı kapalıdır. Sunucu kullanılamıyorsa uygulama cihaz üstü modele geçer. Google/Gemini kullanımı için yalnız `backend/.env` içinde sağlayıcı ayarı ve anahtarı gerekir; mobil uygulamaya anahtar yazmayın.
- E-posta Mailpit'e, SMS yerel test kutusuna gider; gerçek kişilere iletilmez. Diyetisyen test hesabını `sandbox-dietitian@nutrisense.invalid` adresiyle oluşturun veya `backend/.env` içindeki sandbox izin listesini kendi test adresinize göre ayarlayın; Compose'u yeniden başlatın. Hasta/diyetisyen eşleşmesini iki tarafta onaylayın.
- Yerel SMS kutusunu görmek: `docker compose -f backend/docker-compose.yml exec backend cat /tmp/sms_outbox.jsonl`. İlk SMS'ten önce dosyanın bulunmaması normaldir.

## 5. Güncelleme ve doğrulama

```sh
git pull --ff-only
flutter pub get
docker compose -f backend/docker-compose.yml up -d --build --wait
flutter test
python scripts/qa/ios_release_checks.py
```

iOS bağımlılıkları değiştiğinde `cd ios && pod install` çalıştırın. Backend testleri:

```sh
docker compose -f backend/docker-compose.yml --profile test run --rm test
```

Servisleri durdurmak: `docker compose -f backend/docker-compose.yml stop`. `down -v` yerel veritabanını siler; normal güncellemede kullanmayın.

## Ortak çalışma

Kendi dalınızda çalışın (`git switch -c feature/kisa-aciklama`), ilgili testleri çalıştırıp pull request açın. `.env`, API anahtarları, kişisel imzalar, `local.properties`, Pods/build klasörleri ve kullanıcı verileri Git'e eklenmez. `pubspec.lock`, kaynak kodu ve dağıtım modeli sürümlenir. Android yayın anahtarı geliştirme derlemesi için gerekli değildir.
