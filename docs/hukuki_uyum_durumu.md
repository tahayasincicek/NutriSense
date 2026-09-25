# Hukuki uyum durumu

Bu belge, danışman onaylı proje teslimindeki gizlilik ve veri koruma
önlemlerini izler. Hukuki mütalaa değildir. Araştırma projesinin teknik
teslimi tamamlanmıştır; mağazada production hizmeti verecek işletmeciye ait
unvan, sözleşme ve operasyon kayıtları dağıtım sırasında eklenir.

## Kodla kapatılanlar

| Engel | Uygulanan önlem | Kanıt |
|---|---|---|
| Sağlık verisinin sıradan SMS ve e-posta gövdesinde taşınması | Rapor şeması v4: e-posta yalnız yeni rapor bildirimi, ilişkiye özel `D-…` danışan kodu ve rapor referansını içerir; SMS yalnız genel yeni rapor bildirimidir. Besin, gram, saat ve kalori yalnız giriş yapılmış diyetisyen panelinde açılır. | `backend/app/domain/report_messages.py`, `backend/tests/test_dietitian_report_delivery.py` |
| Aydınlatma ile açık rızanın ayrı düzenlenmesi (KVKK 2026/347 ilke kararı) | Aydınlatma teyidi ayrı kayıttır. Rızalar amaç bazlı ayrı anahtarlarla verilir, kapalı başlar. Güncel aydınlatma teyit edilmeden ana uygulama açılmaz. | `lib/features/auth/screens/privacy_consent_screen.dart`, `lib/features/auth/screens/auth_gate.dart`, `backend/tests/test_product_consents.py` |
| Diyetisyenle rol ve gizlilik sözleşmesi | Diyetisyen hesabı, sürüm damgalı veri işleme sözleşmesi kabul edilmeden açılmaz. | `docs/dietitian_data_processing_agreement.md`, `backend/tests/test_dietitian_mutual_consent.py` |
| Araştırma verisinde ürün kimliğinin ayrılması | Araştırma dışa aktarımı anahtarlı takma kimlik kullanır. Production ve onaylı araştırma modunda ayrı, güçlü `RESEARCH_PSEUDONYMIZATION_KEY` zorunludur. | `backend/app/config.py`, `backend/tests/test_research_ethics_gate.py` |
| Veri sorumlusu kimliği ve başvuru kanalı | `DATA_CONTROLLER_NAME` ve geçerli `DATA_CONTROLLER_CONTACT_EMAIL` olmadan production başlamaz. | `backend/app/config.py`, `backend/tests/test_legal_compliance.py` |
| Yurt dışına aktarım (KVKK m.9) | Nutritionix, Twilio veya production SMTP etkinse `CROSS_BORDER_TRANSFER_REFERENCE` olmadan production başlamaz. | aynı dosyalar; `docs/yurt_disi_aktarim_matrisi.md` |
| Fotoğrafın yurt dışına çıkması | Besin tanıma yalnız telefondaki NutriSense modeliyle yapılır; uygulama fotoğrafı sunucuya yüklemez. Gemini ve Google Vision kodu ile paketleri kaldırıldı; sunucuda sağlayıcı yokken görüntü işlenmeden reddedilir. Fotoğraf aktarımı için ayrı rıza anahtarı korunur. | `lib/features/food_scan/screens/camera_screen.dart`, `backend/app/routers/food_router.py`, `backend/tests/test_product_consents.py` |
| Uygulama dışında hesap silme yolu (Google Play) ve KVKK m.11 başvurusu | Herkese açık `/hesap-silme` (`/account-deletion`) ve `/kvkk-basvuru` sayfaları. Form içermez, veri toplamaz; veri sorumlusu iletişimini ayarlardan gösterir. | `backend/app/routers/legal_router.py`, `backend/tests/test_legal_compliance.py` |
| Fotoğrafın konum ve cihaz bilgisi | Sunucu görüntüyü EXIF'siz yeniden kodlar; dosya, veritabanı veya loga yazmaz. | `backend/app/routers/food_router.py` |
| Yurt dışına giden verinin kimliksizleştirilmesi | Sağlayıcı istekleri sunucudan çıkar; kullanıcı kimliği, IP, ad veya e-posta eklenmez. Fotoğraf en uzun kenarı 1024 piksele küçültülür. Besin araması önce yurt içi katalogda yapılır; yurt dışına yalnız bağlantı, e-posta ve telefonu silinmiş, 80 karakterle sınırlı metin gider. | `backend/app/routers/food_router.py`, `backend/app/services/nutritionix_service.py`, `backend/tests/test_provider_anonymization.py`, `docs/yurt_disi_aktarim_matrisi.md` |
| Ses ve metin okumanın cihazda kalması | Android'de cihaz üstü konuşma tanıma zorunlu istenir; destek yoksa buluta sessiz geçilmez. Metin okumada yerel Türkçe ses seçilir. iOS platform hizmeti ayrıca aydınlatılır. | `lib/shared/services/on_device_voice_policy.dart`, `test/unit/on_device_voice_policy_test.dart` |
| Açılışta Google'a yazı tipi isteği | Plus Jakarta Sans uygulamaya gömüldü; çalışırken indirme kapalı, kullanıcının IP adresi Google'a gitmez. | `assets/google_fonts/`, `lib/main.dart` |
| Veri kaynaklarına atıf | Modelin eğitim verileri ve kalori kaynakları uygulamada Ayarlar → Lisanslar ve Veri Kaynakları ekranında listelenir. | `lib/main.dart`, `ml/LICENSES.md` |
| Kayıt ekranında hesap varlığının sızması | Hasta ve diyetisyen hesabı e-postaya gönderilen kodla açılır. Kayıt isteği her durumda aynı yanıtı verir ve parola özeti iki durumda da hesaplanır; adres zaten kayıtlıysa bilgi yalnız adresin sahibine e-postayla gider. Kod beş yanlış denemede iptal olur, kayıt isteği 15 dakikada beşle sınırlıdır. | `backend/app/routers/food_router.py`, `backend/tests/test_registration_verification.py`, `backend/tests/test_dietitian_registration_verification.py`, `lib/features/auth/screens/registration_verification_screen.dart` |
| E-posta adresinin güvenli değiştirilmesi | Yeni adres, mevcut parola ve yalnız yeni adrese gönderilen sekiz haneli kod doğrulandıktan sonra etkinleşir. Yanıtlar başka bir hesabın varlığını açıklamaz; değişiklik tamamlanınca eski yenileme oturumları iptal edilir ve yeni oturum anahtarları verilir. | `backend/app/routers/food_router.py`, `backend/tests/test_email_change.py`, `lib/features/auth/screens/email_change_screen.dart` |
| Dağıtık kaba kuvvet ve kötüye kullanım sınırı | Login, kayıt, e-posta değişikliği ve besin analizi sayaçları bütün backend süreçlerinin paylaştığı veritabanında tutulur. IP/e-posta gibi ham tanımlayıcılar yerine HMAC anahtarları saklanır. | `backend/app/security/rate_limiter.py`, `backend/migrations/versions/f1a2b3c4d5e6_shared_rate_limit_buckets.py`, `backend/tests/test_email_change.py` |
| Saklama ve imha | Süresi dolan oturum anahtarları, parola sıfırlama kodları, e-posta değişiklikleri, hız sınırı sayaçları ve karara bağlanmamış tanıma denemeleri silinir; güvenlik kayıtlarında IP 90 günde boşaltılır, kayıt 365 günde silinir. Her çalıştırma kişisel veri içermeyen bir imha kaydı yazar. Süreler kurum onayı bekler. | `backend/app/domain/retention.py`, `backend/scripts/purge_expired_data.py`, `docs/saklama_ve_imha_politikasi.md` |
| Güvenlik kayıtlarında e-posta | E-posta, uygulama sırrıyla anahtarlı özet (HMAC-SHA256) olarak tutulur; düz özet gibi bilinen adres listeleriyle geri eşleştirilemez. | `backend/app/routers/food_router.py` |
| Cihazdaki sağlık verisi | Su, adım, uyku, ruh hâli, kilo ve ilaç listesi şifreli depoda tutulur. Çevrim dışı beslenme geçmişi yedi günle sınırlıdır. Paylaşılan CSV ve JSON dosyaları paylaşımdan sonra silinir; fotoğrafın EXIF bilgisi telefondan çıkmadan temizlenir. Yanlış tahmin fotoğrafı yalnız ayrı izinle yerelde tutulur; çıkış ve hesap silmede güvenli depo ile birlikte temizlenir. | `lib/features/water_tracker/state/water_provider.dart`, `lib/features/history/data/history_cache_store.dart`, `lib/shared/services/local_privacy_cleanup.dart`, `lib/shared/utils/temporary_share_file.dart`, `lib/features/food_scan/services/image_preprocessing.dart` |
| Tıbbi iddia sınırı | Tarama sonucu ve raporlarda tahmin olduğu, tıbbi teşhis veya tedavi olmadığı belirtilir. | `lib/features/food_scan/screens/camera_screen.dart`, `backend/app/domain/report_delivery.py` |
| Sağlık bilgisinin sesli okunması | Tanıtım ekranı, besin ve sağlık bilgilerinin sesli okunduğunu ve yanındakilerin duyabileceğini söyler; kalabalık ortamda kulaklık önerir. | `lib/features/onboarding/screens/onboarding_screen.dart` |
| Besin verisi kaynağına atıf | Manuel girişte seçilen besinin kartında verinin kaynağı gösterilir; Nutritionix gibi atıf isteyen lisanslı bir kaynak açılırsa atıf görünür olur. | `lib/features/food_scan/screens/manual_food_entry_screen.dart` |

## Proje teslim belgeleri ve production işletmeci alanları

| Belge | Dosya | Production dağıtımında eklenecek işletmeci kaydı |
|---|---|---|
| Aydınlatma metni | `docs/privacy_notice.md` | Veri sorumlusu, amaç bazlı hukuki sebep, saklama süreleri |
| Kullanım koşulları | `docs/kullanim_kosullari.md` | Hizmet sağlayıcı kimliği, hukukçu onayı |
| Yurt dışı aktarım matrisi | `docs/yurt_disi_aktarim_matrisi.md` | Sağlayıcı seçimi, standart sözleşme ve Kurula bildirim |
| Veri ihlali müdahale prosedürü | `docs/veri_ihlali_mudahale_proseduru.md` | İrtibat kişisi ve bildirim yetkilisi |
| Diyetisyen veri işleme sözleşmesi | `docs/dietitian_data_processing_agreement.md` | Hukukçu onayı |
| Veri işleme envanteri | `docs/data_processing_inventory.md` | Hukuki sebep ve saklama süresi sütunları |
| Etik kurul paketi | `docs/etik_kvkk_belgeleri.md` | Etik kurul kararı |
| Özel nitelikli veri güvenliği politikası | `docs/ozel_nitelikli_veri_guvenligi_politikasi.md` | Veri sorumlusu onayı, sorumlu atamaları, eğitim ve MFA kanıtı |

## Mağaza/production işletmecisinin dağıtım sorumlulukları

1. Veri sorumlusunun kim olduğuna dair yazılı karar (üniversite, proje
   yürütücüsü veya kurulacak tüzel kişi) ve başvuru için e-posta/KEP adresi.
2. Hukukçu onaylı aydınlatma, açık rıza ve kullanım koşulları metinleri.
   Onaylanan aydınlatma sürümü `PRIVACY_NOTICE_VERSION` ayarına yazılır.
3. Kullanılacak her yurt dışı sağlayıcı için KVKK standart sözleşmesinin
   değiştirilmeden imzalanması ve imzadan sonra beş iş günü içinde Kurula
   bildirilmesi.
4. Gerçek katılımcı verisi için etik kurul kararı. Karar numarası olmadan
   `RESEARCH_MODE=approved` açılamaz.
5. VERBİS kayıt yükümlülüğü ve istisna değerlendirmesi.
6. Diyetisyen özelliğinin uzaktan sağlık hizmeti sayılmayacak biçimde veri
   paylaşımıyla sınırlı kaldığının hukukçu tarafından teyidi.
7. Google Play sağlık beyanı ve Data Safety formu ile Apple App Privacy
   etiketinin gerçek build üzerinden doldurulması. Gizlilik politikasının
   herkese açık, PDF olmayan bir adreste yayımlanması.
8. Production altyapısında veritabanı ve yedek şifrelemesi, yedek imhası ve
   bağımsız sızma testi kanıtları.
9. Çocuk kullanıcılar: uygulamada yaş sınırı yoktur, çocuklar da kayıt
   olabilir. 18 yaşından küçük kullanıcıların sağlık verisi için veli onayı
   gerekip gerekmediği ve nasıl alınacağı hukukçuya danışılmalıdır.
10. Kurulun 2018/10 sayılı kararı uyarınca sağlık verisine uzaktan erişen
    diyetisyen/personel hesaplarında çok faktörlü kimlik doğrulama ve bunun
    production kanıtı.

## Açık teknik işler

- İşletim sistemi konuşma tanıma servisi: Android'de cihaz üstü tanıma
  zorunludur ve destek yoksa buluta sessiz geçiş yapılmaz. iOS'ta ses Apple
  sunucusunda işlenebilir. Bu nedenle servis aydınlatmada ve aktarım matrisinde
  dış alıcı olarak açıklanır.

## Production için zorunlu ayarlar

```text
PRIVACY_NOTICE_VERSION=<hukukça onaylı aydınlatma sürümü>
DATA_CONTROLLER_NAME=<veri sorumlusu>
DATA_CONTROLLER_CONTACT_EMAIL=<başvuru e-postası>
DATA_CONTROLLER_POSTAL_ADDRESS=<posta veya KEP adresi, önerilir>
CROSS_BORDER_TRANSFER_REFERENCE=<aktarım dosyası kayıt no; dış sağlayıcı açıksa>
```

