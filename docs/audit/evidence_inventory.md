# Doğrulanabilir Kanıt Envanteri

**Denetim tarihi:** 17 Temmuz 2026  
**Kök:** `C:\Users\TAHA\Desktop\2209\nutrisense`  
**Kural:** “Var” yalnız fiziksel artefaktın bulunduğunu gösterir; artefaktın doğru, güncel veya kabul edilmiş olduğunu ayrıca kanıtlamaz.

> **Snapshot notu:** Ana tablolar ilk denetim anını korur. 18 Temmuz 2026 kamera güvenlik uygulaması sonrasında güncel yürütme kanıtı: backend **31/31**, Flutter **97/97** test geçti; OpenAPI drift kontrolü ve debug APK build başarılıdır. Fiziksel cihaz E2E/latency hâlâ **NOT RUN**, gerçek TFLite model hâlâ **YOK**. Ayrıntı: `docs/camera_food_scan_pipeline.md`.

## Hızlı sonuç

| Sınıf | Var | Kısmi | Yok | Kritik yorum |
|---|---:|---:|---:|---|
| Dağıtım/build | 1 | 0 | 4 | Yalnız eski debug APK var; release/AAB/IPA/provenance yok. |
| YZ/veri | 1 | 1 | 9 | Kalori JSON’u ve pipeline kodu var; veri seti/model/checkpoint/metrik yok. |
| Test/CI | 2 | 1 | 6 | Test kaynakları ve CI YAML var; çalışan rapor yok, test komutu başlamıyor. |
| Araştırma/etik | 2 | 1 | 11 | Taslak rapor ve taslak formlar var; etik karar, ham veri, onam ve analiz yok. |
| Dış servis | 1 | 1 | 5 | Servis kodu ve SMTP yapılandırma durumu var; teslimat/sandbox kanıtı yok. |
| Yeniden üretim/yönetişim | 1 | 1 | 7 | Bağımlılık tanımları var; README, SBOM, migrasyon ve sürüm provenance yetersiz. |

## 1. Dağıtım ve platform artefaktları

| Beklenen artefakt | Durum | Konum/kanıt | Bütünlük/provenance | Sonuç |
|---|---|---|---|---|
| Android debug APK | **Var** | `build/app/outputs/apk/debug/app-debug.apk` ve `build/app/outputs/flutter-apk/app-debug.apk` | İki dosya aynı: 105.549.983 bayt, 19.03.2026 20:26, SHA-256 `48DF4778FA351F51AC5303676E978ACBEE8E09326409580E897B019484ED8619`. Commit/build logu yok. | Mevcut kaynakla üretildiği kanıtlanmadığı için beta/release kabul kanıtı değildir. |
| Android release APK | **Yok** | `build/` taramasında bulunmadı | — | Release dağıtımı kanıtsız. |
| Android App Bundle (`.aab`) | **Yok** | Proje taramasında bulunmadı | — | Play Store teslimi yok. |
| iOS kaynak/Xcode projesi | **Var; kaynak hazırlığı** | `ios/`, plist, Podfile, release guard | Windows statik kontrolü | Xcode derleme kanıtı değildir. |
| iOS IPA/TestFlight build’i | **Yok** | `.ipa` yok | — | VoiceOver ve iOS dağıtım kanıtı yok. |
| Store yayını | **Kısmi** | `docs/play_store_listing_tr.md`, `docs/app_store_listing_tr.md` | Yalnız metin taslakları; URL/sürüm/yayın kimliği yok. | Yayın gerçekleşmiş sayılamaz. |
| Android imzalama/ürün kimliği | **Yetersiz** | `android/app/build.gradle.kts:25,35-38` | `com.example.nutrisense`; release debug key kullanıyor. | Güvenli release artefaktı üretilemez. |
| Android release izin manifesti | **Yok** | `android/app/src/main/AndroidManifest.xml` | `uses-permission` yok; INTERNET yalnız debug/profile manifestlerinde. | Kamera, mikrofon ve ağ işlevleri release’de kabul edilmemeli. |

## 2. Yapay zekâ, model ve veri artefaktları

| Beklenen artefakt | Durum | Konum/kanıt | Gerekli ek kanıt | Sonuç |
|---|---|---|---|---|
| Veri hazırlama kodu | **Var** | `ai_model/01_data_preparation.py` | Kilitli ortam ve gerçek run logu | Kod, veri setinin üretildiğini kanıtlamaz. |
| Etiketli ham veri seti | **Yok** | `raw_datasets/`, görüntü manifesti veya arşiv yok | Kaynak, lisans, checksum, sınıf listesi | Eğitim yapılmış sayılamaz. |
| Birleştirilmiş/split veri seti | **Yok** | `merged_dataset`, train/val/test manifestleri yok | Örneğe göre split, sızıntı kontrolü | Metrik üretilemez. |
| Veri seti yapılandırması | **Var; çalıştırılmadı** | `ml/configs/mvp_v1.json` | Onaylı gerçek manifest ve veri sürümü | 10 sınıflı kapsam, seed, group split hedefleri ve güvenlik eşiği sürümlüdür; veri kanıtı değildir. |
| Eğitim kodu | **Var; çalıştırılmadı** | `ml/src/nutrisense_ml/train.py`; `ml/requirements.lock`; `ml/README.md` | Gerçek deney kimliği, checkpoint ve metrik | Test splitini eğitimden ayıran deterministik hat vardır; model başarısı henüz yoktur. |
| Keras model | **Yok** | `.keras`/`.h5` bulunmadı | Model checksum ve model card | “MobileNetV3 tamamlandı” iddiası desteklenmiyor. |
| Checkpoint | **Yok** | `.ckpt`/`best_model_*.keras` yok | Run kimliği, epoch, val metriği | En iyi model seçimi doğrulanamaz. |
| TFLite mobil model | **Yok** | `assets/models/` yalnız `.gitkeep`; `.tflite` yok | Dönüşüm logu, quantization raporu | Cihazda yerel YZ çıkarımı yok. |
| ONNX/PB model | **Yok** | `.onnx`/`.pb` yok | — | Alternatif model artefaktı yok. |
| Model eğitim geçmişi/metrik JSON | **NOT RUN şablonu var** | `ml/runs/NOT_RUN/metrics.json` | Gerçek run altındaki history/metrics/grafikler | Alanların `null` olması kasıtlıdır; başarı metrikleri hâlâ doğrulanamaz. |
| Eğitim grafiği | **Yok** | Kodun hedeflediği `training_results.png` yok | Üretim komutu ve kaynak run | Grafik üretilmemiş. |
| Confusion matrix | **Yok** | Kodun hedeflediği `confusion_matrix.png` yok | Etiket sırası ve sayımlar | Sınıf bazlı performans bilinmiyor. |
| Model benchmark raporu | **Yok** | TFLite latency/boyut raporu yok | Cihaz modeli, tekrar sayısı, P50/P95 | “Hızlı” iddiası desteklenmiyor. |
| Kalori veritabanı | **Var** | `ai_model/calorie_database.json` | Kaynak, sürüm, güncelleme tarihi, uzman doğrulaması | Fallback verisi var; bilimsel doğruluğu kanıtsız. |
| Model dönüştürme kodu | **Var; çalıştırılmadı** | `ml/src/nutrisense_ml/convert.py`; `ai_model/04_model_converter.py` | Gerçek eğitilmiş modelle dönüşüm/eşdeğerlik raporu | Demo ve rastgele kalibrasyon fallback’i kaldırıldı; model/validation kararı/gerçek kalibrasyon yoksa komut kapanır. |
| Model card | **Yok** | Bulunmadı | Amaç, veri, metrik, sınırlama, etik risk | Model yönetişimi eksik. |

## 3. Test ve CI artefaktları

| Beklenen artefakt | Durum | Konum/kanıt | Çalıştırma sonucu | Sonuç |
|---|---|---|---|---|
| Flutter unit test kaynakları | **Var** | `test/unit/` altında 3 dosya | `flutter test test/unit` bağımlılık çözümünde durdu: SDK `intl 0.19.0` isterken proje `intl 0.20.2` istiyor. | Hiçbir test bu turda çalışmadı. |
| Flutter widget test kaynakları | **Var** | `test/widget/` ve `test/widget_test.dart` | Analiz hataları var; varsayılan test olmayan `MyApp`/Counter kullanıyor. | Paket, gerçek ürün güvencesi sağlamıyor. |
| Üretim geçmiş ekranı widget testi | **Yok** | `food_history_screen_test.dart` yalnız tema import edip kendi mock widget’ını kuruyor | `_buildMockFoodTile` test ediliyor. | Gerçek geçmiş ekranı sınanmıyor. |
| Üretim kamera ekranı entegrasyon testi | **Yok** | Kamera testinde gerçek backend sözleşmesini doğrulayan test yok | — | Kamera contract hatası testte yakalanmıyor. |
| Backend proje testleri | **Yok** | `venv` dışı `test_*.py` / `*_test.py` yok | CI’daki pytest hatası `|| echo` ile maskeleniyor. | Backend için otomatik güvence yok. |
| Flutter analiz raporu | **Kısmi** | Yerel komut çıktısı | `dart analyze`: exit 1, 106 issue, 13 error. | Kaynak analyzer-clean değil. |
| Test sonucu (`junit`, pytest, Flutter JSON) | **Yok** | Proje taramasında bulunmadı | — | Geçmiş test başarısı doğrulanamaz. |
| Coverage raporu | **Yok** | `coverage/` veya LCOV artefaktı yok | CI komutu tanımlı ama sonuç yok. | Kapsam bilinmiyor. |
| CI iş akışı tanımı | **Var** | `.github/workflows/ci.yml` | Flutter/pytest/debug build adımları yazılı. | Tanım, başarılı CI çalışması değildir. |
| CI başarılı çalışma kanıtı | **Yok** | Badge, run URL, log veya indirilebilir artefakt yok | Projede `.git` de yok. | CI sonucu doğrulanamaz. |
| Python sözdizimi kontrolü | **Var — bu denetimde üretildi** | 21 proje Python dosyası `ast.parse` ile okundu | `AST_OK` | Yalnız sözdizimi kanıtıdır; import, DB ve servis davranışı kanıtı değildir. |

## 4. Araştırma, etik ve analiz artefaktları

| Beklenen artefakt | Durum | Konum/kanıt | Araştırma bütünlüğü değerlendirmesi |
|---|---|---|---|
| TÜBİTAK kaynak proje PDF’i | **Var** | Workspace kökü; 10 sayfa; SHA-256 `9C9F1E4A577C0B84F9574FCF25BADCD2AC29AABFC09AE06CE9F80EED12F75BC3` | Taahhütlerin birincil denetim kaynağıdır. |
| Sonuç raporu taslağı | **Var** | `docs/tubitak_sonuc_raporu.md` | Ham veri olmadığı için sonuç kanıtı değil; nicel iddialar karantinaya alınmalıdır. |
| Akademik makale taslağı | **Var** | `docs/akademik_makale_taslak.md` | Aynı doğrulanmamış sayıları tekrar ediyor; yayın için kullanılamaz. |
| Etik kurul başvuru taslağı | **Kısmi** | `docs/etik_kvkk_belgeleri.md` | Liste/şablon var; resmi başvuru/karar yok. |
| Etik kurul kararı | **Yok** | Tarih, kurul, karar numarası içeren dosya yok | Etik onay verilmiş sayılamaz. |
| Kurum izni | **Yok** | Engelli kuruluşu/kurum izin yazısı yok | Saha erişimi yetkilendirilmiş değildir. |
| Aydınlatılmış onam şablonu | **Var** | `docs/etik_kvkk_belgeleri.md` | Taslak; katılımcı onamı değildir. “Ses kaydı yapılmaz” ile “sesli onam kaydedilebilir” ifadeleri uzlaştırılmalı. |
| İmzalı/sesli onam kayıtları | **Yok** | Katılımcı referansı veya güvenli kayıt envanteri yok | Katılım kanıtı yok. |
| Anket ham verisi | **Yok** | `backend/data/survey_responses.json` ve dışa aktarım yok | Frekans/yüzde iddiaları doğrulanamaz. |
| Kullanılabilirlik ham verisi | **Yok** | `backend/data/usability_sessions.json` ve dışa aktarım yok | 20 katılımcı/görev süreleri doğrulanamaz. |
| Veri sözlüğü | **Yok** | Değişken kodlama belgesi yok | Analiz yeniden üretilemez. |
| Örneklem/katılımcı akış şeması | **Yok** | Davet, dışlama, tamamlayan sayıları yok | n=20 iddiası izlenemez. |
| Analiz notebook’u | **Yok** | `.ipynb` yok | İstatistikler yeniden üretilemez. |
| SPSS veri/syntax | **Yok** | `.sav/.sps` yok | PDF’deki SPSS yöntemi kanıtsız. |
| Excel veri/analiz | **Yok** | `.xlsx/.xls/.csv` yok | PDF’deki Excel yöntemi kanıtsız. |
| R/Python istatistik betiği | **Yok** | Araştırma sonuçlarını üreten betik yok | AI model kodu istatistik analiz betiği değildir. |
| İstatistik çıktı dosyası | **Yok** | Test tablosu/log/HTML/PDF yok | U, p ve Cohen’s d değerleri doğrulanamaz. |
| Araştırma grafikleri | **Yok** | Ham veriden üretilmiş grafik yok | Rapor tabloları kaynak veriye bağlı değildir. |
| Nitel veri/kodlama kitabı | **Yok** | Anonim not/transkript, kod ve tema matrisi yok | Katılımcı alıntıları/temaları doğrulanamaz. |
| Protokol ve analiz ön-kaydı | **Yok** | Sürüm/tarih damgalı protokol yok | Sonuca göre yöntem seçimi riski vardır. |

## 5. Dış servis ve entegrasyon kanıtları

| Servis/artefakt | Yapılandırma durumu | Runtime/sandbox kanıtı | Sonuç |
|---|---|---|---|
| Google Cloud Vision | Gerçek `.env` içinde ilgili değişkenler yok; kod ve `.env.example` var | Yok | Yapılandırılmamış/kanıtsız. |
| Nutritionix | Gerçek `.env` içinde ilgili değişkenler yok; kod ve yerel fallback var | Yok | Dış API kanıtsız; fallback doğruluğu da doğrulanmamış. |
| Twilio SMS | Gerçek `.env` içinde ilgili değişkenler yok; istemci kodu var | Mesaj SID’i/sandbox ekranı yok | SMS devre dışı veya çalışmaz kabul edilmeli. |
| SMTP | İlgili değişkenler `SET`; değerler raporlanmadı | Test e-postası, message-id veya sandbox teslim kaydı yok | Yalnız yapılandırma varlığı; çalışma kanıtı yok. |
| Üretim API dağıtımı | Mobil sabit URL içeriyor | Deployment manifesti, health check kaydı, TLS/domain sahipliği veya log yok | Uzak backend mevcut/çalışıyor sayılamaz. |
| Yerel FastAPI | Kaynak kod ve `requirements.txt` var | Temiz DB migrasyonu ve API entegrasyon testi yok | Çalışabilirlik kanıtsız. |
| Diyetisyen atama | DB modeli var | Oluşturma/atama/onay API’si ve E2E kayıt yok | Rapor alıcısı zinciri eksik. |

## 6. Sırlar ve güvenlik kanıtı

Gerçek değerler hiçbir komut çıktısına veya bu rapora yazılmadı. Sınıflandırma:

| Değişken grubu | Durum |
|---|---|
| `APP_NAME`, `DEBUG`, DB bağlantı değişkenleri, `SECRET_KEY`, `JWT_SECRET_KEY` | `SET` |
| SMTP host/port/user/password/from-name | `SET` |
| Google Vision | `EMPTY`/dosyada yok |
| Nutritionix | `EMPTY`/dosyada yok |
| Twilio | `EMPTY`/dosyada yok |

| Güvenlik artefaktı | Durum | Kanıt/risk |
|---|---|---|
| `.env.example` | Var | Placeholder örnekleri içeriyor; bu uygundur. |
| `.env` ignore kuralı | Yok | `.gitignore` içinde açık `.env` kuralı bulunmadı. |
| Secret tarama raporu | Yok | Gitleaks/TruffleHog vb. rapor yok. |
| Secret rotasyon kaydı | Yok | Sırlar daha önce paylaşıldıysa rotasyon gerekir. |
| Sürüm kontrol deposu | Yok | Denetim anında `.git` yok; geçmiş sızıntı durumu yerelden doğrulanamaz. |

## 7. Yeniden üretilebilirlik ve yönetişim

| Beklenen artefakt | Durum | Kanıt | Eksik olan |
|---|---|---|---|
| README | **Yetersiz** | Varsayılan “A new Flutter project” metni | Mimari, SDK, kurulum, env, DB, API, model, test ve build adımları. |
| Flutter bağımlılık tanımı | **Var fakat çözümsüz** | `pubspec.yaml` | `intl` sürüm çatışması; kaynakta kullanılan bazı paketler beyan edilmemiş. |
| Python bağımlılık tanımı | **Var** | `backend/requirements.txt` | Hash/lock ve temiz ortam kurulum kanıtı. |
| DB migrasyonu | **Yok** | Alembic proje dosyası yok; yalnız paket venv’de | Şema sürümü ve yükseltme/geri dönüş. |
| API sözleşmesi | **Kısmi** | FastAPI şemaları var | Mobil ile uyuşan tek OpenAPI ve contract testi. |
| SBOM/lisans raporu | **Yok** | — | Mobil/backend bağımlılık ve lisans envanteri. |
| Build provenance | **Yok** | APK var fakat commit/CI/run ID yok | Kaynak commit’i, toolchain, komut, hash, imza. |
| Değişiklik günlüğü/release notes | **Yok** | — | Sürüm kapsamı ve bilinen sınırlamalar. |
| Risk register | **Yok** | Yalnız PDF risk tablosu | Yaşayan risk kaydı, sahip ve tetikleyici. |

## 8. Artefakt kabul kapısı

Bir sonraki geliştirme/araştırma aşamasına geçmeden önce en az şu kanıt paketi oluşmalıdır:

1. Sürüm/commit kimliğine bağlı, temiz ortamda üretilmiş debug ve release build raporu.
2. Kamera sözleşmesi için mobil-backend contract testi ve gerçek cihaz E2E çıktısı.
3. Auth register/login/refresh/logout ve yetkilendirme entegrasyon test raporu.
4. Veri seti manifesti, lisansları, split hash’leri, eğitim logu, model/checkpoint ve model card.
5. Etik kurul kararı ve kurum izni; bunlardan sonra anonim onam/ham veri envanteri.
6. Ham veriden tablo/grafik/istatistik üreten tek komutluk analiz paketi.
7. SMTP/Twilio kullanılacaksa redakte edilmiş sandbox teslimat kanıtı.
8. TalkBack ve VoiceOver kritik görev kabul tutanakları.
