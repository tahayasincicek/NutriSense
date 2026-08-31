# NutriSense ortam matrisi

Durum: **yerel ve test yapılandırmaları çalıştırılabilir; local staging-benzeri
ortam hazırlanmıştır; gerçek staging ve production kurulmamıştır.**

Secret değerleri bu belgede ve mobil binary'de tutulmaz. Sunucu secret'ları
environment/secret store ile enjekte edilir. Mobil `dart-define` yalnız public
URL ve feature bilgisini taşıyabilir.

| Özellik | Local | Test/CI | Staging | Production |
|---|---|---|---|---|
| `APP_ENVIRONMENT` | `local`/`dev` | `test` | `staging` | `prod` |
| API URL | `http://10.0.2.2:8000/api/v1` veya localhost | süreç içi test istemcisi | kurumun HTTPS staging alan adı; yerel Compose istisnası `http://localhost:8000` | doğrulanmış HTTPS alan adı gerekli |
| Veritabanı | geliştirici MySQL; hızlı unit test için SQLite | izole SQLite ve migration testleri; Compose smoke için MySQL | ayrı MySQL, yalnız sentetik veri | yönetilen/harici MySQL, yedek ve PITR gerekli |
| CORS | açıkça listelenen local origin'ler | `testserver` | yalnız staging istemcileri | yalnız doğrulanmış production istemcileri |
| Vision | varsayılan `disabled`; geliştirici mock'u ayrı profil | disabled/fixture | disabled veya onaylı sandbox | yalnız secret store kimliği ve aktarım onayıyla `google` |
| Nutrition | `verified_local` veya fixture | fixture | disabled/fixture/sandbox | lisanslı `nutritionix`, `verified_local` veya `hybrid` |
| E-posta/SMS | Mailpit ve mock transport | mock | sandbox + alıcı allowlist | doğrulanmış provider ve alıcı/onam kontrolleri |
| Araştırma modu | disabled/synthetic | synthetic | **yalnız synthetic** | etik kapılar tamamlanırsa ayrı approved ortam |
| Log | geliştirici text/JSON, PII redaction | JSON | JSON INFO | JSON INFO/WARNING, merkezi erişim kontrolü |
| API docs | açık olabilir | açık | kapalı | kapalı |
| Metrik endpointi | opsiyonel | testli | güçlü operasyon token'ı ile | private network + operasyon kimliği |
| Migration | geliştirici `apply` seçebilir | up/down/up | ayrı job `upgrade`; uygulama yalnız `verify` | backup sonrası ayrı tekil job; uygulama yalnız `verify` |
| ML artefaktı | yoksa özellik kapalı | checksum test fixture | HTTPS + SHA-256 veya disabled | immutable artefakt deposu + SHA-256 |
| Gerçek kullanıcı/sağlık verisi | kullanılmamalı | yasak | yasak | hukuk/etik/güvenlik onaylarından sonra |

## Provider davranış sözleşmesi

- Required olarak etkinleştirilen provider'ın kimliği eksikse uygulama startup'ta
  fail-closed davranır.
- Optional provider `disabled` ise sahte başarı üretilmez.
  `/health/capabilities` yalnız `enabled` ve mod bilgisini döndürür; anahtar
  veya kimlik bilgisi döndürmez.
- Mobil arayüz provider kapalı/hatalı olduğunda hizmetin kullanılamadığını
  söylemeli ve varsa manuel giriş/offline seçeneğini sunmalıdır.
- Google/Nutritionix/Twilio/SMTP secret'ları Flutter yapılandırmasına girmez.

## Production karar kapıları

Aşağıdakiler bilinmediği için placeholder ile aşılmaz:

1. gerçek domain, TLS sertifikası ve CORS origin'leri;
2. barındırma sağlayıcısı, bölge ve yurtdışı aktarım kararı;
3. yönetilen DB, şifreleme, backup/PITR ve erişim politikası;
4. provider sözleşmeleri ve onam/hukuki dayanak;
5. alert hedefleri ve nöbet sahibi;
6. RPO/RTO'nun kurum tarafından onayı;
7. mobil production API URL'si ve API sürüm uyumluluk kanıtı.

