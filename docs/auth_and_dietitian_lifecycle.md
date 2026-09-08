# NutriSense Kimlik Doğrulama ve Diyetisyen Yaşam Döngüsü

## Ürün kararı ve kimlik sınırı

NutriSense uygulamasının kanonik çalışma biçimi **gerçek hesap modu**dur. Besin geçmişi, hesap/veri silme ve kullanıcının seçtiği diyetisyenle rapor paylaşımı kalıcı bir kullanıcı hesabı gerektirir. Uygulama ilk açılışta doğrudan ana kabuğu göstermez; güvenli oturum doğrulamasından sonra Login/Register veya `AppShell` açılır.

Araştırma kimliği hesap kimliğinden ayrıdır. Anket gönderimlerinde `users.id` kullanılmaz. Mobil uygulama yalnız araştırma alanı için rastgele bir `participant_id` üretir ve bu takma kimliği `SharedPreferences` içinde tutar. Bu değer erişim anahtarı değildir ve access/refresh token ile aynı depoya veya aynı JSON alanına yazılmaz. Eski bekleyen anketlerdeki `user_id` alanı senkronizasyondan önce kaldırılıp anonim `participant_id` ile değiştirilir. Kullanılabilirlik oturumları da araştırmacının verdiği takma `participant_id` ile çalışır.

Bu teknik ayrım etik kurul kararı veya katılımcı onayı yerine geçmez. Etik kurul/onam yoksa saha verisi toplanmamalıdır. Araştırma istatistik ve ham veri dışa aktarma endpointleri `X-Research-Export-Token` olmadan 403 döner; production anahtarı yalnız sunucu secret store'unda tutulmalıdır.

## Mobil auth state machine

| Durum | Anlam | Görünen ekran |
|---|---|---|
| `unknown` | Controller henüz başlamadı | Geçici yükleme |
| `loading` | Güvenli kasa/API işlemi sürüyor | Erişilebilir ilerleme göstergesi |
| `unauthenticated` | Oturum yok | Login; buradan Register |
| `authenticated` | Token ve aktif kullanıcı `/users/me` ile doğrulandı | `AppShell` |
| `locked` | Saklanan oturum doğrulanamadı veya süresi doldu | Açık süre-doldu mesajı ve yeniden giriş |

Access ve refresh tokenlar `flutter_secure_storage` ile platform kasasında tutulur. Android'de paket tarafından sağlanan modern şifreli kasa, iOS'ta Keychain kullanılır. Eski `SharedPreferences` token anahtarları ilk okumada ve çıkışta temizlenir. Araştırma takma kimliği token değildir ve ayrı tutulur.

Tek Dio istemcisi:

- access tokenı `Authorization: Bearer` başlığına ekler;
- aynı anda gelen 401 yanıtlarında tek refresh isteğini paylaşır;
- yenilenen access ve refresh tokenı atomik oturum nesnesi olarak yazar;
- refresh başarısızsa yerel oturumu temizler ve tekrar 401 döngüsü oluşturmaz;
- yanlış hesap-silme parolası gibi işleme özgü 401'i refresh tetikleyicisi yapmaz;
- logout sırasında sunucudaki refresh tokenı revoke etmeyi dener ve sonuçtan bağımsız olarak cihaz kasasını temizler.

Parola sıfırlama uygulanmamıştır. Mobil arayüz bunu “henüz kullanılamıyor” olarak açıkça gösterir; backend 501 döner. Çalışıyormuş gibi başarı mesajı verilmez.

## Backend oturum güvenliği

Yeni parolalar Argon2id ile hashlenir. Geçiş sürecindeki mevcut bcrypt karmaları doğrulanabilir. Mobil ve backend aynı asgari kuralı uygular: en az 8 karakter, en az bir harf ve bir rakam.

Access token `type=access`; refresh token `type=refresh`, `jti`, kullanıcı ve expiry içerir. Refresh tokenın ham değeri veritabanında tutulmaz, SHA-256 özeti tutulur. Refresh çağrısı eski kaydı revoke eder ve yeni `jti` üretir; aynı tokenın tekrar kullanımı reddedilir. Logout geçerli refresh kaydını revoke eder. Aktif olmayan veya silinmiş kullanıcı için refresh ve korumalı endpointler başarısız olur.

`APP_ENVIRONMENT=prod` iken boş veya varsayılan `JWT_SECRET_KEY` ile servis başlamaz. Secret mobil binary'ye, Git'e veya dokümana yazılmaz.

Login korumaları:

- IP + geri döndürülemez e-posta özeti anahtarında 15 dakikada 5 başarısız deneme sınırı;
- var olmayan kullanıcı ile yanlış parola aynı 401 mesajını üretir;
- audit kaydında ham parola ve ham e-posta yoktur;
- validation hata gövdeleri ham girdiyi veya Pydantic exception nesnesini geri yansıtmaz.

Production'da in-memory rate limit yerine Redis/API gateway gibi çok-instance uyumlu bir sayaç kullanılmalı; güvenilir proxy zinciri ve IP başlıkları ayrıca yapılandırılmalıdır.

## Hesap ve veri silme

Kullanıcı mobilde parolasını ve tam olarak `HESABIMI SIL` ifadesini girer. Backend parolayı yeniden doğrular; sonra refresh tokenları, diyetisyen atamaları, rapor kayıtları ve ORM cascade ile besin günlüklerini siler. Başarılı işlem geri döndürülemez ve `account_deleted` audit olayı oluşturur. Yanlış parola hesabı silmez ve mobil güvenli oturumu temizlemez.

Production için yasal saklama/audit politikası, yedeklerden silme takvimi ve dış sağlayıcılara gönderilmiş raporların kapsamı kurum tarafından ayrıca onaylanmalıdır.

## Diyetisyen yaşam döngüsü

1. Kullanıcı kayıtlı diyetisyenin e-posta adresini girer.
2. Backend yalnız aktif ve en az bir doğrulanmış iletişim kanalına sahip diyetisyeni kabul eder.
3. Atama `pending` oluşur; aynı kullanıcının ikinci aktif ataması 409 ile reddedilir.
4. Yalnız atamanın sahibi onaylayabilir. Onay `approved` durumuna geçer ve kullanıcıya bağlanır.
5. Yalnız onaylı atama rapor önizleyebilir; alıcı mobilde maskeli gösterilir.
6. Önizleme tarih aralığı, kanallar, maskeli alıcı ve gönderilecek gerçek kayıt kümesini bir `consent_context_hash` değerine bağlar.
7. Kullanıcı erişilebilir özeti gördükten/dinledikten sonra her gönderim için ayrı açık onay verir. `consent: true`, preview hash ve `Idempotency-Key` zorunludur.
8. Yalnız doğrulanmış e-posta/telefon kanalı bildirim servisine verilir. Kanal sonuçları birbirinden bağımsız saklanır.
9. Kullanıcı pending veya approved atamayı iptal edebilir; durum `cancelled` olur ve aktif bağ kaldırılır.

Başka kullanıcının UUID'siyle geçmiş okuma 403; başka kullanıcının raporunu görme/retry etme ve assignment UUID'sini onaylama 404 döner. Otomatik/periyodik rapor paylaşımı yoktur; her gönderim kullanıcı arayüzünde önizleme sonrası ayrı checkbox onayı gerektirir. Sağlayıcı kabulü nihai insan teslimatı olarak gösterilmez; e-posta/SMS kısmi sonuçları ayrı sunulur.

## Tehdit özeti

| Tehdit | Kontrol | Kalan production işi |
|---|---|---|
| Mobil depodan token çalınması | Platform güvenli kasası; SharedPreferences token temizliği | Root/jailbreak ve cihaz bütünlüğü kararı |
| Refresh replay | Hashli kayıt, `jti`, rotation, revoke, tek refresh kuyruğu | Token ailesi replay alarmı ve tüm aileyi revoke |
| Kullanıcı keşfi/brute force | Genel hata, rate limit, hashli audit | Dağıtık rate limit, alarm ve WAF |
| IDOR | Token kullanıcısı ile kaynak sahibini karşılaştırma | Tüm yeni endpointlerde aynı policy testi |
| İstenmeyen sağlık verisi paylaşımı | Approved assignment + doğrulanmış kanal + her gönderimde açık rıza | Kurumsal DPA, retention ve sağlayıcı sözleşmeleri |
| Araştırma/hesap kimliği birleşmesi | Ayrı `participant_id`; legacy alan temizliği | Etik kurul onayı, kod anahtarı sorumluluğu ve silme planı |
| Secret sızıntısı | Production default-secret reddi; `.gitignore` | Secret manager, rotasyon ve CI secret scan |

## Yerel demo ve test

Gerçek kullanıcı veya sağlık verisi kullanmayın. E-posta/SMS gönderimi için sandbox fake kullanılmalıdır.

Depo kökünden, Windows PowerShell ile:

```powershell
py -3 scripts/dev_setup.py
docker compose -f backend/docker-compose.yml up -d --build --wait
flutter pub get
flutter run --flavor dev --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Bu komut Android emülatörü içindir. iOS ve fiziksel telefon için [kurulum rehberini](developer_setup.md) kullanın. SQLite test veritabanı örneklerini geliştirme sunucusu kurulumu olarak kullanmayın.

Test hesabı uygulamadaki **Hesap Oluştur** ekranından, yalnız sentetik ad ve `example.com` e-posta adresiyle oluşturulur. Diyetisyen testi için veritabanına sentetik, `email_verified=true` bir sandbox kaydı fixture/migration ile eklenmelidir; production doğrulaması taklit edilmemelidir.

Tekrar üretim komutları:

```powershell
cd C:\projeler\NutriSense\backend
.\venv\Scripts\python.exe -m pytest -q

cd C:\projeler\NutriSense
flutter pub get
flutter analyze --no-pub
flutter test --no-pub test\contract\api_contract_test.dart test\widget_test.dart
flutter build apk --debug --flavor dev --no-pub
```

## Production kabul kapıları

- MySQL migration `001` ve `002` yedekli ortamda uygulanmış olmalı.
- JWT ve araştırma export anahtarları secret manager'dan gelmeli; loglarda görünmemeli.
- SMTP/Twilio sandbox kanıtından sonra doğrulanmış gönderici ve veri işleyen sözleşmeleri tamamlanmalı.
- Diyetisyen kimliği, e-posta ve telefon doğrulama süreci kurum tarafından tanımlanmalı.
- KVKK aydınlatma, açık rıza, saklama/silme ve veri ihlali prosedürü hukuk/etik kurulca onaylanmalı.
- iOS Keychain entitlements ve Android backup/restore davranışı gerçek cihazlarda doğrulanmalı.
- Dağıtık rate limit, audit log erişim kontrolü, merkezi izleme ve alarm kurulmalı.
- Saha araştırması başlamadan etik kurul kararı, katılımcı onamı ve anonim veri sözlüğü sürümlenmiş olmalı.

## Doğrulanan son durum (2026-07-17)

- Backend yaşam döngüsü, IDOR, rıza, rate-limit ve araştırma kimliği ayrımı testleri: **19/19 geçti**.
- Flutter unit/widget/contract/erişilebilirlik testleri: **90/90 geçti**.
- Flutter analiz: **0 error, 0 warning**; 100 adet engelleyici olmayan info P2/P3 teknik borç olarak kayıtlıdır.
- OpenAPI drift kontrolü geçti.
- Android debug APK hem temiz hem son kaynakla incremental derlemede başarıyla üretildi.
