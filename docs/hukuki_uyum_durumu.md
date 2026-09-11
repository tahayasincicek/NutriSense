# Hukuki uyum durumu

Bu belge, 9 Eylül 2026 tarihli hukuki sorumluluk ve gizlilik araştırmasında
yayın engeli olarak sayılan maddelerin projedeki karşılığını izler. Hukuki
mütalaa değildir. Kodla kapatılan maddeler yalnız teknik önlemi gösterir;
nihai uygunluk kararını veri sorumlusu ve KVKK/sağlık hukuku alanında çalışan
bir hukukçu verir.

## Kodla kapatılanlar

| Engel | Uygulanan önlem | Kanıt |
|---|---|---|
| Sağlık verisinin sıradan SMS ve e-posta gövdesinde taşınması | Rapor şeması v4: SMS ve e-posta yalnız yeni rapor bildirimi ile ilişkiye özel `D-…` danışan kodunu içerir. Besin, gram, saat ve kalori yalnız giriş yapılmış diyetisyen panelinde açılır. | `backend/app/domain/report_messages.py`, `backend/tests/test_dietitian_report_delivery.py` |
| Aydınlatma ile açık rızanın ayrı düzenlenmesi (KVKK 2026/347 ilke kararı) | Aydınlatma teyidi ayrı kayıttır. Rızalar amaç bazlı ayrı anahtarlarla verilir, kapalı başlar. Güncel aydınlatma teyit edilmeden ana uygulama açılmaz. | `lib/features/auth/screens/privacy_consent_screen.dart`, `lib/features/auth/screens/auth_gate.dart`, `backend/tests/test_product_consents.py` |
| Diyetisyenle rol ve gizlilik sözleşmesi | Diyetisyen hesabı, sürüm damgalı veri işleme sözleşmesi kabul edilmeden açılmaz. | `docs/dietitian_data_processing_agreement.md`, `backend/tests/test_dietitian_mutual_consent.py` |
| Araştırma verisinde ürün kimliğinin ayrılması | Araştırma dışa aktarımı anahtarlı takma kimlik kullanır. Production ve onaylı araştırma modunda ayrı, güçlü `RESEARCH_PSEUDONYMIZATION_KEY` zorunludur. | `backend/app/config.py`, `backend/tests/test_research_ethics_gate.py` |
| Çocuk kullanıcılar | Yaş sınırı hukuken belirlenene kadar hizmet yetişkinlere açıktır. Kayıt, 18 yaş beyanı olmadan sunucuya gönderilmez ve sunucuda kabul edilmez. Beyan zamanı `users.adult_confirmed_at` alanında saklanır. | `lib/features/auth/screens/register_screen.dart`, `backend/app/models/schemas.py`, `backend/tests/test_legal_compliance.py` |
| Veri sorumlusu kimliği ve başvuru kanalı | `DATA_CONTROLLER_NAME` ve geçerli `DATA_CONTROLLER_CONTACT_EMAIL` olmadan production başlamaz. | `backend/app/config.py`, `backend/tests/test_legal_compliance.py` |
| Yurt dışına aktarım (KVKK m.9) | Gemini/Google Vision, Nutritionix, Twilio veya production SMTP etkinse `CROSS_BORDER_TRANSFER_REFERENCE` olmadan production başlamaz. | aynı dosyalar; `docs/yurt_disi_aktarim_matrisi.md` |
| Ücretsiz Gemini katmanına sağlık bağlamlı fotoğraf | Production'da Gemini, `GEMINI_PAID_TIER_CONFIRMED=true` olmadan açılamaz. | aynı dosyalar |
| Uygulama dışında hesap silme yolu (Google Play) ve KVKK m.11 başvurusu | Herkese açık `/hesap-silme` (`/account-deletion`) ve `/kvkk-basvuru` sayfaları. Form içermez, veri toplamaz; veri sorumlusu iletişimini ayarlardan gösterir. | `backend/app/routers/legal_router.py`, `backend/tests/test_legal_compliance.py` |
| Fotoğrafın konum ve cihaz bilgisi | Sunucu görüntüyü EXIF'siz yeniden kodlar; dosya, veritabanı veya loga yazmaz. | `backend/app/routers/food_router.py` |
| Veri kaynaklarına atıf | Modelin eğitim verileri ve kalori kaynakları uygulamada Ayarlar → Lisanslar ve Veri Kaynakları ekranında listelenir. | `lib/main.dart`, `ml/LICENSES.md` |
| Tıbbi iddia sınırı | Tarama sonucu ve raporlarda tahmin olduğu, tıbbi teşhis veya tedavi olmadığı belirtilir. | `lib/features/food_scan/screens/camera_screen.dart`, `backend/app/domain/report_delivery.py` |

## Taslağı hazır, onay bekleyen belgeler

| Belge | Dosya | Bekleyen karar |
|---|---|---|
| Aydınlatma metni | `docs/privacy_notice_draft.md` | Veri sorumlusu, amaç bazlı hukuki sebep, saklama süreleri |
| Kullanım koşulları | `docs/kullanim_kosullari_taslak.md` | Hizmet sağlayıcı kimliği, hukukçu onayı |
| Yurt dışı aktarım matrisi | `docs/yurt_disi_aktarim_matrisi.md` | Sağlayıcı seçimi, standart sözleşme ve Kurula bildirim |
| Veri ihlali müdahale prosedürü | `docs/veri_ihlali_mudahale_proseduru.md` | İrtibat kişisi ve bildirim yetkilisi |
| Diyetisyen veri işleme sözleşmesi | `docs/dietitian_data_processing_agreement.md` | Hukukçu onayı |
| Veri işleme envanteri | `docs/data_processing_inventory.md` | Hukuki sebep ve saklama süresi sütunları |
| Etik kurul paketi | `docs/etik_kvkk_belgeleri.md` | Etik kurul kararı |

## Kodla çözülemeyen, yayından önce zorunlu maddeler

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

## Açık teknik işler

- Periyodik saklama ve imha işi: süresi dolmuş oturum anahtarları, teslimat
  kayıtları ve güvenlik kayıtları için süre ve otomatik silme henüz yok.
- Sesli okumada hassas bilgi uyarısı: sağlık bilgisinin hoparlörden
  duyulabileceğine dair ilk kullanım uyarısı ve kulaklık önerisi yok.
- İşletim sistemi konuşma tanıma servisi: cihaz içi tanıma zorunlu
  kılınmıyor. Bu nedenle servis aydınlatmada ve aktarım matrisinde dış alıcı
  olarak açıklanır.

## Production için zorunlu ayarlar

```text
PRIVACY_NOTICE_VERSION=<hukukça onaylı aydınlatma sürümü>
DATA_CONTROLLER_NAME=<veri sorumlusu>
DATA_CONTROLLER_CONTACT_EMAIL=<başvuru e-postası>
DATA_CONTROLLER_POSTAL_ADDRESS=<posta veya KEP adresi, önerilir>
CROSS_BORDER_TRANSFER_REFERENCE=<aktarım dosyası kayıt no; dış sağlayıcı açıksa>
GEMINI_PAID_TIER_CONFIRMED=true   # yalnız faturalandırmalı Gemini projesi varsa
```
