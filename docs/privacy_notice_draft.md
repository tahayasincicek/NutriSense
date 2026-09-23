# NutriSense aydınlatma/gizlilik metni — teknik taslak

**Yayınlanamaz taslak.** Veri sorumlusu, iletişim adresi, hukuki sebepler,
saklama süreleri, alıcı ülkeler/aktarım mekanizması ve başvuru yöntemi
üniversite/hukuk birimi tarafından doldurulup onaylanmadan kullanıcıya kesin
gizlilik politikası olarak sunulamaz.

## Ne işler?

NutriSense; hesap için e-posta, ad, parola hash'i ve tercihleri; hizmet için
onaylanan besin adı, porsiyon, kalori/makro ve zamanı; kullanıcı seçerse
diyetisyen iletişimi ve gönderim kayıtlarını işler. Besin fotoğrafı ya kameradan çekilir ya da kullanıcının galerisinden tek tek seçtiği dosyadan alınır; uygulama fotoğraf kütüphanesini taramaz, yalnız seçilen dosyayı okur. Kamera görüntüsü
besin tanıma için yalnız telefonda, uygulamayla gelen NutriSense modeliyle
işlenir; fotoğraf sunucuya veya yurt dışına gönderilmez, dosya, veritabanı
veya logda saklanmaz. Sunucu tarafında görüntü sağlayıcısı yoktur ve production uygulaması
fotoğraf aktarım rızası istemez. Böyle bir özellik ileride eklenecekse yeni veri
akışı ayrıca değerlendirilmeden ve kullanıcıya sunulmadan etkinleştirilemez.

Kullanıcı isterse su, adım, uyku, ruh hâli ve kilo ölçümlerini de kaydeder.
Bunlar sağlık verisidir ve hesaba bağlı olarak saklanır; hesap silindiğinde
birlikte silinir, veri dışa aktarımına dahildir. Bu ölçümlerin cihazdaki
kopyası şifreli depoda tutulur.

Kullanıcının eklediği ilaç ve takviye listesi ile bunların o gün alınıp
alınmadığı da sağlık verisidir. Bu liste yalnız cihazda, şifreli depoda
tutulur ve sunucuya gönderilmez; uygulama kaldırıldığında cihazdan silinir.

Diyetisyen, kendisine ulaşan rapora tek bir cevap yazabilir. Cevap sağlık
verisi bağlamında bir yazışmadır ve yalnız raporu gönderen danışana görünür.

Besin araması önce yurt içindeki doğrulanmış katalogda yapılır; bulunan besin
için Nutritionix'e istek gitmez. Katalogda olmayan besinde Nutritionix'e yalnız
kimliksizleştirilmiş arama metni gönderilir: metindeki bağlantı, e-posta ve
telefon numarası silinir, metin 80 karakterle sınırlanır. Kullanıcının her gönderimde
onayladığı raporun sağlık ayrıntıları yalnız doğrulanmış ve atanmış diyetisyenin
uygulama içi panelinde gösterilir. SMTP sağlayıcısı ve/veya Twilio yalnız yeni
rapor bildirimi, alıcı iletişim adresi ve ilişkiye özel `D-…` danışan kodunu
işler; besin adı, gram, tarih-saat, kalori ve kullanıcı notu bu kanallara
verilmez. Bu paylaşım gönderim öncesinde ayrıca açıklanır ve onaylanır. Bu sağlayıcılar için
yurtdışı aktarım ve sözleşme değerlendirmesi yayın öncesi tamamlanmalıdır.

## Hesap açma

Kayıt, e-posta adresine gönderilen sekiz haneli kodla tamamlanır. Kod
doğrulanana kadar ad, e-posta, parola özeti ve kodun özeti en fazla 30 dakika
bekleyen kayıt olarak tutulur; süre dolunca silinir. Kayıt ekranı bir adresin
kayıtlı olup olmadığını göstermez: adres zaten kayıtlıysa bu bilgi yalnız
adresin sahibine e-postayla bildirilir.

## Sesli komut ve konuşma tanıma

Sesli komutlar cihazın işletim sistemindeki konuşma tanıma servisiyle
(Android'de Google, iOS'ta Apple) yazıya çevrilir. NutriSense sesi dosyaya,
veritabanına veya loga yazmaz. Android ve iOS'ta yalnız cihaz üstü tanıma istenir. Türkçe dil paketi veya
cihaz üstü destek yoksa bulut tanımaya sessiz geçilmez; kullanıcı dokunmatik
veya klavyeyle devam eder. NutriSense sesi sunucuya göndermez. Bu servis
`docs/yurt_disi_aktarim_matrisi.md` içinde ayrı satırdır. Sesli komut
kullanmadan dokunmatik ekran ve klavyeyle devam edilebilir.

Uygulama besin ve sağlık bilgilerini sesli okuyabilir; çevredekiler bu
bilgileri duyabilir. Kalabalık ortamda kulaklık önerilir. Android'de cihazda
kurulu yerel Türkçe ses seçilir; okunan metin Google'ın ağ seslerine gönderilmez.

Uygulamanın yazı tipi uygulamayla birlikte gelir; açılışta Google'dan yazı
tipi indirilmez ve kullanıcının IP adresi bu amaçla paylaşılmaz.

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

Sağlık verilerinin işlenmesi için ayrı, kapalı başlayan rıza alınır.
Fotoğraf cihazda işlendiği ve dışarı aktarılmadığı için gerçekleşmeyen gelecekteki
bir aktarım adına rıza istenmez.

Rıza kayıtları politika sürümüyle damgalanır; geri çekme önceki kaydı
silmez, yeni kayıt yazar.

## Kullanıcı seçimleri

Kullanıcı profilini görebilir/düzeltebilir, ürün verisini dışa aktarabilir,
besin kayıtlarını düzeltebilir/silebilir ve hesabını doğrulama adımıyla
silebilir. Uygulamaya erişemeyen kullanıcı için hesap silme yolu `/hesap-silme`,
KVKK m.11 başvuru yolu `/kvkk-basvuru` adresinde herkese açık yayımlanır.
Diyetisyen ilişkisi iptal edilebilir. Daha önce e-posta/SMS
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

- Veri sorumlusu ve temsilci/iletişim: `[KURUM KARARI]` — `DATA_CONTROLLER_NAME`
  ve `DATA_CONTROLLER_CONTACT_EMAIL` ayarlarına yazılır; boşken production
  başlamaz.
- Amaç bazlı hukuki sebep: `[HUKUK İNCELEMESİ]`
- Saklama ve backup imha takvimi: `[KURUM KARARI]` — taslak süreler ve
  uygulanan periyodik imha `docs/saklama_ve_imha_politikasi_taslak.md` içindedir.
- Dış alıcılar, ülkeler ve aktarım mekanizması: `[HUKUK İNCELEMESİ]` — satırlar
  `docs/yurt_disi_aktarim_matrisi.md` içindedir; aktarım dosyasının kayıt
  numarası `CROSS_BORDER_TRANSFER_REFERENCE` ayarına yazılır.
- İlgili kişi başvuru yöntemi ve kimlik doğrulama: `[KURUM KARARI]`
- Şikâyet/denetim ve olay iletişim kanalı: `[KURUM KARARI]`
- 18 yaşından küçük kullanıcılar için veli onayı gerekip gerekmediği:
  `[HUKUK İNCELEMESİ]` — uygulamada yaş sınırı yoktur.
- Sağlık verisi işlemenin hukuki sebebi: `[HUKUK İNCELEMESİ]` — açık rıza
  hizmetin şartına bağlanamaz; çekirdek besin takibi için dayanak belirlenmeli.
- Yayımlanan metnin sürümü `PRIVACY_NOTICE_VERSION` ayarına yazılmalıdır;
  varsayılan `taslak-yayinlanmadi` değeri metnin nihai olmadığını gösterir.

Kanonik teknik ayrıntı: `docs/data_processing_inventory.md`.
