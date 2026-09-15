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

## Anonimleştirme önlemleri

Yurt dışına giden her istek, kişiyi tanıtan bilgiden arındırılır. Hiçbir
özellik kapatılmaz; kimliksizleştirme sağlayıcıya gitmeden önce yapılır.

- **Kimlik yok:** Görüntü tanıma ve besin arama istekleri sunucudan çıkar.
  Sağlayıcı kullanıcının IP adresini görmez; isteğe kullanıcı kimliği, ad,
  e-posta, hesap numarası veya cihaz bilgisi eklenmez.
- **Fotoğraf:** Telefonda ve sunucuda EXIF (konum, cihaz modeli, çekim zamanı)
  silinir. Sunucu fotoğrafı en uzun kenarı 1024 piksel olacak şekilde küçültür
  ve renk profilini kopyalamadan yeniden kodlar; arka plandaki kişi, belge veya
  ekran ayrıntısı azalır. Fotoğraf dosyaya, veritabanına veya loga yazılmaz.
- **Besin araması:** Önce yurt içindeki doğrulanmış katalog aranır; bulunan
  besin için yurt dışına istek gitmez. Katalogda olmayan besinde metinden
  bağlantı, e-posta ve telefon numarası silinir, izin verilmeyen karakterler
  atılır ve metin 80 karakterle sınırlanır.
- **Rapor bildirimleri:** SMS ve e-posta yalnız yeni rapor bildirimi ile
  geri çözülemeyen, ilişkiye özel `D-…` danışan kodunu taşır. Danışan adı,
  besin, gram, saat ve kalori bu kanallara yazılmaz.
- **Konuşma tanıma:** Android'de önce cihaz üstü tanıma istenir; ses telefondan
  çıkmaz. Türkçe dil paketi kurulu değilse sesli komut bozulmasın diye bir kez
  standart tanımaya dönülür.
- **Metin okuma:** Android'de cihazda kurulu yerel Türkçe ses seçilir; okunan
  besin ve sağlık metni Google'ın ağ seslerine gönderilmez.
- **Yazı tipi:** Plus Jakarta Sans uygulamayla gelir. Uygulama açılışta
  Google'a yazı tipi isteği göndermez, kullanıcının IP adresi paylaşılmaz.

Anonimleştirme riski azaltır ama aktarım değerlendirmesinin yerine geçmez:
fotoğraf içeriği ve diyetisyenin iletişim adresi hâlâ kişisel veri
olabilir. Bu yüzden rıza anahtarı, standart sözleşme ve
`CROSS_BORDER_TRANSFER_REFERENCE` kapısı korunur.

## Sağlayıcılar

| Sağlayıcı | Açan ayar | Gönderilen veri | Amaç | Ülke | Varsayılan | Güvence durumu |
|---|---|---|---|---|---|---|
| Google Gemini API | `VISION_PROVIDER_MODE=gemini` | Küçültülmüş, EXIF'i temizlenmiş besin fotoğrafı ve sabit istem metni; kullanıcı kimliği yok | Besin tanıma | ABD ve Google altyapısı | Kapalı | İmzalı standart sözleşme yok. Production'da ayrıca `GEMINI_PAID_TIER_CONFIRMED=true` zorunlu; ücretsiz katman içeriği ürün geliştirmede kullanabilir. |
| Google Cloud Vision | `VISION_PROVIDER_MODE=google` | Küçültülmüş, EXIF'i temizlenmiş besin fotoğrafı; kullanıcı kimliği yok | Besin tanıma | Proje bölgesine bağlı | Kapalı | İmzalı standart sözleşme yok; DPA ve bölge seçimi yapılmadı. |
| Nutritionix (Syndigo) | `NUTRITION_PROVIDER_MODE=nutritionix` veya `hybrid` | Kimliksizleştirilmiş besin arama metni; yerel katalogda bulunan besin için istek yok | Besin değeri arama | ABD | Kapalı; varsayılan yerel USDA kataloğu | İmzalı standart sözleşme yok; API lisansı ve atıf şartı ayrıca incelenmeli. |
| Twilio | `SMS_PROVIDER_MODE=twilio` | Diyetisyen telefon numarası, içeriksiz rapor bildirimi, `D-…` danışan kodu | Rapor bildirimi | ABD (varsayılan bölge) | Kapalı | İmzalı standart sözleşme yok; Twilio DPA'sı KVKK standart sözleşmesinin yerine geçmez. |
| SMTP e-posta sağlayıcısı | `NOTIFICATION_MODE=production` | Diyetisyen e-posta adresi, içeriksiz rapor bildirimi, `D-…` danışan kodu | Rapor bildirimi | Sağlayıcı seçilmedi | Kapalı; geliştirmede yerel Mailpit | Sağlayıcı ve ülke belirlenmedi. |
| İşletim sistemi konuşma tanıma (Android: Google, iOS: Apple) | Kullanıcının sesli komut başlatması | Konuşma sesi ve tanınan metin | Sesli komut | Platform sağlayıcısına bağlı | Kullanıcı başlatınca | Android'de önce cihaz üstü tanıma kullanılır; Türkçe dil paketi yoksa ses platform sunucusunda işlenebilir. iOS'ta Apple tanıması kullanılır. Uygulama ses kaydetmez. |
| İşletim sistemi metin okuma (Android: Google, iOS: Apple) | Uygulamanın sesli geri bildirimi | Okunan metin | Sesli geri bildirim | Cihaz | Açık | Android'de yerel Türkçe ses seçilir; yerel ses yoksa cihazın varsayılan sesi kullanılır. |
| Barındırma ve veritabanı | Production altyapısı | Tüm hesap ve sağlık verisi | Hizmetin sunulması | Belirlenmedi | Yok | Yurt içi barındırma seçilirse bu satır aktarım değildir; seçim yapılmadı. |
| Yazı tipi indirme | Yok | — | — | — | Kapalı | Yazı tipi uygulamayla gelir; çalışırken indirilmez. |
| Hata ve analitik servisleri | Yok | — | — | — | Kapalı | Firebase Crashlytics ve uzak analitik kullanılmıyor. |

## Bir sağlayıcıyı açmadan önce

1. Veri aktaran ve alıcının rolünü (veri sorumlusu/veri işleyen) belirle.
2. Kurulun bu role uyan standart sözleşmesini değiştirmeden imzala ve beş iş
   günü içinde Kurula bildir.
3. Sağlayıcının alt işleyen listesini, saklama süresini, silme ve ihlal
   bildirim yükümlülüklerini dosyaya ekle.
4. İsteğe kişiyi tanıtan yeni bir alan eklenmediğini
   `backend/tests/test_provider_anonymization.py` ile doğrula.
5. Aydınlatma metnindeki alıcı ve ülke bilgisini güncelle.
6. Dosya kayıt numarasını `CROSS_BORDER_TRANSFER_REFERENCE` ayarına yaz.
