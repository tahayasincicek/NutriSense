# NutriSense Türk yemekleri görsel veri toplama protokolü

## Amaç ve etik ön koşul

Amaç yalnız `ml/configs/mvp_v1.json` içindeki sınıflar ve desteklenmeyen/OOD güvenlik değerlendirmesi için yemek fotoğrafı toplamaktır. İnsan katılımcıdan veri alınmadan önce kurumun etik/onam gerekliliği yazılı olarak belirlenir. Gerekli onay yoksa saha toplaması başlamaz ve yapılmış gibi raporlanmaz.

## Rıza ve telif izni

Katkıcıya amaç, saklama süresi, erişecek roller, model eğitimi, olası yayın çıktısı, yeniden dağıtımın varsayılan olarak yapılmayacağı, geri çekme yöntemi ve geri çekmenin daha önce eğitilmiş modele etkisi sade Türkçeyle anlatılır. Fotoğrafı çeken kişinin görsel üzerindeki kullanım izni ayrıca alınır. Restoran, platform veya üçüncü kişiye ait menü görseli kopyalanmaz. Onam reddi hizmet erişimini etkilemez.

## Çekim kuralları

- Karede yüz, beden, plaka, adres, belge, fiş, ekran, kullanıcı adı veya ayırt edici kişisel eşya bulunmaz.
- Konum kaydı kapatılır; kabul edilen kopyadan EXIF/GPS temizlenir.
- Her fiziksel tabak/aynı kısa çekim serisine rastgele `group_id` verilir. Hesap UUID’si, ad, telefon veya e-posta manifestte yer almaz.
- Etiket iki bağımsız gözden geçirici tarafından kontrol edilir; uyuşmazlık çözülmeden örnek kabul edilmez.
- Çeşitlilik için farklı telefon, ışık, açı, uzaklık, kap, sunum ve arka plan planlı biçimde kaydedilir; kişisel özellik çıkarımı yapılmaz.
- Çoklu yemek, yoğun örtüşme veya sınıf dışı yemek desteklenen sınıfa zorlanmaz; uygun ise OOD olarak etiketlenir.

## Kalite ve veri zinciri

Orijinal yükleme alanı erişim kontrollüdür. Kabul/red, label, kaynak, lisans/onam kayıt referansı ve `group_id` tutulur. Manifest SHA-256 veri sürümünü oluşturur. Train/validation/test ayrımından sonra test etiketi ve görselleri geliştirme ekibinden rol bazlı ayrılır. Testte hata görüldüğü için eğitim ayarı değiştirilecekse eski deney kapanır; yeni ön kayıt ve yeni deney kimliği açılır.

## Saklama, geri çekme ve olay yönetimi

Saklama süresi etik başvuru/proje veri yönetim planında tarih olarak yazılır. Süre dolunca ham görsel güvenli silinir veya yeni açık izinle anonim arşive alınır. Geri çekmede görsel ve türevleri veri sürümünden çıkarılır, etkilenen checksumlar kayda alınır ve model yeniden eğitilene kadar dağıtım kararı risk sahibi tarafından değerlendirilir. Kişisel veri sızıntısı şüphesinde toplama durdurulur, erişim logları korunur ve kurum prosedürü uygulanır.

## Yayınlama

Örnek görsel yayınlamak ayrı, açık izin gerektirir. Model kartı toplulaştırılmış dağılım ve hata analizini yayımlar; ham fotoğraf, onam belgesi veya kimlik eşlemesi repoya konmaz. Lisansı belirsiz internet görselleri, arama motoru kazıması ve sosyal medya içeriği kullanılmaz.
