# NutriSense aydınlatma/gizlilik metni — teknik taslak

**Yayınlanamaz taslak.** Veri sorumlusu, iletişim adresi, hukuki sebepler,
saklama süreleri, alıcı ülkeler/aktarım mekanizması ve başvuru yöntemi
üniversite/hukuk birimi tarafından doldurulup onaylanmadan kullanıcıya kesin
gizlilik politikası olarak sunulamaz.

## Ne işler?

NutriSense; hesap için e-posta, ad, parola hash'i ve tercihleri; hizmet için
onaylanan besin adı, porsiyon, kalori/makro ve zamanı; kullanıcı seçerse
diyetisyen iletişimi ve gönderim kayıtlarını işler. Besin fotoğrafı ya kameradan çekilir ya da kullanıcının galerisinden tek tek seçtiği dosyadan alınır; uygulama fotoğraf kütüphanesini taramaz, yalnız seçilen dosyayı okur. Kamera görüntüsü analiz
için geçici işlenir ve yapılandırılmışsa Google Vision veya Google Gemini'ye
gönderilebilir; varsayılan akış görüntüyü dosya, veritabanı veya logda
saklamaz.

Kullanıcı isterse su, adım, uyku, ruh hâli ve kilo ölçümlerini de kaydeder.
Bunlar sağlık verisidir ve hesaba bağlı olarak saklanır; hesap silindiğinde
birlikte silinir, veri dışa aktarımına dahildir.

Diyetisyen, kendisine ulaşan rapora tek bir cevap yazabilir. Cevap sağlık
verisi bağlamında bir yazışmadır ve yalnız raporu gönderen danışana görünür.

Nutritionix'e besin arama adı gönderilebilir. Kullanıcının her gönderimde
onayladığı raporun sağlık ayrıntıları yalnız doğrulanmış ve atanmış diyetisyenin
uygulama içi panelinde gösterilir. SMTP sağlayıcısı ve/veya Twilio yalnız yeni
rapor bildirimi, alıcı iletişim adresi ve ilişkiye özel `D-…` danışan kodunu
işler; besin adı, gram, tarih-saat, kalori ve kullanıcı notu bu kanallara
verilmez. Bu paylaşım gönderim öncesinde ayrıca açıklanır ve onaylanır. Bu sağlayıcılar için
yurtdışı aktarım ve sözleşme değerlendirmesi yayın öncesi tamamlanmalıdır.

## Araştırma verisi

Araştırma modu ürün hesabından ayrı rastgele pseudonym kullanır. Gerçek onam,
protocol version ve etik kurul approval reference yoksa gerçek katılımcı
verisi toplanamaz. Onam kaydı araştırma sonucundan ayrı tutulur; withdrawal
code ile çekilme/silme talebi yapılabilir.

## Aydınlatma ve açık rıza

Aydınlatma metni ile açık rıza uygulamada ayrı sunulur: metin kendi bölümünde
okunur/dinlenir, izinler ise amaç bazlı ayrı anahtarlarla verilir. İzinler
kapalı başlar; sessiz kabul yoktur ve her izin sonradan Ayarlar'dan geri
alınabilir.

Şu an iki amaç için ayrı rıza alınır: sağlık verilerinin işlenmesi ve
fotoğrafın analiz için yurt dışındaki sağlayıcıya gönderilmesi.

Yurt dışı aktarım rızası verilmezse fotoğraf hiç işlenmez ve sağlayıcıya
gönderilmez; kullanıcı besinleri elle girerek uygulamayı kullanmaya devam
eder. Rıza kayıtları politika sürümüyle damgalanır; geri çekme önceki kaydı
silmez, yeni kayıt yazar.

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
- Sağlık verisi işlemenin hukuki sebebi: `[HUKUK İNCELEMESİ]` — açık rıza
  hizmetin şartına bağlanamaz; çekirdek besin takibi için dayanak belirlenmeli.
- Yayımlanan metnin sürümü `PRIVACY_NOTICE_VERSION` ayarına yazılmalıdır;
  varsayılan `taslak-yayinlanmadi` değeri metnin nihai olmadığını gösterir.

Kanonik teknik ayrıntı: `docs/data_processing_inventory.md`.
