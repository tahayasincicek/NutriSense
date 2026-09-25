# Özel nitelikli kişisel veri güvenliği politikası

**Durum: danışman onaylı proje teslim sürümü.** Production işletmecisine ait
rol isimleri, eğitim kayıtları ve operasyon kanıtları dağıtımda eklenir.

Bu politika NutriSense'in beslenme, kilo, uyku, ruh hâli, ilaç ve benzeri
sağlık bağlamlı verileri için uygulanır. Dayanak, KVKK m.6 ile Kurulun
31.01.2018 tarihli 2018/10 sayılı kararıdır.

## Roller ve erişim

- Veri sorumlusu, sistem sahibi, güvenlik sorumlusu ve ihlal irtibat kişisi
  isimleri production öncesinde yazılı olarak atanır.
- Kullanıcı yalnız kendi kaydına; diyetisyen yalnız karşılıklı onaylı ve aktif
  ilişkisindeki danışanın açıkça paylaştığı veriye erişir.
- Yönetim ve destek erişimleri görev, süre ve gerekçeyle sınırlandırılır;
  erişimler en az üç ayda bir gözden geçirilir.
- Görevi değişen veya ayrılan kişinin erişimi derhal kaldırılır ve tahsisli
  anahtar/cihazlar geri alınır.
- Sağlık verisine uzaktan personel/diyetisyen erişimi için çok faktörlü kimlik
  doğrulama production yayınından önce zorunludur. Mevcut uygulamada bu kanıt
  production kullanıcıları açılmadan önce tamamlanır; proje uygulaması
  teslim kapsamının dışındaki operasyon kontrolüdür.

## Teknik önlemler

- Ağ aktarımı TLS ile; veritabanı, yedek ve cihaz kopyaları güçlü şifreleme ile
  korunur. Anahtarlar veriden ayrı secret/key yönetim sisteminde tutulur.
- Yetki verme, görüntüleme, paylaşma, değiştirme, dışa aktarma ve silme
  hareketleri değiştirilmeye karşı korunan audit kaydına yazılır. Loglarda
  sağlık içeriği, parola, token veya açık iletişim bilgisi tutulmaz.
- Güvenlik yamaları düzenli izlenir; bağımlılık taraması, yetki testi ve sızma
  testi sonuçları tarih/sürüm ile saklanır.
- E-posta ve SMS sağlık ayrıntısı taşımaz. Diyetisyen rapor ayrıntıları yalnız
  giriş korumalı panelde gösterilir.
- Yedek geri yükleme ve imha tatbikatı yapılmadan production veri toplama
  açılmaz.

## İdari önlemler

- Sağlık verisine erişebilen herkes işe başlamadan önce KVKK ve özel nitelikli
  veri güvenliği eğitimi alır; eğitim yılda en az bir kez yenilenir.
- Personel, diyetisyen ve veri işleyen sağlayıcılarla rolüne uygun gizlilik ve
  veri işleme sözleşmesi yapılır.
- İhlal şüphesinde erişim sınırlandırılır, kanıt korunur ve
  `docs/veri_ihlali_mudahale_proseduru.md` uygulanır.
- Bu politika yılda en az bir kez ve her önemli veri akışı değişikliğinde
  gözden geçirilir; değişiklik kaydı tutulur.

## Production kabul kanıtları

Yayın kararı için aşağıdaki kanıtlar dosyalanır:

1. Atanmış roller ve güncel erişim listesi.
2. Eğitim ve gizlilik sözleşmesi kayıtları.
3. Diyetisyen/personel MFA testi.
4. TLS, veritabanı ve yedek şifreleme kanıtı.
5. Yetki/audit ve hesap silme test raporu.
6. Sızma testi, yama ve bağımlılık tarama raporu.
7. Yedek geri yükleme ve imha tatbikatı.
8. Yurt dışı aktarım mekanizması ve sağlayıcı sözleşmeleri.

## Resmî dayanaklar

- [KVKK Özel Nitelikli Kişisel Verilerin İşlenmesine İlişkin Rehber](https://www.kvkk.gov.tr/Icerik/8184/Ozel-Nitelikli-Kisisel-Verilerin-Islenmesine-Iliskin-Rehber)
- [Kurulun 31.01.2018 tarihli 2018/10 sayılı kararı](https://www.kvkk.gov.tr/Icerik/4110/2018-10)
- [Yurt dışı standart sözleşmeler kamuoyu duyurusu](https://www.kvkk.gov.tr/Icerik/8170/Yurt-Disina-Kisisel-Veri-Aktariminda-Kullanilacak-Standart-Sozlesmelerde-Dikkat-Edilmesi-Gereken-Hususlara-Iliskin-Kamuoyu-Duyurusu)
