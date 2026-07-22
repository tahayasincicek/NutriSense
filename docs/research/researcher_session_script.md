# Araştırmacı oturum scripti ve müdahale kuralları

## Oturum öncesi

1. Etik kapının `approved` olduğunu ve gerçek referansların sunucuda tanımlı olduğunu doğrula; ekranda secret gösterme.
2. Uygulama/protokol/anket/görev sürümlerini kaydet.
3. Sentetik hesap, test yiyeceği, sandbox diyetisyen ve ağ/offline senaryosunu hazırla.
4. Erişilebilir fiziksel yol, sandalye/masa, priz, kulaklık ve mola alanını kontrol et.
5. Kamera alanında yüz, belge, isim veya adres bulunmadığını doğrula.
6. Gerçek katılımcı gelmeden deneme verisini sil; sentetik fixture'ı sonuç analizi dışında tut.

## Standart açılış

“Bugün uygulamayı değil, uygulamanın size ne kadar iyi hizmet ettiğini değerlendiriyoruz; sizin performansınız test edilmiyor. İstediğiniz an durabilir, mola verebilir veya soruyu atlayabilirsiniz. Uygulamanın besin/kalori sonucu tahmindir ve yeme ya da tedavi kararı için kullanılmayacaktır. Görev sırasında ne düşündüğünüzü söylemeniz isteğe bağlıdır; ses kaydı yapılmaz. Yardıma ihtiyaç duyarsanız söyleyin; verdiğim yardım düzeyi not edilir.”

Bilgilendirme/onam kontrol listesini tamamla. Geri çekilme kodunu tercih edilen erişilebilir formatta ver; araştırmacı kopyasını sonuç notuna yazma.

## Müdahale basamakları

Araştırmacı ilk 10 saniye güvenlik riski yoksa müdahale etmez. Katılımcı yardım ister veya maksimum görev süresine yaklaşırsa sırayla:

1. `prompt`: “Bu görevde bir sonraki adımı nasıl bulabileceğinizi düşünün.” İşlev adı söylenmez.
2. `partial`: ilgili ekran/alan adı söylenir, kontrolün yeri söylenmez.
3. `full`: gerekli kontrol ve eylem açıkça tarif edilir.

Her basamak `assistance_level` alanına en yüksek verilen düzey olarak yazılır. Araştırmacı uygulamayı katılımcı yerine kullanırsa görev bağımsız başarı değildir. Güvenlik için fiziksel müdahale ayrı `safety_intervention` notuyla abort olarak kaydedilir.

## Hata tanımı

Önceden tanımlı yanlış ekran/işlem, yanlış besin adayını onaylamaya çalışma, gönderim önizlemesini doğrulamadan ilerleme, yanlış kaydı silmeye çalışma veya komutu üç kez tanıtamama bir hata sayılır. Aynı kesintisiz yanlış eylem bir kez sayılır. Sistem/network hatası kullanıcı hatası değildir; `technical_failure` abort nedenidir.

## Görev kapatma

Görev başarı kriteri gerçekleştiği anda bitirilir. Monotonik sayaç otomatik durur. Maksimum süre aşılırsa araştırmacı “Bu görevi burada durduruyoruz; bu sizin hatanız değil” der, `timeout` abort ve yardım düzeyini kaydeder. Manuel süre düzeltmesi yalnız teknik sayaç arızasında ve gerekçeyle yapılır; audit kaydı oluşur.

## Yan etki ve güvenlik durdurması

Yorgunluk, baş dönmesi, yoğun kaygı, düşme/çarpma riski, yanlış sonuca dayanarak yiyecek tüketme niyeti veya mahrem veri görünmesi halinde görevi hemen durdur. Gerekiyorsa görüntüyü sil, cihazı güvenli konuma al, katılımcıya mola/bitirme seçeneği ver ve olay prosedürünü uygula. Tıbbi yorum yapma.

## Kapanış

Anketi isteğe bağlı tamamlat; açık uçlu yanıtta kişisel bilgi vermeme uyarısını oku. Uygulama sonucunun tahmini olduğunu tekrar et. Geri çekilme kanalı ve son tarihini hatırlat. Ödeme/masraf işlemini sonuç verisinden ayrı yürüt. Araştırmacı oturumdan sonra protokol sapması, teknik sorun ve eksik alan kontrolünü tamamlar; başarı metriği hesaplamaz veya katılımcıya açıklamaz.
