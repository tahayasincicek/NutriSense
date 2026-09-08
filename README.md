# NutriSense

**Görme engelli bireyler için yapay zekâ destekli besin tanıma ve kalori takip uygulaması.**

Kullanıcı yemeğinin fotoğrafını çeker; uygulama besini tanır, kaloriyi sesli
olarak bildirir, kullanıcı onayladıktan sonra kaydeder ve raporu diyetisyenine
iletir. Tüm akış ekrana bakmadan tamamlanabilir.

TÜBİTAK 2209-A kapsamında Kocaeli Üniversitesi'nde yürütülmektedir.

---

## Öne çıkanlar

**Ekranı görmeden tam kullanım.** Her ekran ekran okuyucuyla gezilebilir,
sonuçlar sesli bildirilir, sesli komut desteklenir. Telefonu sallamak komut
dinlemeyi başlatır — kullanıcının ekranda düğme araması gerekmez. Erişilebilirlik
her push'ta ayrı bir CI işiyle denetlenir.

**Onaya dayalı kayıt.** Model bir tahmin üretir, kullanıcı duyar ve onaylar;
kayıt ancak ondan sonra oluşur. Emin olunmayan tahminler sessizce kaydedilmez,
kullanıcıya sorulur.

**Kendi görüntü tanıma modeli.** `ml/` altında sızıntıya dirençli, yeniden
üretilebilir bir eğitim hattı bulunur: sürümlenmiş veri manifesti, gruplara göre
bölme, iki aşamalı transfer öğrenme, mühürlü test kümesi ve TFLite dönüşümü.
Test verisi bir kez açılır ve deney yeniden test edilemez; sonuç seçilerek
iyileştirilemez. Güncel kapsam `ml/configs/tr222_v1.json` içinde 221 sınıftır;
bunların yaklaşık 90'ı Türk mutfağıdır.

**Karşılıklı onaylı diyetisyen bağlantısı.** Eşleşme iki tarafın da onayını
gerektirir. Hasta yalnız onayladığı diyetisyene rapor gönderebilir, dilediğinde
bağlantıyı sonlandırabilir. Diyetisyen raporu yanıtlayabilir.

**Sağlık takibi.** Su, adım, uyku, kilo ve ruh hâli kaydedilir; veriler cihazda
saklanır ve sunucuyla eşitlenir.

**Araştırma verisi kendi hattında.** Uygulama içindeki anket ve kullanılabilirlik
ölçümleri araştırma rızasına bağlıdır; rıza geri alınabilir ve geri alındığında
kayıt dışarı aktarımdan düşer. `analysis/` altında önceden yazılmış analiz planı,
veri sözlüğü ve nitel kodlama kitabıyla yeniden üretilebilir bir HCI analiz hattı
bulunur. Hat hazırdır ancak **henüz gerçek veri işlenmemiştir**; depoda bilimsel
sonuç iddiası yoktur.

**Kaynağı belli besin değerleri.** Uygulama kaloriyi tahmin etmez; 500
kayıtlık yerel katalogdan okur. Kayıtların 488'i USDA FoodData Central FNDDS
(CC0) arşivinden birebir çıkarılmıştır ve arşiv SHA-256 ile sabitlenmiştir.
Kaynağı olmayan 12 Türk yemeği `ESTIMATED` olarak işaretlidir ve hangi
kaynaklardan ortalandığı kayıtlıdır. Porsiyon gram/adet/dilim/kase/ml/litre
olarak girilebilir; hacim birimleri yoğunluk üzerinden çevrilir, 1 ml = 1 g
varsayılmaz. Ayrıntı: `docs/nutrition_data_methodology.md`.

## Teknoloji

| Katman | Kullanılan |
|---|---|
| Mobil | Flutter (Dart SDK ≥ 3.2), Riverpod |
| Backend | FastAPI, SQLAlchemy, Alembic, Python 3.11 |
| Veritabanı | MySQL 8.4 |
| Model | TensorFlow 2.18, MobileNetV3Small, TFLite |
| Görüntü servisi | Google Vision veya Gemini (yapılandırmayla seçilir) |
| Çalışma ortamı | Docker Compose |

## Çalıştırma

Gereken: Docker Desktop, Flutter SDK, bir Android emülatörü.

### Backend

```bash
docker compose -f backend/docker-compose.yml up -d
```

Üç servis başlar: backend (`:8000`), MySQL ve e-postaları yakalayan Mailpit
(`:8025`). Hazır olduğunu doğrulamak için:

```bash
curl http://localhost:8000/health
```

### Mobil uygulama

Emülatörü açtıktan sonra:

```bash
flutter run --flavor dev --dart-define=APP_ENV=dev
```

`APP_ENV=dev` verildiğinde API adresi otomatik olarak `http://10.0.2.2:8000`
olur. Bu, emülatörün ana makineye baktığı adrestir; `localhost` yazmak çalışmaz
çünkü emülatör kendi içine bakar.

### Yararlı adresler

| Ne | Nerede |
|---|---|
| API dokümanı | http://localhost:8000/docs |
| Gönderilen e-postalar | http://localhost:8025 |

## Proje yapısı

```
lib/                  Flutter uygulaması
  features/           auth, food_scan, history, dietitian, water_tracker,
                      discover, settings, onboarding, survey
  shared/             Servisler, modeller, ortak bileşenler
  core/               Yapılandırma, tema, sabitler
backend/              FastAPI servisi, Alembic göçleri, testler
ml/                   Model eğitim hattı
analysis/             Araştırma verisi analiz hattı
contracts/            openapi.json — CI'da sapmaya karşı korunur
integration_test/     Emülatörde koşan uçtan uca test
docs/                 Mimari, gizlilik, erişilebilirlik belgeleri
```

`ai_model/` altındaki betikler geriye dönük uyumluluk giriş noktalarıdır ve
`ml/` hattını çağırır; yeni çalışmalar doğrudan `ml/` üzerinden yürütülür.

## Model eğitimi

```bash
cd ml
python -m nutrisense_ml.manifest --intake data/intake.csv --data-root data/raw \
  --config configs/<config>.json --licenses sources/licenses.json \
  --output data/versions/<sürüm>/manifest.csv

python -m nutrisense_ml.train --config configs/<config>.json \
  --manifest data/versions/<sürüm>/manifest.csv --data-root data/raw --runs-dir runs

python -m nutrisense_ml.evaluate --run runs/<DENEY_ID> --data-root data/raw --split validation
python -m nutrisense_ml.evaluate --run runs/<DENEY_ID> --data-root data/raw --split test

python -m nutrisense_ml.convert --run runs/<DENEY_ID> --data-root data/raw \
  --output artifacts/<DENEY_ID> --formats float32 float16 int8
```

Manifest adımı lisansı onaylanmamış kaynağı reddeder, bozuk görselleri raporlar
ve sınıf/grup yeterlilik kapılarını uygular. Eşik yalnız doğrulama kümesinden
seçilir; test kümesi tek kullanımlıktır.

## Araştırma analizi

Anket ve kullanılabilirlik verisi uygulamadan tidy CSV olarak dışa aktarılır
(`/survey/export/tidy`, `/usability/export/tidy`); yalnız araştırma rızası veren
ve rızasını geri almamış katılımcılar bu çıktıya girer.

```bash
python analysis/run_analysis.py
```

Analiz planı veri görülmeden yazılmıştır (`analysis/PRE_ANALYSIS_PLAN.md`).
Depoda gerçek katılımcı verisi bulunmaz; hat çalıştırılabilir durumdadır ancak
şu an bilimsel bir sonuç üretmemiştir.

## Test

```bash
flutter test
```

```bash
docker compose -f backend/docker-compose.yml --profile test run --rm test
```

Sırasıyla 289 ve 232 test koşar. Backend testleri kendi geçici MySQL örneğinde
çalışır, geliştirme veritabanına dokunmaz.

Emülatörde uçtan uca yolculuk:

```bash
flutter test integration_test/p0_fixture_journey_test.dart --flavor dev --dart-define=APP_ENV=dev
```

Bu test giriş → tarama onayı → geçmiş → rapor önizleme zincirini gerçek bir
Android emülatöründe doğrular.

## CI

Her push'ta 10 iş çalışır: Flutter ve backend testleri, Android emülatör
yolculuğu, güvenlik taramaları, ML kapıları, erişilebilirlik denetimi, sentetik
staging smoke testi, SBOM üretimi ve build kontrolü. iOS derlemesi elle
tetiklenir.

CI birkaç kuralı zorunlu kılar:

- OpenAPI sözleşmesi koddan sapamaz
- Bağımlılık kilitleri hash doğrulamalıdır
- İş akışında hata maskeleyen ifade (`continue-on-error`, `|| true`) bulunamaz
- Konteyner imajı kök dosya sistemine yazamaz ve tüm Linux capability'leri kapalıdır

## Gizlilik

Uygulama sağlık verisi işler; KVKK m.6 uyarınca bu özel nitelikli veridir ve
açık rıza gerektirir. Rıza burada bir onay kutusu değil, uygulanan bir kapıdır:
`image_cross_border_transfer` rızası verilmemişse fotoğraf analiz uçları 403
döner ve görüntü yurt dışındaki sağlayıcıya gönderilmez.

Rızalar amaç bazlıdır, ayrı ayrı verilir ve istendiğinde geri alınabilir. Veri
işleme envanteri `docs/data_processing_inventory.md` altında sürümlenir.

## Belgeler

**Akademik çıktılar**

| Belge | İçerik |
|---|---|
| `docs/tubitak_sonuc_raporu.md` | TÜBİTAK 2209-A sonuç raporu |
| `docs/akademik_makale_taslak.md` | Akademik makale taslağı |
| `analysis/PRE_ANALYSIS_PLAN.md` | Önceden kayıtlı analiz planı |
| `analysis/DATA_DICTIONARY.md` | Değişken sözlüğü |
| `analysis/QUALITATIVE_CODEBOOK.md` | Nitel kodlama kitabı |
| `ml/MODEL_CARD.md` | Model kartı |
| `ml/DATA_CARD.md` | Veri kartı |

**Mimari ve teknik**

| Belge | İçerik |
|---|---|
| `docs/api_contract.md` | İstemci–backend sözleşmesi |
| `docs/backend_data_architecture.md` | Veri modeli |
| `docs/camera_food_scan_pipeline.md` | Kamera tarama akışı |
| `docs/food_history_architecture.md` | Geçmiş ekranı mimarisi |
| `docs/auth_and_dietitian_lifecycle.md` | Kimlik ve diyetisyen yaşam döngüsü |
| `docs/dietitian_report_delivery.md` | Rapor iletimi |
| `docs/nutrition_data_methodology.md` | Besin verisi yöntemi |
| `docs/adr/` | Mimari karar kayıtları |

**Hukuk, etik ve güvenlik**

| Belge | İçerik |
|---|---|
| `docs/etik_kvkk_belgeleri.md` | Etik kurul ve KVKK belgeleri |
| `docs/data_processing_inventory.md` | KVKK veri işleme envanteri |
| `docs/data_collection_protocol.md` | Katılımcı veri toplama protokolü |
| `docs/privacy_notice_draft.md` | Aydınlatma metni taslağı |
| `docs/threat_model.md` | Tehdit modeli |
| `docs/security_findings_register.md` | Güvenlik bulgu kaydı |
| `ml/LICENSES.md` | Veri ve yazılım kaynak envanteri |

**Erişilebilirlik ve test**

| Belge | İçerik |
|---|---|
| `docs/accessibility_conformance_report.md` | Erişilebilirlik uygunluğu |
| `docs/manual_screen_reader_test_plan.md` | TalkBack/VoiceOver test planı |
| `docs/voiceover_manual_test_report.md` | VoiceOver elle test raporu |
| `docs/test_strategy.md` | Test stratejisi |
| `docs/requirements_test_matrix.md` | Gereksinim–test izlenebilirliği |
| `docs/android_device_acceptance_report.md` | Gerçek cihaz kabul raporu |

**Yayın ve işletme**

| Belge | İçerik |
|---|---|
| `docs/deployment_runbook.md` | Dağıtım adımları |
| `docs/operations_runbook.md` | İşletme el kitabı |
| `docs/android_release_runbook.md` | Android yayın adımları |
| `docs/ios_release_runbook.md` | iOS yayın adımları |
| `docs/ios_devir_notu.md` | Mac'te ilk çalıştırma ve devir notu |
| `docs/backup_restore_plan.md` | Yedekleme ve geri dönüş planı |
| `docs/environment_matrix.md` | Ortam matrisi |
| `docs/play_store_listing_tr.md` | Play Store metni |
| `docs/play_store_data_safety_draft.md` | Play Store veri güvenliği formu |
| `docs/app_store_listing_tr.md` | App Store metni |
| `docs/kullanici_el_kitabi.md` | Kullanıcı el kitabı |

## Atıf

Model eğitiminde Food-101 veri kümesi kullanılmıştır:

> Bossard, L., Guillaumin, M., Van Gool, L. (2014). *Food-101 – Mining
> Discriminative Components with Random Forests.* ECCV.

Türk mutfağı sınıfları için ek olarak `alpsahin/Turkish-Food-Dataset-Combined`
kullanılmıştır. Bu veri kümesinin kartında lisans beyanı yoktur; şartları
bilinmediği için görseller yalnız yerelde tutulur, yeniden dağıtılmaz. Durum
`ml/sources/licenses.json` içinde açıkça kayıtlıdır.

Besin değerleri USDA FoodData Central, FNDDS 2021-2023 (CC0) kaynaklıdır.
