# NutriSense aydınlatma/gizlilik metni — teknik taslak

**Yayınlanamaz taslak.** Veri sorumlusu, iletişim adresi, hukuki sebepler,
saklama süreleri, alıcı ülkeler/aktarım mekanizması ve başvuru yöntemi
üniversite/hukuk birimi tarafından doldurulup onaylanmadan kullanıcıya kesin
gizlilik politikası olarak sunulamaz.

## Ne işler?

NutriSense; hesap için e-posta, ad, parola hash'i ve tercihleri; hizmet için
onaylanan besin adı, porsiyon, kalori/makro ve zamanı; kullanıcı seçerse
diyetisyen iletişimi ve gönderim kayıtlarını işler. Kamera görüntüsü analiz
için geçici işlenir ve yapılandırılmışsa Google Vision'a gönderilebilir;
varsayılan akış görüntüyü dosya, veritabanı veya logda saklamaz.

Nutritionix'e besin arama adı gönderilebilir. Kullanıcının her gönderimde
onayladığı minimum rapor SMTP sağlayıcısı ve/veya Twilio üzerinden doğrulanmış
diyetisyene iletilebilir. SMS tam besin günlüğünü içermez. Bu sağlayıcılar için
yurtdışı aktarım ve sözleşme değerlendirmesi yayın öncesi tamamlanmalıdır.

## Araştırma verisi

Araştırma modu ürün hesabından ayrı rastgele pseudonym kullanır. Gerçek onam,
protocol version ve etik kurul approval reference yoksa gerçek katılımcı
verisi toplanamaz. Onam kaydı araştırma sonucundan ayrı tutulur; withdrawal
code ile çekilme/silme talebi yapılabilir.

## Kullanıcı seçimleri

Kullanıcı profilini görebilir/düzeltebilir, ürün verisini dışa aktarabilir,
besin kayıtlarını düzeltebilir/silebilir ve hesabını doğrulama adımıyla
silebilir. Diyetisyen ilişkisi iptal edilebilir. Daha önce e-posta/SMS
sağlayıcısına gönderilmiş kopyalar ile backup kopyalarının silinme süresi
kurumsal prosedürde açıklanmalıdır.

## Güvenlik ve sınırlamalar

Tokenlar mobil platform güvenli deposunda tutulur; API sahiplik kontrolleri,
JWT expiry/rotation/revocation, görüntü sınırları ve log redaksiyonu uygular.
TLS reverse proxy ve DB/yedek şifreleme production altyapısında ayrıca
kanıtlanmalıdır. Firebase Crashlytics/uzak analytics şu an kapalıdır.

Uygulama tıbbi teşhis veya kişiselleştirilmiş tedavi sunmaz; besin tanıma ve
porsiyon değerleri tahmin içerebilir. Bu sınırlama hatalı veriyi kabul
edilebilir yapmaz; düşük güvenli sonuç kullanıcı onayı olmadan kaydedilmez.

## Doldurulması gereken kurum alanları

- Veri sorumlusu ve temsilci/iletişim: `[KURUM KARARI]`
- Amaç bazlı hukuki sebep: `[HUKUK İNCELEMESİ]`
- Saklama ve backup imha takvimi: `[KURUM KARARI]`
- Dış alıcılar, ülkeler ve aktarım mekanizması: `[HUKUK İNCELEMESİ]`
- İlgili kişi başvuru yöntemi ve kimlik doğrulama: `[KURUM KARARI]`
- Şikâyet/denetim ve olay iletişim kanalı: `[KURUM KARARI]`

Kanonik teknik ayrıntı: `docs/data_processing_inventory.md`.
