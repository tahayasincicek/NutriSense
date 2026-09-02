# NutriSense

Görme engelli bireyler için yapay zekâ destekli besin tanıma ve kalori takip
uygulaması. Kullanıcı yemeğinin fotoğrafını çeker, uygulama besini tanır,
kaloriyi sesli olarak bildirir ve onaylanan kayıtları diyetisyene iletir.

TÜBİTAK 2209-A kapsamında yürütülen bir araştırma projesidir.

> **Durum:** Geliştirme aşamasında. Uygulama uçtan uca çalışır durumdadır,
> fakat henüz eğitilmiş bir görüntü tanıma modeli yoktur ve gerçek
> kullanıcılarla saha testi yapılmamıştır. Ayrıntı için
> [Bilinen sınırlar](#bilinen-sınırlar).

## İçindekiler

- [Ne yapar](#ne-yapar)
- [Teknoloji](#teknoloji)
- [Çalıştırma](#çalıştırma)
- [Proje yapısı](#proje-yapısı)
- [Test](#test)
- [CI](#ci)
- [Gizlilik ve KVKK](#gizlilik-ve-kvkk)
- [Bilinen sınırlar](#bilinen-sınırlar)
- [Belgeler](#belgeler)

## Ne yapar

**Erişilebilirlik önce.** Arayüz görsel öğelere bağımlı olmadan kullanılabilir:
her ekran ekran okuyucuyla gezilebilir, sonuçlar sesli bildirilir ve sesli
komut desteklenir. Telefonu sallayarak da komut başlatılabilir — kullanıcının
ekranda düğme araması gerekmez.

**Besin tanıma.** Kamerayla çekilen fotoğraf analiz edilir, aday besinler
kullanıcıya okunur ve kayıt yalnız kullanıcı onayladıktan sonra oluşur.
Porsiyon miktarı sesli veya dokunmatik olarak ayarlanabilir.

**Sağlık takibi.** Su, adım, uyku, kilo ve ruh hâli kaydedilir; veriler
cihazda saklanır ve sunucuyla eşitlenir.

**Diyetisyen bağlantısı.** Hasta ve diyetisyen karşılıklı onayla eşleşir.
Hasta yalnız onayladığı diyetisyene rapor gönderebilir; diyetisyen raporu
yanıtlayabilir. Rapor e-posta veya SMS ile iletilir.

## Teknoloji

| Katman | Kullanılan |
|---|---|
| Mobil | Flutter (Dart SDK ≥ 3.2), Riverpod |
| Backend | FastAPI, SQLAlchemy, Alembic, Python 3.11 |
| Veritabanı | MySQL 8.4 |
| Görüntü tanıma | Google Vision veya Gemini (yapılandırmayla seçilir) |
| Çalışma ortamı | Docker Compose |

## Çalıştırma

Gereken: Docker Desktop, Flutter SDK, bir Android emülatörü.

### 1. Backend

```bash
docker compose -f backend/docker-compose.yml up -d
```

Bu komut üç servis başlatır: backend (`:8000`), MySQL ve e-postaları yakalayan
Mailpit (`:8025`). Hazır olduğunu doğrulamak için:

```bash
curl http://localhost:8000/health
```

`{"status":"ready", ...}` dönmelidir.

### 2. Mobil uygulama

Emülatörü açtıktan sonra:

```bash
flutter run --flavor dev --dart-define=APP_ENV=dev
```

`APP_ENV=dev` verildiğinde API adresi otomatik olarak `http://10.0.2.2:8000`
olur. Bu, emülatörün ana makineye baktığı özel adrestir; `localhost` yazmak
çalışmaz çünkü emülatör kendi içine bakar.

### Yararlı adresler

| Ne | Nerede |
|---|---|
| API dokümanı | http://localhost:8000/docs |
| Gönderilen e-postalar | http://localhost:8025 |
| Gönderilen SMS'ler | container içinde `/tmp/sms_outbox.jsonl` |

Veritabanı olarak yalnız Docker'daki MySQL kullanılır. Depoda
`backend/nutrisense_dev.db` dosyasını görürseniz o eski bir kalıntıdır ve
kullanılmaz.

## Proje yapısı

```
lib/                  Flutter uygulaması
  features/           Ekranlar: auth, food_scan, history, dietitian,
                      water_tracker, discover, settings, onboarding, survey
  shared/             Servisler, modeller, ortak bileşenler
  core/               Yapılandırma, tema, sabitler
backend/              FastAPI servisi, Alembic göçleri, testler
ml/                   Model eğitim hattı (CI tarafından doğrulanır)
analysis/             Araştırma verisi analiz hattı
contracts/            openapi.json — CI'da sapmaya karşı korunur
integration_test/     Emülatörde koşan uçtan uca test
docs/                 Mimari, gizlilik, erişilebilirlik ve denetim belgeleri
```

Not: `ai_model/` klasöründeki betikler geriye dönük uyumluluk giriş
noktalarıdır; kendileri iş yapmaz, `ml/` altındaki hattı çağırırlar. Yeni
çalışmalar doğrudan `ml/` üzerinden yürütülmelidir.

## Test

```bash
flutter test
```

```bash
docker compose -f backend/docker-compose.yml --profile test run --rm test
```

Sırasıyla 239 ve 128 test koşar. Backend testleri kendi geçici MySQL
örneğinde çalışır; geliştirme veritabanına dokunmaz.

Emülatörde koşan uçtan uca test:

```bash
flutter test integration_test/p0_fixture_journey_test.dart --flavor dev --dart-define=APP_ENV=dev
```

Bu test giriş → tarama onayı → geçmiş → rapor önizleme zincirini gerçek bir
Android emülatöründe doğrular.

## CI

Her push'ta 10 iş çalışır: Flutter ve backend testleri, Android emülatör
yolculuğu, güvenlik taramaları, ML kapıları, erişilebilirlik denetimi,
sentetik staging smoke testi, SBOM üretimi ve build kontrolü.

iOS derlemesi ayrıca durur ve yalnız elle tetiklenir (Actions → Run workflow),
çünkü macOS runner özel depoda 10 kat dakika harcar.

CI birkaç kapıyı zorunlu kılar: OpenAPI sözleşmesi koddan sapamaz, bağımlılık
kilitleri hash doğrulamalıdır ve iş akışında hata maskeleyen ifade
(`continue-on-error`, `|| true`) bulunamaz.

## Gizlilik ve KVKK

Uygulama sağlık verisi işler; KVKK m.6 uyarınca bu özel nitelikli veridir ve
açık rıza gerektirir. Rıza bir onay kutusu değil, uygulanan bir kapıdır:
`image_cross_border_transfer` rızası verilmemişse fotoğraf analiz uçları 403
döner ve görüntü yurt dışındaki sağlayıcıya gönderilmez.

Rızalar amaç bazlıdır, ayrı ayrı verilir ve geri alınabilir.

**Aydınlatma metni henüz yayımlanmamıştır** (`privacy_notice_version` değeri
`taslak-yayinlanmadi`). Uygulama gerçek kullanıcıya açılmadan önce metnin
yayımlanması ve VERBİS yükümlülüğünün değerlendirilmesi gerekir.

## Bilinen sınırlar

Bu bölüm bilerek açık yazılmıştır; projenin ne kanıtladığı ile neyi henüz
kanıtlamadığı karıştırılmamalıdır.

- **Eğitilmiş model yok.** `ml/MODEL_CARD.md` durumu `NOT RUN` olarak
  bildirir. Besin tanıma tümüyle dış sağlayıcıya (Google Vision / Gemini)
  dayanır. Hiçbir başarım metriği üretilmemiştir.
- **Saha testi yapılmadı.** Etik kurul kararı beklenmektedir. Depodaki tüm
  veriler sentetiktir; `analysis/` hattı gerçek veri olmadığını
  `NO-REAL-DATA` çalıştırma kimliğiyle bildirir.
- **SMS gerçek operatöre çıkmaz.** Geliştirme ortamı `SMS_PROVIDER_MODE`
  değerini `local_outbox` yapar; bu, e-posta tarafındaki Mailpit'in
  karşılığıdır: mesaj üretilir ve dosyaya kaydedilir ama telefona ulaşmaz.
  Gerçek teslimat için Twilio kimlikleri gerekir. Bu mod staging ve
  production'da bilerek reddedilir.
- **iOS imzalanmadı.** Kaynak macOS runner'da derlenmektedir, fakat imzalı
  arşiv, TestFlight dağıtımı ve gerçek cihazda VoiceOver kanıtı yoktur.

## Belgeler

`docs/` altında; başlıcaları:

| Belge | İçerik |
|---|---|
| `api_contract.md` | İstemci–backend sözleşmesi |
| `backend_data_architecture.md` | Veri modeli |
| `data_processing_inventory.md` | KVKK veri işleme envanteri |
| `privacy_notice_draft.md` | Aydınlatma metni taslağı |
| `accessibility_conformance_report.md` | Erişilebilirlik uygunluğu |
| `manual_screen_reader_test_plan.md` | TalkBack/VoiceOver test planı |
| `audit/tubitak_requirement_reaudit_2026-09.md` | Güncel gereksinim denetimi |
| `deployment_runbook.md` | Dağıtım adımları |
