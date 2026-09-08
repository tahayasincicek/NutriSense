# NutriSense

**Görme engelli bireyler için sesli beslenme takibi.**

NutriSense; kamera veya galeriden besin tanıma, porsiyon ve kalori takibi, sesli komutlar ve diyetisyenle rapor paylaşımı sunan bir Flutter uygulamasıdır. Besin kayıtları kullanıcı onayından sonra oluşturulur.

TÜBİTAK 2209-A kapsamında Kocaeli Üniversitesi'nde geliştirilmektedir.

## Neler yapabilirsiniz?

- Kamera veya galeriden fotoğraf seçerek besin tanıma.
- Manuel besin girişi, porsiyon seçimi ve günlük kalori takibi.
- Sesli komutlarla işlem yapma ve besin bilgilerini dinleme.
- Sık tüketilen besinleri tekrar ekleme ve son işlemi geri alma.
- Diyetisyenle eşleşme, rapor paylaşma ve yanıtları görüntüleme.
- Su, adım, kilo, uyku ve ruh hâli kaydı.

## Başlamadan önce

Projenin iki parçası var: telefonda çalışan **Flutter uygulaması** ve bilgisayarda Docker ile çalışan **backend**. Hesap, besin değerleri ve kayıt işlemleri için backend açık olmalı.

**Model depoda hazır gelir; uygulamayı kullanmak için eğitim yapmanız veya API anahtarı almanız gerekmez.**

| Ortak araçlar | Android için ayrıca | iOS için ayrıca |
|---|---|---|
| Git, Flutter **3.41.4**, Python **3.11+**, Docker Desktop | Android Studio ve emülatör veya Android telefon | **Mac**, Xcode, CocoaPods ve simülatör veya iPhone |

Docker Desktop'ı açın. Flutter kurulumunu `flutter doctor -v` ile kontrol edin.

## 1. Projeyi indirin

```sh
git clone https://github.com/tahayasincicek/NutriSense.git
cd NutriSense
```

Bundan sonraki komutları, aksi belirtilmedikçe **bu klasörde** çalıştırın.

## 2. Backend'i hazırlayın

Yerel ayar dosyasını oluşturun.

**Windows:**

```powershell
py -3 scripts/dev_setup.py
```

**macOS / Linux:**

```sh
python3 scripts/dev_setup.py
```

Bu betik `backend/.env` dosyasını oluşturur ve gerekli parolaları üretir. Mevcut dosyanın üzerine yazmaz.

Ardından servisleri başlatın ve mobil bağımlılıkları yükleyin:

```sh
docker compose -f backend/docker-compose.yml up -d --build --wait
flutter pub get
```

İlk kurulum indirmeler nedeniyle zaman alabilir. Komut bitince [backend hazırlık kontrolünü](http://localhost:8000/health/ready) tarayıcıda açın. Sonra aşağıdan kendi platformunuzu seçin.

## 3. Uygulamayı çalıştırın

### Android emülatörü

Android Studio'dan emülatörü açın:

```sh
flutter run --flavor dev --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

### USB ile Android telefon

Telefonda USB hata ayıklamayı açın, USB kablosuyla bağlayın ve telefondaki bağlantı iznini onaylayın. Tek cihaz bağlıyken:

```sh
adb reverse tcp:8000 tcp:8000
flutter run --flavor dev --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

### iOS simülatörü — yalnız Mac

Önce yukarıdaki ortak kurulumu tamamlayın. Ardından:

```sh
cd ios
pod install
cd ..
open -a Simulator
flutter run --debug --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

iOS komutlarında `--flavor dev` kullanmayın.

**Gerçek iPhone için:** Xcode'da imzalama takımı seçilmeli ve API adresinde Mac'in yerel ağ IP'si kullanılmalı. [iPhone kurulum adımları](docs/developer_setup.md#3-ios).

> iOS için CI imzasız derlemesi geçti. İmzalı dağıtım ve gerçek iPhone doğrulaması henüz tamamlanmamıştır. [Doğrulama kaydı](docs/ios_release_runbook.md).

Birden fazla cihaz bağlıysa `flutter devices` ile cihaz kimliğini bulun ve çalıştırma komutuna `-d CIHAZ_KIMLIGI` ekleyin.

## 4. İlk denemenizi yapın

1. Uygulamada **Hesap Aç** bölümünden kendi hesabınızı oluşturun. Yeni kurulum boş veritabanıyla başlar.
2. **Ayarlar → Cihaz Üstü Model** seçeneğini açın.
3. Tarama ekranında **Galeriden fotoğraf seç** ile bir yemek fotoğrafı seçin. Gerçek telefonda kamerayı da kullanabilirsiniz.
4. Tanınan besini ve porsiyonu kontrol edip onaylayın.
5. Kaydınızı günlük ekranından görüntüleyin.

Cihaz üstü model fotoğrafı telefonda analiz eder. Besin değerlerini alma ve kayıt işlemleri için backend bağlantısı gerekir.

**E-posta ve SMS bu kurulumda test amaçlıdır.** Gerçek alıcılara gönderilmez: e-postalar Mailpit'te, SMS'ler backend'in yerel test kutusunda görüntülenir. Diyetisyen ve rapor testi için [geliştirici rehberine](docs/developer_setup.md) bakın.

## Yararlı adresler

Backend açıkken bilgisayarınızın tarayıcısından erişebilirsiniz:

| Adres | Ne için? |
|---|---|
| [Hazırlık kontrolü](http://localhost:8000/health/ready) | Backend çalışıyor mu? |
| [API dokümanı](http://localhost:8000/docs) | Sunucu uçlarını incelemek |
| [Mailpit](http://localhost:8025) | Test e-postalarını görmek |

## Sorun yaşarsanız

| Sorun | İlk kontrol |
|---|---|
| Sunucuya bağlanılamıyor | Docker açık mı? Hazırlık kontrolü yanıt veriyor mu? Platformunuza uygun komutu kullandınız mı? |
| Cihaz bulunamadı | Emülatörü/simülatörü açın veya USB bağlantısını kontrol edin; `flutter devices` çalıştırın. |
| Android APK bulunamadı | Derleme komutuna `--flavor dev` ekleyin. |
| iOS scheme/flavor hatası | Komuttan `--flavor dev` parametresini kaldırın. |
| Fotoğraf tanınmadı | Daha net fotoğraf seçin veya manuel besin girişini kullanın. |

SDK/NDK sürümleri, APK oluşturma, fiziksel cihaz bağlantısı ve güncelleme adımları: **[Ayrıntılı geliştirici rehberi](docs/developer_setup.md)**.

## Geliştiriciler için

| Klasör | İçerik |
|---|---|
| `lib/` | Flutter ekranları ve uygulama mantığı |
| `backend/` | FastAPI sunucusu ve veritabanı işlemleri |
| `assets/models/` | Hazır TFLite modeli ve etiketler |
| `test/`, `integration_test/` | Mobil testler |
| `ml/` | Model eğitimi ve değerlendirme |
| `analysis/` | Araştırma analizleri |
| `docs/` | Teknik belgeler ve rehberler |

Mobil testleri:

```sh
flutter test
```

Backend testleri:

```sh
docker compose -f backend/docker-compose.yml --profile test run --rm test
```

Kendi dalınızda çalışıp pull request açın. `.env`, kişisel imzalama dosyaları ve kullanıcı verilerini Git'e eklemeyin.

## Belgeler

- [Android ve iOS geliştirici rehberi](docs/developer_setup.md)
- [iOS devir notu](docs/ios_devir_notu.md)
- [Kullanıcı el kitabı](docs/kullanici_el_kitabi.md)
- [Besin değerlerinin kaynakları](docs/nutrition_data_methodology.md)
- [Model kartı](ml/MODEL_CARD.md) · [Veri ve lisans bilgileri](ml/LICENSES.md)
- [Erişilebilirlik doğrulama durumu](docs/accessibility_conformance_report.md)
- [Android yayın rehberi](docs/android_release_runbook.md) · [iOS yayın rehberi](docs/ios_release_runbook.md)
- [TÜBİTAK sonuç raporu](docs/tubitak_sonuc_raporu.md) · [Makale taslağı](docs/akademik_makale_taslak.md)

Model eğitimindeki Food-101 ve Türk mutfağı veri kaynaklarının kullanım koşulları lisans belgesindedir. Besin kataloğu USDA FoodData Central verilerini ve tahmini olduğu belirtilen kayıtları içerir.
