# Yurt dışı aktarım matrisi

KVKK m.9 kapsamında her dış sağlayıcı ayrı bir aktarım satırıdır. Türkiye
dışındaki bir sunucuda veriyi yalnız kısa süreli veya bellekte işlemek de
aktarım değerlendirmesine girer. Kurulun ilan ettiği bir yeterlilik kararı
bulunmadığı için düzenli aktarımlarda uygun güvence, pratikte değiştirilmeden
imzalanan standart sözleşme gerekir. Sözleşme imzalandıktan sonra beş iş günü
içinde Kurula bildirilir. Aydınlatmada “yurt dışı aktarımına izin ver” anahtarı
faydalı bir kullanıcı kontrolüdür, fakat sürekli sağlayıcı aktarımında tek
başına yeterli değildir.

Production, aşağıdaki sağlayıcılardan biri açıkken
`CROSS_BORDER_TRANSFER_REFERENCE` ayarı olmadan başlamaz
(`backend/app/config.py`). Bu ayara, satırların tamamlandığını gösteren aktarım
dosyasının kayıt numarası yazılır.

| Sağlayıcı | Açan ayar | Gönderilen veri | Amaç | Ülke | Varsayılan | Güvence durumu |
|---|---|---|---|---|---|---|
| Google Gemini API | `VISION_PROVIDER_MODE=gemini` | EXIF'i temizlenmiş besin fotoğrafı | Besin tanıma | ABD ve Google altyapısı | Kapalı | İmzalı standart sözleşme yok. Production'da ayrıca `GEMINI_PAID_TIER_CONFIRMED=true` zorunlu; ücretsiz katman içeriği ürün geliştirmede kullanabilir. |
| Google Cloud Vision | `VISION_PROVIDER_MODE=google` | EXIF'i temizlenmiş besin fotoğrafı | Besin tanıma | Proje bölgesine bağlı | Kapalı | İmzalı standart sözleşme yok; DPA ve bölge seçimi yapılmadı. |
| Nutritionix (Syndigo) | `NUTRITION_PROVIDER_MODE=nutritionix` veya `hybrid` | Besin arama adı | Besin değeri arama | ABD | Kapalı; varsayılan yerel USDA kataloğu | İmzalı standart sözleşme yok; API lisansı ve atıf şartı ayrıca incelenmeli. |
| Twilio | `SMS_PROVIDER_MODE=twilio` | Diyetisyen telefon numarası, içeriksiz rapor bildirimi, `D-…` danışan kodu | Rapor bildirimi | ABD (varsayılan bölge) | Kapalı | İmzalı standart sözleşme yok; Twilio DPA'sı KVKK standart sözleşmesinin yerine geçmez. |
| SMTP e-posta sağlayıcısı | `NOTIFICATION_MODE=production` | Diyetisyen e-posta adresi, içeriksiz rapor bildirimi, `D-…` danışan kodu | Rapor bildirimi | Sağlayıcı seçilmedi | Kapalı; geliştirmede yerel Mailpit | Sağlayıcı ve ülke belirlenmedi. |
| İşletim sistemi konuşma tanıma (Android: Google, iOS: Apple) | Kullanıcının sesli komut başlatması | Konuşma sesi ve tanınan metin | Sesli komut | Platform sağlayıcısına bağlı | Kullanıcı başlatınca | Uygulama cihaz içi tanımayı zorunlu kılmaz; ses platform sunucusunda işlenebilir. Uygulama ses kaydetmez. Aydınlatmada dış alıcı olarak açıklanır. |
| Barındırma ve veritabanı | Production altyapısı | Tüm hesap ve sağlık verisi | Hizmetin sunulması | Belirlenmedi | Yok | Yurt içi barındırma seçilirse bu satır aktarım değildir; seçim yapılmadı. |
| Hata ve analitik servisleri | Yok | — | — | — | Kapalı | Firebase Crashlytics ve uzak analitik kullanılmıyor. |

## Bir sağlayıcıyı açmadan önce

1. Veri aktaran ve alıcının rolünü (veri sorumlusu/veri işleyen) belirle.
2. Kurulun bu role uyan standart sözleşmesini değiştirmeden imzala ve beş iş
   günü içinde Kurula bildir.
3. Sağlayıcının alt işleyen listesini, saklama süresini, silme ve ihlal
   bildirim yükümlülüklerini dosyaya ekle.
4. Aydınlatma metnindeki alıcı ve ülke bilgisini güncelle.
5. Dosya kayıt numarasını `CROSS_BORDER_TRANSFER_REFERENCE` ayarına yaz.
