# NutriSense — iOS mağaza kapsam notu

Durum: **BLOKE / kaynak hazır, iOS yayın kanıtı yok**

Depoda iOS kaynak iskeleti vardır; ancak Xcode build/archive, Apple signing,
gerçek VoiceOver cihaz testi ve App Store Connect yetkisi doğrulanmamıştır.
Android için doğrulanan davranışlar iOS'ta çalışıyormuş gibi tekrarlanmamalıdır.

## İzin kapsamı

Hazırlanan iOS uygulaması yalnız gerçekten kullanılan izinleri açık Türkçe
gerekçelerle içerir:

- Kamera: yiyecek görüntüsünü analiz etmek için.
- Mikrofon ve konuşma tanıma: kullanıcı sesli komutu başlattığında.

Fotoğraf kitaplığına kayıt ve arka planda ses çalma mevcut ürün gereksinimi
değildir; ilgili entitlement/izinler kanıtlanmış özellik olmadan eklenmemelidir.
Görüntünün çevrimiçi hizmete aktarılması ve varsayılan saklamama davranışı,
uygulama içi aydınlatma ile gizlilik politikasında aynı şekilde açıklanmalıdır.

## Yayın öncesi zorunlu kanıt

- Gerçek bundle ID ve Apple takım/sözleşme sahibi.
- Distribution sertifikası ve güvenli signing süreci.
- VoiceOver, %200 metin, koyu tema, izin reddi, kamera lifecycle ve Türkçe
  TTS/STT için fiziksel iPhone test kaydı.
- Gerçek gizlilik politikası ve App Privacy yanıtları.
- Archive/TestFlight smoke ve crash/log PII incelemesi.
- Production backend ve üçüncü taraf aktarımına göre App Privacy formu.
- Uygulama içinden hesap silme/dışa aktarma ve support akışının iPhone kanıtı.

## App Privacy teknik taslak

Nihai etiket değildir. Production konfigürasyonuna göre en az şu kategoriler
yeniden değerlendirilmelidir:

- Contact Info: hesap adı/e-postası.
- Identifiers: kullanıcı UUID'si ve auth/audit kimlikleri.
- Health & Fitness veya User Content: kullanıcı onaylı beslenme günlüğü.
- Photos or Videos: görüntü yalnız analiz sırasında cloud sağlayıcısına
  aktarılıyorsa.
- Other User Content: araştırma anketinin açık uçlu yanıtları yalnız etik modda.
- Diagnostics: Crashlytics/analytics eklenirse; şu anda doğrulanmış SDK yoktur.

Verinin kullanıcıyla ilişkilendirilmesi, tracking, üçüncü taraf paylaşımı,
saklama ülkesi ve silme süreleri üniversite veri sorumlusu/hukuk birimi
tarafından production akışıyla doğrulanmalıdır.

Gerçek support e-postası, support URL'si ve privacy URL'si henüz sağlanmamıştır;
placeholder URL mağazaya girilemez.

“TÜBİTAK destekli”, “WCAG uyumlu”, belirli besin sayısı, doğrulanmamış model
başarısı veya “KVKK uyum garantisi” kanıt ve kurum onayı olmadan kullanılamaz.
