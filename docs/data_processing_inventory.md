# Veri işleme envanteri

Sürüm: 1.1

Teknik durum tarihi: 2026-09-01

Bu envanter uygulamadaki gerçek/verilmesi planlanan veri akışını açıklar.
Hukuki sebep, kesin saklama süresi, veri sorumlusu ve yurtdışı aktarım
mekanizması üniversite/hukuk birimi kararı olmadan kesinleştirilmemiştir.

## Veri sınıfları

| Veri | Amaç | Teknik konum/alıcı | Hukuki karar | Saklama/silme durumu |
|---|---|---|---|---|
| E-posta, ad, opsiyonel telefon, tercihler | Hesap ve erişilebilir kullanıcı deneyimi | `users` | Sözleşme/kanuni sebep kurumca seçilmeli | Hesap aktifken önerisi; `/users/me` silme ile kaldırılır |
| Parola hash'i | Kimlik doğrulama | Argon2/bcrypt hash; DB | Kurum kararı | Düz parola saklanmaz; hesap silmeyle gider |
| Access/refresh token | Oturum | Access mobil secure storage; refresh hash DB | Güvenlik zorunluluğu | Expiry/rotation/logout; hesap silmede cascade |
| Besin adı, porsiyon, kalori, makro, zaman | Günlük ve onaylı rapor | `food_logs`, nutrition provenance | Beslenme verisi hassas kabul edilerek kurum kararı | Kullanıcı silene/hesabı kapatana kadar önerisi; yedek süresi bekliyor |
| Tanıma sonucu/güven | Güvenli onay ve kalite | `recognition_attempts`; ham görüntü yok | Hizmet ve araştırma ayrımı kararı | Günlükle uyumlu; hesap silmede cascade |
| Kamera görüntüsü | Tek seferlik besin analizi | Bellekte sanitize edilir; Google Vision'a gönderilebilir | Açık aydınlatma ve yurtdışı aktarım kararı | Varsayılan olarak dosya/DB/logda saklanmaz |
| Diyetisyen adı/iletişim/doğrulama | Kullanıcının seçtiği alıcı | `dietitians`, assignment | Diyetisyen doğrulama ve rol kararı | İlişki iptali/pasifleştirme; kesin süre bekliyor |
| Onaylı rapor ve gönderim metadatası | Kullanıcı talebiyle paylaşım ve retry | DB; SMTP/Twilio | Her gönderimde ayrı onay; sağlayıcı sözleşmesi | Kurum retention ve provider silme süresi bekliyor |
| Rapor alıcı adresi/telefonu | Teslimat | Provider'a açık; DB/audit'te maskeli snapshot | Veri aktarım değerlendirmesi | Provider politikasına bağlı; uygulama kaydı hesapla silinir |
| Su, adım, uyku, ruh hâli | Kullanıcının kendi sağlık takibi | `health_metrics` (kullanıcı + gün başına tek satır) | Sağlık verisi; KVKK m.6 özel nitelikli. Açık rıza gerekir | Hesap silmede cascade; dışa aktarıma dahil |
| Kilo ölçümü | Kullanıcının kendi sağlık takibi | `weight_measurements` (zaman serisi) | Sağlık verisi; KVKK m.6 özel nitelikli. Açık rıza gerekir | Hesap silmede cascade; dışa aktarıma dahil |
| Diyetisyen cevabı | Danışanın raporuna yanıt | `dietitian_reports.dietitian_reply` | Sağlık verisi üzerinden yazışma; ayrı rıza ve aydınlatma değerlendirmesi gerekir | Rapor kaydıyla; kurum retention kararı bekliyor |
| Ürün rızası kaydı | Açık rızanın ve geri çekilmenin ispatı | `consent_records` (amaç + politika sürümü) | KVKK m.6 açık rıza ispat yükü | Geri çekme kaydı silmez, yeni kayıt yazar; hesap silmede cascade |
| Survey/usability yanıtı | Etik onaylı HCI araştırması | Ayrı pseudonym alanı, araştırma tabloları | Etik kurul + araştırma hukuki sebebi | Onaylı DMP süresi; withdrawal koduyla silme |
| Araştırma onam kanıtı | Onam/çekilme ispatı | Sonuçtan ayrı `research_consents` | Etik kurul kararı | Sonuçtan ayrı; çekilmede minimal audit dışında silme |
| Audit olayları/IP/hash | Güvenlik, rıza ve işlem kanıtı | `audit_events` | Meşru menfaat/kanuni yükümlülük analizi | Öneri 1 yıl; kurum kararı ve anonimleştirme gerekir |
| Uygulama/server logu | Teşhis ve güvenlik | Yerel/işletim logu; redakte | Kurum işletim kararı | Süre henüz tanımlı değil; kısa ve erişim kontrollü olmalı |
| Crash/analytics | Şu an işlenmiyor | Crashlytics kapalı | Etkinleştirilirse yeni değerlendirme | Veri yok; remote crash gönderimi yapılmaz |

## Dış alıcılar ve yurtdışı aktarım riski

| Alıcı | Gönderilen minimum veri | Gönderilmeyen veri | Durum/kapı |
|---|---|---|---|
| Google Vision | Sanitize edilmiş görüntü byte'ları | Token, parola, kullanıcı UUID'si, günlük geçmişi | Credentials yoksa fail-closed; aydınlatma/DPA/yurtdışı kararı gerekir |
| Google Gemini (AI Studio) | Sanitize edilmiş görüntü byte'ları | Token, parola, kullanıcı UUID'si, günlük geçmişi | `VISION_PROVIDER_MODE=gemini` ile devreye girer. Vision ile aynı yurtdışı aktarım kararını gerektirir; çok modlu model şartları ayrıca incelenmelidir |
| Nutritionix | Normalize besin arama adı | Görüntü, hesap kimliği, iletişim | API şartları/attribution ve aktarım değerlendirmesi gerekir |
| SMTP sağlayıcısı | Onaylı dönem raporu ve alıcı e-posta | Parola/token; onaysız kayıt | Production secret store, TLS ve sağlayıcı sözleşmesi gerekir |
| Twilio | Kısa, ayrıntısız SMS özeti ve telefon | Tam besin günlüğü/görüntü | Sandbox allowlist; production aktarım/hukuk kararı gerekir |
| Firebase Crashlytics | Hiçbir veri | Tüm veriler | Yapılandırılmamış ve kod kapısı nedeniyle devre dışı |

Sağlayıcıların ülke/alt işleyen/retention bilgileri teknik depodan
kanıtlanamaz. Production öncesi üniversite veri sorumlusu tarafından güncel
sözleşme ve aktarım mekanizması kaydedilmelidir.

## Veri sahibi hakları ve teknik karşılık

| Talep | Teknik yol | Sınır |
|---|---|---|
| Hesap verisini görme | `GET /api/v1/users/me` | Yalnız token sahibi |
| Profil/tercih düzeltme | `PATCH /api/v1/users/me` | E-posta değişimi/reverification ayrıca tasarlanmalı |
| Ürün verisini dışa aktarma | `GET /api/v1/users/me/export` | Parola hash'i ve tokenlar çıkmaz; araştırma verisi ayrı |
| Günlük düzeltme/silme | `PATCH/DELETE /api/v1/food-logs/{id}` | Sahiplik ve audit; soft-delete/restore |
| Hesap silme | `DELETE /api/v1/users/me` | Parola + kesin ifade; DB cascade; backup/provider silmesi dış prosedür |
| Diyetisyen rızasını iptal | Assignment iptal endpointi | Yeni gönderimi engeller; önceden gönderilen kopya provider politikasına bağlı |
| Rızayı geri çekme | `PUT /api/v1/consents` (`granted: false`) | Yurt dışı aktarım rızası geri alınınca fotoğraf analizi 403 döner; manuel giriş açık kalır |
| Rıza durumunu görme | `GET /api/v1/consents` | Yalnız token sahibi |
| Araştırmadan çekilme | `POST /api/v1/research/withdraw` | Düz withdrawal code yalnız katılımcıda; server hash tutar |

## Privacy-by-design kuralları

1. Görüntü EXIF yönü düzeltilip RGB JPEG'e yeniden kodlanır; ham yükleme ve
   base64 loglanmaz, `food_logs.image_url` yeni akışta boş bırakılır.
2. Besin kaydı yalnız kullanıcı onayından sonra oluşur.
3. Diyetisyen raporu yalnız onaylanmış kayıtlardan ve her gönderimde yeni açık
   onayla hazırlanır; alıcı önizlemede maskelenir.
4. SMS tam günlüğü içermez.
5. Araştırma pseudonym'i hesap UUID'si değildir; onam sonucu verisinden ayrıdır.
6. Gerçek araştırma modu gerçek protocol/consent/approval alanları olmadan
   açılmaz; geliştirme sentetik fixture kullanır.
7. Log filter token, parola, e-posta, telefon, görüntü/base64 ve exception
   mesajını redakte eder.
8. Aydınlatma metni açık rızadan ayrı ekranda sunulur; rıza amaç bazlıdır ve
   kapalı başlar. Sessiz kabul yoktur.
9. Yurt dışı aktarım rızası verilmediyse görüntü hiç işlenmez ve sağlayıcıya
   gönderilmez; kullanıcı manuel girişle uygulamayı kullanmaya devam eder.
   Rıza yalnız kayıt değil, koddaki bir kapıdır.
10. Rıza geri çekildiğinde önceki kayıt silinmez; yeni kayıt yazılır, böylece
    rızanın ne zaman verilip alındığı ispatlanabilir.

## Karar bekleyen alanlar

- Veri sorumlusu ve irtibat kanalı.
- Her amaç için hukuki sebep ve gerekiyorsa açık rıza metni.
- Her veri sınıfı, log ve yedek için kesin retention/imha takvimi.
- Google/Nutritionix/Twilio/SMTP için yurtdışı aktarım ve sözleşmeler.
- Diyetisyen kimlik doğrulama otoritesi ve rol sınırları.
- Veri sahibi başvurusu kimlik doğrulama ve yanıt prosedürü.
- İhlal bildirimi sorumluları ve yasal süre değerlendirmesi (Kurul kararına
  göre en geç 72 saat).
- Sağlık verisinin işlenmesinde hukuki sebep: açık rıza hizmetin şartına
  bağlanamayacağı için çekirdek besin takibinin hangi sebebe dayanacağı
  hukuk birimince belirlenmelidir. Kod rızayı kaydeder, kararı kilitlemez.
- Yurt dışına aktarımda standart sözleşme kullanılacaksa imzadan sonra beş iş
  günü içinde Kuruma bildirim yükümlülüğü (KVKK m.9/5).
- VERBİS kayıt yükümlülüğü: Kurul'un 04.09.2025 tarihli 2025/1572 sayılı
  kararındaki çalışan sayısı ve bilanço eşiklerine göre değerlendirilmelidir.
- Aydınlatma metninin kurum alanları doldurulup yayımlanması; `PRIVACY_NOTICE_VERSION`
  bu sürümle güncellenmelidir.
