# NutriSense operations runbook

## İşletim durumu

Bu runbook yerel/sentetik staging-benzeri ortam ve gelecekteki production
işletimi için hazırlanmıştır. Gerçek izleme platformu, alarm alıcısı ve nöbet
ekibi henüz seçilmediğinden production işletim kanıtı değildir.

## Sağlık uçları

- `GET /health/live`: süreç yaşıyor mu; harici bağımlılık kontrol etmez.
- `GET /health/ready`: DB bağlantısı, Alembic revision ve startup
  yapılandırması uygun mu.
- `GET /health/capabilities`: UI'ın dürüst degrade davranması için yalnız
  public provider/özellik modu.
- `GET /operations/metrics`: güçlü `X-Operations-Token` ve private network
  gerektirir; geçersiz isteğe endpoint varlığını ifşa etmeden 404 döner.

Readiness başarısız instance'a trafik verilmez. Provider outage readiness'i
bozmaz; uygulama manuel/offline seçeneğe degrade olur. DB veya migration drift
readiness'i bozar.

## Privacy-safe telemetry

İzin verilen düşük-kardinaliteli alanlar:

- request ID, method, route template, status class;
- latency, aktif istek, DB pool durumu;
- provider adı + `success/not_found/timeout/error/disabled`;
- outbox queue depth ve hata sınıfı;
- build version/revision.

Loglanmaması gerekenler:

- access/refresh token, parola, cookie, API key;
- e-posta, telefon, kullanıcı/katılımcı UUID'si;
- görüntü, base64, besin adı/ayrıntılı beslenme günlüğü;
- açık uçlu araştırma metni;
- provider request/response gövdesi.

Raw URL yerine route template kullanılır. Request ID yalnız izleme
korelasyonudur; kullanıcı kimliği değildir. Sentry/Crashlytics etkin değildir.
İleride etkinleştirilirse onam, veri bölgesi/aktarımı, sampling, redaction ve
retention ayrı onaylanmalıdır.

## Önerilen başlangıç alarmları

Eşikler gerçek trafik baz çizgisiyle yeniden kalibre edilir.

| Alarm | Başlangıç koşulu | İlk yanıt |
|---|---|---|
| API error rate | 5 dakika boyunca 5xx > %2 ve en az 20 istek | revision/provider/DB durumunu ayır |
| P95 latency | 10 dakika > 2 saniye | DB pool, provider timeout, CPU/bellek kontrolü |
| Provider failure | 10 dakika aynı provider hata oranı > %20 | provider'ı kapat, manuel/offline modu duyur |
| DB down | readiness 2 ardışık kontrol başarısız | trafiği kes, DB ve migration revision kontrol et |
| Queue backlog | oldest queued > 10 dk veya depth sürekli artıyor | worker/provider/allowlist kontrolü; çift gönderme yapma |
| Backup | planlanan backup gecikmesi > 1 periyot | release'i durdur, backup sistemini düzelt |
| Disk | kullanım > %80 | büyüme kaynağını incele; gelişigüzel veri silme |
| Auth anomaly | aynı kaynakta yüksek login/refresh hata artışı | rate-limit/audit kontrolü, gerekirse token revoke |

## Olay prosedürleri

### DB down veya migration drift

1. `/health/ready` hata sınıfını ve revision'ı kontrol et.
2. Yeni rollout'u durdur; migration job'ı tekrar tekrar çalıştırma.
3. DB bağlantı/pool/sertifika/kapasiteyi incele.
4. Şema drift varsa hedef ve mevcut Alembic revision'larını karşılaştır.
5. Backup kanıtı olmadan downgrade/restore yapma.
6. Düzeltme sonrası readiness, migration check ve P0 smoke çalıştır.

### Provider outage

1. Provider outcome metriğini doğrula; request gövdelerini loglama.
2. Circuit/feature flag ile etkilenen provider'ı `disabled` yap.
3. UI capability bilgisini yenilesin; sahte besin/kalori/teslimat sonucu dönme.
4. Kullanıcıya yeniden deneme, manuel giriş veya doğrulanmış offline yol sun.
5. Provider dönüşünde kontrollü sandbox smoke sonrası özelliği aç.

### Bildirim queue backlog

1. `queued/sending/partial_failed/failed` dağılımını incele.
2. Idempotency key ve provider message ID korunmadan manuel replay yapma.
3. Alıcı veya mesaj içeriğini loglara yazma.
4. Retry limiti/backoff sonrası dead-letter/manuel inceleme uygula.
5. Kısmi başarıyı tam başarı olarak işaretleme.

### Auth anomaly

1. Rate limit ve hata sınıfı değişimini doğrula.
2. PII olmadan zaman, route ve request ID korelasyonu kullan.
3. Şüpheli refresh ailesini revoke et.
4. Secret sızıntısı şüphesinde
   `docs/runbooks/security_incident_and_secret_rotation.md` prosedürünü uygula.

## Degrade modları

- Vision yok: kamera analizi başarılı sayılmaz; manuel giriş/yeniden deneme.
- Nutrition yok: sıfır kalorili başarı kaydı yok; kaynak bulunamadı durumu.
- Bildirim provider yok: outbox sonucu queued/failed; teslim edildi denmez.
- İnternet yok: yalnız doğrulanmış offline model/cache varsa kullan; kaynak ve
  güven türünü online sonuçla karıştırma.
- DB yok: mutasyon kabul edilmez; şifresiz yerel sağlık verisi kuyruğu üretme.

## Günlük/haftalık işletim kontrolleri

Günlük: readiness, error rate, provider outcomes, queue age, auth anomaly.
Haftalık: dependency/security bulguları, disk büyümesi, restore tatbikat
takvimi, retention işleri. Her release: OpenAPI drift, image/SBOM checksum,
migration ve rollback digest doğrulaması.

