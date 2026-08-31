# NutriSense Manuel Ekran Okuyucu Test Planı

## Amaç ve kanıt kuralı

Amaç, görme engelli bir kullanıcının ana görevleri ekranı görmeden bağımsız tamamlayabildiğini gerçek cihazda doğrulamaktır. Otomasyon yalnız ön kontrol sağlar; bu dosyada bir adım gerçekten uygulanmadıkça **GEÇTİ** işaretlenmez.

Başlangıç durumu (27 Temmuz 2026): **Tüm manuel koşular NOT RUN.** Android 16 emülatörü bağlıdır fakat bu, fiziksel TalkBack kanıtı değildir. iOS kaynak iskeleti vardır; macOS/Xcode ve gerçek iPhone olmadığı için iOS/VoiceOver koşuları **BLOCKED** durumundadır.

Gerçek sağlık verisi, gerçek diyetisyen iletişim bilgisi veya gerçek alıcı kullanılmaz. Yalnız açıkça `TEST/SYNTHETIC` olarak işaretlenmiş hesap, besin kayıtları ve sandbox alıcıları kullanılır.

## Test matrisi

| Kimlik | Platform/cihaz | Ekran okuyucu | Metin | Yön | Ses bağlantısı | Ağ | Durum |
|---|---|---|---|---|---|---|---|
| A1 | Fiziksel Android, desteklenen en eski sürüm | TalkBack güncel | 100% | Dikey | Hoparlör | Online | NOT RUN |
| A2 | Fiziksel Android, güncel sürüm | TalkBack güncel | 200% | Dikey/yatay | Kablolu veya USB kulaklık | Online | NOT RUN |
| A3 | Fiziksel Android, güncel sürüm | TalkBack güncel | 200% | Dikey | Bluetooth kulaklık | Offline/kesintili | NOT RUN |
| A4 | Android emülatör API 36 | TalkBack | 100%/200% | Dikey/yatay | Sanal | Online | NOT RUN; ön kontrol |
| I1 | Desteklenen iPhone/iOS | VoiceOver | 100% | Dikey | Hoparlör | Online | BLOCKED: Mac/iPhone yok, Xcode build yok |
| I2 | Desteklenen iPhone/iOS | VoiceOver | En büyük desteklenen ölçek | Dikey/yatay | Bluetooth | Kesintili | BLOCKED: Mac/iPhone yok, Xcode build yok |
| L1 | Fiziksel Android | Ekran okuyucu kapalı | 200%, yüksek kontrast, reduce motion | Dikey/yatay | Hoparlör | Online | NOT RUN |

Her koşuda cihaz modeli, OS build, TalkBack/VoiceOver sürümü, TTS motoru/sesi, uygulama commit SHA'sı ve backend sürümü kaydedilir.

## Önkoşullar

1. Temiz debug veya imzalı test build'i kur.
2. Sandbox backend, test veritabanı, mail sandbox ve SMS mock transport kullan.
3. Bir sentetik kullanıcı, bir doğrulanmış sentetik diyetisyen ve en az iki onaylı fixture besin kaydı hazırla.
4. Kamera hedefi için kişisel veri içermeyen lisanslı test görselleri/yiyecek nesneleri kullan.
5. Ekran kaydı alınacaksa bildirimleri kapat, e-posta/telefonu maskele ve konuşma dökümünde kimlik bilgisi bırakma.
6. Başlangıçta önbelleği/oturumu test senaryosuna göre temizle; üretim veritabanına bağlanmadığını doğrula.
7. Test build'inin commit'ini kaydet:

```powershell
git rev-parse HEAD
flutter devices
flutter doctor -v
```

## Ortak gözlem ölçütleri

Her adımda şunları kaydet:

- odak sırası mantıklı mı ve odak görünür mü;
- kontrol adı, rolü, değeri, seçili/kapalı durumu ve ipucu doğru mu;
- aynı içerik TalkBack/VoiceOver ve TTS tarafından üst üste okunuyor mu;
- TTS sürerken mikrofon açıldığında TTS kesin olarak susuyor mu;
- dinleme başlangıç/bitiş/hata durumu ses dışı haptic veya görünür metinle de anlaşılır mı;
- geri/iptal ile güvenli biçimde çıkılabiliyor mu;
- hata sonrası klavye/dokunma alternatifi var mı;
- odak beklenmedik biçimde sayfa başına kaçıyor mu;
- 200% metinde kırpılma, üst üste binme veya yatay kayıp var mı;
- kritik eylem tek yanlış/fuzzy komutla gerçekleşiyor mu.

## Görev 1 — Kayıt ve giriş

Amaç: Kullanıcı ekranı görmeden test hesabı oluşturur, giriş yapar ve ana tarama sekmesine ulaşır.

1. Uygulamayı temiz kurulum/çıkış yapılmış durumda aç.
2. İlk odağın route adı veya anlamlı giriş başlığı olduğunu doğrula.
3. “Hesap Oluştur” kontrolüne ilerle; ad, e-posta, parola alanlarını doldur.
4. Hatalı e-posta ve kısa parola gir; hatanın alanla anlamlı ilişkili ve tekrar bulunabilir olduğunu doğrula.
5. Geçerli sentetik bilgilerle kayıt ol.
6. Çıkış yap, aynı hesapla tekrar giriş yap.
7. Şifre görünürlük düğmesinin durumunu doğru okuduğunu doğrula.
8. “Şifremi Unuttum” eyleminin çalışıyormuş gibi davranmadığını ve mevcut durumu açık söylediğini doğrula.
9. 200% ve yatay yönde tekrar et.

Geçme ölçütü: Başkasının yardımı olmadan ana ekrana ulaşılır; parola sesli ifşa edilmez; tüm hatalar düzeltilebilir. Sesle form doldurma kapsam dışıysa klavye yolu açıkça çalışmalıdır.

## Görev 2 — Besini tara, sonucu dinle, porsiyonu düzelt ve kaydet

Amaç: Kamera izninden onaylı geçmiş kaydına kadar bir tarama tamamlanır.

1. Tara sekmesinde başlık ve “Besini Tara” kontrolünü bul.
2. Kamera iznini bir koşuda kabul et, diğer koşuda reddet; kalıcı rette sistem ayarı/dokunma alternatifini doğrula.
3. Kamerayı aç; sözlü “daha aydınlık/yaklaştır/sabit tut” uyarılarının spam olmadığını gözle.
4. TTS konuşurken mikrofonu başlat; TTS'nin durduğunu doğrula.
5. Yüksek güvenli fixture'da sonucu dinle ve dokunma yoluyla düzeltme fırsatını bul.
6. Orta güvende üçten fazla aday olmadığını doğrula; “birinci seçenek” de ve seçimi kontrol et.
7. “porsiyon 150 gram” de; görünür/okunan değerin 150 g olduğunu doğrula.
8. Onay bağlamı dışında “evet” de; hiçbir kayıt oluşmamalı.
9. Onay sorusunda “evet” de veya dokunma alternatifini kullan.
10. Düşük güven/OOD koşulunda kesin kalori okunmadığını ve yeniden çekim/manuel giriş yolu sunulduğunu doğrula.
11. Mikrofon iznini reddet; sonuç dokunma yoluyla tamamlanabilmeli.
12. Geçmişe git ve tek yeni kaydı doğrula; çift kayıt olmamalı.

Geçme ölçütü: Kullanıcı görsel yardım almadan tarar, belirsizliği anlar, porsiyonu değiştirir ve yalnız açık onayla tek kayıt oluşturur.

## Görev 3 — Geçmişi dinle, düzelt ve sil

Amaç: Kullanıcı bugünkü kayıtlarını bulur ve sahip olduğu kaydı yönetir.

1. Global mikrofona basıp “bugün ne yedim” de; Geçmiş sekmesine geçişi doğrula.
2. Loading, data ve offline-cache durumlarının birbirinden ayırt edilebilir olduğunu doğrula.
3. Günlük özetini dinle.
4. Bir kaydı tek anlamlı semantik cümle olarak oku; alt ikonların aynı içeriği tekrarlamadığını doğrula.
5. Kayıt kartındaki sesli eylem düğmesine basıp “kaydı dinle”, “kaydı düzelt”, “öğünü değiştir” ve “porsiyon 150 gram” yollarını ayrı ayrı doğrula; yalnız seçili kayıt değişmeli.
6. Kaydı silmeyi seç; açık onay olmadan silinmemeli.
7. Sesli eylemde “kaydı sil” de; ilk komut yalnız ikinci onayı açmalı, kayıt durmalıdır.
8. İkinci dinlemede “evett” gibi fuzzy/gürültülü komut söyle; silme gerçekleşmemeli. Sonra “hayır” ile iptal et.
9. Komutu yeniden başlat, ayrı ve tam “evet” ile sentetik kaydı sil; “Geri al” eylemini doğrula.
10. Başka sentetik kullanıcıyla giriş yap ve ilk kullanıcının kaydının görünmediğini doğrula.

Geçme ölçütü: Özet ve kayıtlar anlaşılır; yalnız seçili kayıt değişir; sesli/dokunmatik düzeltme ve çift onaylı silme güvenli çalışır; kullanıcı izolasyonu korunur.

## Görev 4 — Diyetisyen atama ve onay

Amaç: Kullanıcı yalnız doğrulanmış sentetik diyetisyeni seçip ilişkiyi açıkça onaylar.

1. Diyetisyen sekmesine git.
2. Atama yok durumunun açık ve eyleme dönük olduğunu doğrula.
3. Geçersiz adres gir; hata kullanıcı varlığını/özel bilgiyi ifşa etmemeli.
4. Sandbox doğrulanmış diyetisyen adresini gir.
5. Maskeli iletişim bilgisini ve “onay bekliyor” durumunu dinle.
6. Atamayı onayla; durum değişikliğinin live region/odak ile anlaşılır olduğunu doğrula.
7. İptal eylemini aç, vazgeç ve ilişkinin kaldığını doğrula.

Geçme ölçütü: Yanlış kişiye otomatik atama olmaz; doğrulanmış/maskeli alıcı ve onay durumu bağımsız anlaşılır.

## Görev 5 — Raporu önizle, açık onayla ve sandbox'a gönder

Amaç: Kullanıcı alıcıyı, dönemi, kayıt sayısını ve kanalları doğrular; kritik gönderimi çift onayla yapar.

1. “Raporu Önizle ve Gönder” eylemini aç.
2. Dönem, onaylı kayıt sayısı, e-posta/SMS kanalları ve maskeli alıcıyı dinle.
3. “Özeti Dinle”yi çalıştır; TalkBack/VoiceOver ile çift konuşmayı gözle.
4. Onay checkbox'ı seçilmeden gönderimin kapalı olduğunu doğrula.
5. Checkbox'ı seç ve “Sesli Rapor Komutu”na bas.
6. “raporu gönder” gibi fuzzy/yanlış komut söyle; gönderim başlamamalı.
7. Tam “rapor gönder” de; uygulama ikinci onay istemeli.
8. 12 saniye bekleyip “evet” de; timeout nedeniyle gönderim başlamamalı.
9. Komutu yeniden ver ve süre içinde tam “evet” de; yalnız bir sandbox işi oluşmalı.
10. Aynı butona/komuta iki kez hızlıca bas; duplicate mesaj oluşmamalı.
11. E-posta başarı/SMS hata fixture'ında “kısmi başarısız” durumunun doğru okunduğunu doğrula.
12. Mikrofonu reddederek checkbox + dokunma gönderim yolunu tamamla.

Geçme ölçütü: Yanlış/fuzzy komut gönderimi tetiklemez; açık özet ve tek kullanımlık ikinci onay olmadan mesaj oluşmaz; sonuç kanallara göre doğrudur.

## Görev 6 — Anket, erişilebilirlik ayarları ve çıkış

Amaç: Kullanıcı araştırma formunu ve tercihleri yönetir, oturumu güvenle kapatır.

1. Anketi aç; soru numarası, grup ve cevap kontrollerinin sırasını doğrula.
2. Kapalı uçlu soruları ekran okuyucu ile yanıtla.
3. Açık metinde sesli giriş başlat; TTS'nin sustuğunu ve dinleme durumunun anlaşılır olduğunu doğrula.
4. Mikrofon reddinde klavye alternatifiyle devam et.
5. Reduce motion açıkken geçiş animasyonlarının azaltıldığını doğrula.
6. Ayarlar sekmesinde konuşma hızı, haptic ve yüksek kontrast kontrollerinin ad/rol/değerini doğrula.
7. Türkçe TTS sesi olmayan cihaz/emülatör koşulunda kullanıcıya anlaşılır fallback sağlanıp sağlanmadığını kaydet.
8. Ayarlar mikrofonunda “çıkış yap” de; ilk komutun yalnız ikinci onayı açtığını doğrula.
9. İkinci dinlemede önce “evett” de; oturum kapanmamalı. Ardından yeniden başlatıp tam “evet” de.
10. Geri ile korumalı AppShell'e dönülemediğini ve yerel hassas önbelleğin temizlendiğini doğrula. Aynı görevi dokunmatik “Çıkış Yap” alternatifiyle tekrar et.

Geçme ölçütü: Zorunlu soruların tamamı erişilebilir; mikrofon olmadan alternatif vardır; ayarlar anlaşılır; çıkış oturumu atomik kapatır.

## Gürültü, timeout ve ses yönlendirme alt testleri

- Sessiz ortam, konuşmalı oda ve sokak gürültüsü kaydı olmadan canlı ortamda dene.
- Kısmi sonucu durup düzelterek söyle; kritik eylem yalnız final ve kesin komutla çalışmalı.
- Mikrofon açıkken geri/iptal yap; akış bekleyen dinleyici bırakmamalı.
- Kablolu kulaklık çıkarma ve Bluetooth bağlantı/kopma sırasında TTS'nin özel hoparlöre sızıp sızmadığını kaydet.
- Uygulamayı TTS/STT sırasında arka plana al ve geri getir; konuşma kendiliğinden tehlikeli eylemi sürdürmemeli.
- Uçak modunda tarama yap; doğrulanmış TFLite yoksa sahte başarı değil, manuel seçenek gösterilmeli.

## Bulguyu kaydetme şablonu

| Alan | Değer |
|---|---|
| Bulgu kimliği | A11Y-YYYY-NNN |
| Commit SHA |  |
| Matris koşulu |  |
| Görev/adım |  |
| Beklenen |  |
| Gerçekleşen |  |
| Tekrar üretim |  |
| Etki | Kritik / Yüksek / Orta / Düşük |
| WCAG/mobil kriter |  |
| Ekran kaydı/log | Kişisel veri içermeyen güvenli artefakt yolu |
| Durum | Açık / Düzeltildi / Yeniden test |

## Koşu sonucu tablosu

| Tarih | Commit | Koşul | Görev 1 | Görev 2 | Görev 3 | Görev 4 | Görev 5 | Görev 6 | Test eden |
|---|---|---|---|---|---|---|---|---|---|
| 19.07.2026 | Değişiklik seti doğrulama öncesi | Otomatik ön kontrol | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN | — |

## Sürüm kabul kapısı

- Altı görevin A1 ve A2 koşullarında P0/P1 erişilebilirlik hatası olmadan tamamlanması.
- A3 offline/Bluetooth koşulunda veri kaybı, ses gizliliği ihlali veya kritik yanlış komut olmaması.
- I1 en az bir kez geçmeden iOS erişilebilirliği iddia edilmemesi.
- 200% metin, dikey/yatay, reduce motion ve yüksek kontrast kontrollerinin kritik ekranlarda geçmesi.
- Tüm kritik eylemlerde dokunma/klavye alternatifi ve kesin onay bulunması.
- Kanıt dosyalarının kişisel/sağlık verisi içermeden CI veya kontrollü araştırma artefakt alanında saklanması.
