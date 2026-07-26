# Gereksinim–test matrisi

Durumlar: **Otomatik** CI kanıtı, **Manuel** gerçek cihaz/insan gerekir,
**Bloke** dış artefakt veya yetki yoktur.

| Öncelik | Yol / risk | Otomatik kanıt | Manuel kanıt | Durum |
|---|---|---|---|---|
| P0 | Register/login/refresh/logout | `backend/tests/test_auth_lifecycle.py`, `test/unit/api_service_auth_test.dart`, P0 integration auth transport | Gerçek backend staging oturumu | Otomatik |
| P0 | Kamera geçici/kalıcı izin reddi | `test/widget/camera_screen_test.dart`, `test/unit/food_scan_safety_test.dart` | API 23/35 izin ve Ayarlar dönüşü | Otomatik + Manuel |
| P0 | Yüksek güven tarama ve onay | `test/unit/food_scan_safety_test.dart`, `integration_test/p0_fixture_journey_test.dart` | Gerçek kamera ve sağlayıcı sandbox | Otomatik + Manuel |
| P0 | Orta/düşük güven/OOD ve başarısız sağlayıcı | `test/unit/food_scan_safety_test.dart`, backend image/provider testleri | Karanlık/bulanık gerçek çekimler | Otomatik + Manuel |
| P0 | Porsiyon ve kalori sınırları | `test/unit/nutrition_calculation_test.dart`, portion parser/widget testleri | Türkçe sesli 50/100/150/200 g | Otomatik + Manuel |
| P0 | Onaysız/sıfır kalorili log oluşmaması | kamera safety ve backend contract/security testleri | Ağ kesintisinde UI mesajı | Otomatik + Manuel |
| P0 | Geçmiş CRUD/filtre/timezone/ownership | `test/widget/food_history_screen_test.dart`, `backend/tests/test_food_history_api.py` | İstanbul gece yarısı cihaz kontrolü | Otomatik + Manuel |
| P0 | Bağlama duyarlı sesli komut | `test/unit/contextual_voice_command_test.dart` | Gürültü, kulaklık, Türkçe STT | Otomatik + Manuel |
| P0 | Diyetisyen ilişkilendirme ve sahiplik | `backend/tests/test_auth_dietitian_lifecycle.py` | Doğrulama sağlayıcı sandbox | Otomatik + Manuel |
| P0 | Rapor önizleme, açık onay, partial failure | `test/widget/dietitian_report_wizard_test.dart`, `backend/tests/test_dietitian_report_delivery.py`, integration | Mailpit/Twilio sandbox teslim durumu | Otomatik + Manuel |
| P0 | Çift gönderim/idempotency | backend delivery/data architecture testleri | Staging retry gözlemi | Otomatik + Manuel |
| P0 | Survey/onam/etik kapı/çekilme/export | research API ve collection testleri | Etik kurul referansı ile saha açma | Otomatik; saha Bloke |
| P0 | Hesap/veri silme ve IDOR | auth lifecycle/security/privacy testleri | Staging retention job doğrulaması | Otomatik + Manuel |
| P1 | Secure offline history cache/logout temizliği | history repository/widget testleri | Uçak modu + process kill | Otomatik + Manuel |
| P1 | OpenAPI/mobile fixture drift | backend OpenAPI check ve `test/contract` | Yok | Otomatik |
| P1 | Migration temiz DB ve downgrade | backend migration/data tests; CI `alembic upgrade head/current` | MySQL backup restore provası | Otomatik + Manuel |
| P1 | Startup config/health/readiness | backend config/security tests | Staging TLS/DB readiness | Otomatik + Manuel |
| P1 | ML split/checksum/label/OOD/metrics | `ml/tests/test_manifest.py`, `ml/tests/test_safety_gates.py` | Yok | Otomatik |
| P0 | Keras–TFLite parity, regression threshold | `ml/src/nutrisense_ml/convert.py` doğrulama kapısı | Gerçek model/checkpoint/regression set | Bloke: model yok |
| P1 | Semantics/focus/%200/contrast | `test/accessibility`, production widget testleri | TalkBack iki Android sürümü | Otomatik + Manuel |
| P1 | Release APK/AAB ve imza | CI dev debug APK; Gradle release blocker | Kurum app id + upload key ile signed AAB | AAB Bloke |

## TÜBİTAK teknik hedef bağlantısı

- Görüntüyle besin tanıma: camera contract/safety/ML satırları.
- Türkçe sesli erişim: voice intent, semantics ve gerçek cihaz satırları.
- Miktar, kalori ve besin değerleri: porsiyon/kalori/history satırları.
- Onaylı geçmiş: log karar kapısı ve history satırları.
- Diyetisyene kullanıcı onaylı e-posta/SMS: assignment/report/outbox satırları.
- Kullanılabilirlik araştırması: ethics gate/survey/export ve analiz CI hattı.

Bu matris otomatik fixture sonucunu saha, model doğruluğu veya sağlayıcı teslim
kanıtı olarak yükseltmez.
