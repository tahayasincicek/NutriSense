# Google Play Data Safety teknik taslağı

Durum: **YAYIN BLOKER'I — Play Console'a doğrudan girilmez**

Bu belge kod ve mevcut veri mimarisine dayalı teknik envanterdir. Nihai
yanıtlar production sağlayıcıları, barındırma ülkeleri, saklama süreleri,
gizlilik politikası ve üniversite veri sorumlusu/hukuk incelemesiyle
doğrulanmalıdır.

## Veri kategorileri

| Veri | Amaç | Saklama/paylaşım özeti | Kullanıcı kontrolü |
|---|---|---|---|
| Ad ve e-posta | Hesap ve oturum | Backend hesabında; erişim kontrolü gerekir | Düzeltme, dışa aktarma ve hesap silme |
| Kimlik doğrulama verisi | Oturum güvenliği | Parola özeti sunucuda; token cihaz güvenli deposunda | Logout ve token iptali |
| Beslenme günlüğü | Geçmiş ve kullanıcı onaylı rapor | Backend veritabanında kullanıcı UUID'sine bağlı | Düzeltme/silme ve rapor onayı |
| Kamera görüntüsü | Besin adayını analiz etme | Varsayılan kalıcı saklama yok; yapılandırmaya göre işlem sağlayıcısına aktarılabilir | İzin reddi ve manuel giriş |
| Diyetisyen iletişimi | Kullanıcı onaylı rapor gönderimi | Doğrulanmış alıcı ve kanal durumları sunucuda | Atama/iptal ve her gönderimde açık onay |
| Araştırma yanıtı | Etik onaylı HCI araştırması | Ürün hesabından ayrı pseudonym; etik kapı olmadan gerçek veri yok | Onam geri çekme koduyla silme |
| Tanılama verisi | Hata teşhisi | Production crash/analytics sağlayıcısı şu anda doğrulanmış değil | Sağlayıcı eklenirse form yeniden değerlendirilir |

## Olası üçüncü taraf işleyiciler

Yalnız production ortamında gerçekten yapılandırılıp sözleşme/hukuk incelemesi
tamamlananlar beyan edilir:

- Görüntü tanıma sağlayıcısı: gönderilen görüntü ve teknik istek metadatası.
- Besin verisi sağlayıcısı: normalize edilmiş besin sorgusu.
- E-posta/SMS sağlayıcısı: minimum rapor içeriği ve doğrulanmış alıcı.
- Barındırma/veritabanı sağlayıcısı: hesap, günlük ve audit verisi.

Google Vision, Nutritionix, Twilio, SMTP veya Crashlytics adı yalnız gerçek
production konfigürasyonu ve veri akışı doğrulanırsa Play Console'da seçilir.

## Güvenlik beyanı için teknik dayanak

- Staging/prod API URL'si HTTPS değilse uygulama başlamaz.
- Production Android manifesti cleartext trafiği reddeder.
- Release debug anahtarıyla imzalanmaz; kurum upload key'i gerekir.
- Android yedekleme ve cihazlar arası aktarım uygulama verisi için kapalıdır.
- Kamera, mikrofon ve token değerlerinin loglanmaması gerekir.
- Hesap silme, araştırma verisi silme ve diyetisyen paylaşım onayı test
  kanıtları release kapısına dahildir.

Bu kontroller uçtan uca şifreleme, belirli bir disk şifreleme algoritması veya
kesin hukuki uyum garantisi anlamına gelmez.

## Nihai formdan önce karar gerekenler

1. Veri sorumlusu, iletişim adresi ve gerçek gizlilik politikası URL'si.
2. Production backend/DB ülkesi ve tüm alt işleyenler.
3. Her veri sınıfı için onaylı retention ve silme süresi.
4. Görüntünün cloud sağlayıcısına aktarılıp aktarılmayacağı.
5. Crash/analytics SDK'larının release'te açık olup olmayacağı.
6. Hesap oluşturmanın zorunlu olup olmadığı ve veri silme URL/akışı.
7. Araştırma modunun mağaza build'inde bulunup bulunmayacağı.
