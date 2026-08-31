# NutriSense deployment runbook

## Kanıtlanan durum

Backend için digest ile sabitlenmiş Python base image, hash-kilitli Python
bağımlılıkları, UID/GID 10001 non-root çalışma, read-only root filesystem,
capability drop, health/readiness probe, graceful shutdown ve ayrı migration
job hazırlanmıştır. `backend/compose.staging.yml` yalnız sentetik veriyle
staging-benzeri yerel sistemi kurar.

**Gerçek domain, TLS, cloud kaynağı veya production deploy yoktur. Bu nedenle
NutriSense production hazır değildir ve production'a dağıtılmamıştır.**

### 27 Temmuz 2026 yerel doğrulama kaydı

- Windows 11 + Docker Desktop'ta `staging_up.ps1`: **PASS**
- `/health/live`, `/health/ready`, capability ve korumalı metrics smoke:
  **PASS**
- backend container: `user=10001:10001`, read-only root, all capabilities
  dropped, health `healthy`
- temiz MySQL migration: **PASS**
- MySQL son revision `downgrade -1` → `upgrade head`: **PASS**
- sentetik backup → ayrı DB restore: **PASS**, 17/17 tablo
- backend temel testleri: **82 passed**; opt-in Mailpit HTML/plain-text sandbox
  E2E: **1 passed**
- flake8, Compose/YAML parse, deployment checks, OpenAPI drift: **PASS**
- hash-kilitli Python bağımlılık audit'i Linux ortamında: bilinen zafiyet yok
- SBOM: 70 component; manifest durumu: `BUILT_NOT_DEPLOYED`
- Docker Scout yerel taraması Docker ID istediği için çalıştırılamadı.
  Kimlik gerektirmeyen Trivy taraması CI'da fail-closed kapıdır; CI sonucu
  görülmeden container zafiyetsiz sayılmaz.

## Windows 11'de tek komut staging-benzeri ortam

Gerekenler: güncel Docker Desktop (Linux containers), Git ve Python launcher.

```powershell
Set-Location C:\Users\TAHA\Desktop\2209\nutrisense\backend
powershell -ExecutionPolicy Bypass -File .\scripts\staging_up.ps1
```

Script `.runtime/staging.env` içine rastgele yerel secret üretir; değerleri
ekrana yazmaz. Dosya Git tarafından ignore edilir. Başarılı durumda:

- API: `http://127.0.0.1:8000`
- Mailpit: `http://127.0.0.1:8025`
- health: `/health/live`
- readiness: `/health/ready`
- public capability: `/health/capabilities`

Backup/restore smoke:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\backup_restore_smoke.ps1
```

Kapatma, DB volume'ünü korur:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\staging_down.ps1
```

Volume'ü silmek veri kaybıdır; normal kapatma komutu bunu yapmaz. Yalnız
sentetik ortamı bilinçli sıfırlamak için hedef compose dosyası ve volume adları
önceden doğrulanarak `docker compose down --volumes` kullanılır.

## Container ve migration stratejisi

`backend/Dockerfile`:

- base image tag + SHA-256 digest ile sabitlidir;
- `requirements.lock` hash'lerini build sırasında zorunlu doğrular;
- secret veya `.env` kopyalamaz;
- uygulamayı non-root çalıştırır;
- liveness probe kullanır; readiness ayrıca DB ve migration revision'ını sınar;
- SIGTERM alır, açık istekler için sınırlı graceful shutdown uygular.

Staging/production uygulama container'ında
`MIGRATION_STARTUP_MODE=verify` zorunludur. Şema değişikliği:

1. immutable image ve SBOM üret;
2. DB backup/restore kanıtını kaydet;
3. tek bir migration job ile `alembic upgrade head` çalıştır;
4. revision kontrolü başarılıysa yeni uygulama instance'larını başlat;
5. `/health/ready` ve P0 smoke testini geçir.

Production'da uygulama startup'ında otomatik migration çalıştırılmaz. Alembic
downgrade yalnız migration gerçekten geri döndürülebilir ise ve veri kaybı
analizi yapılmışsa kullanılmalıdır. Aksi halde ileri düzeltme migration'ı
uygulanır.

## İzlenebilir build

```powershell
Set-Location C:\Users\TAHA\Desktop\2209\nutrisense
$revision = git rev-parse HEAD
docker build --target production `
  --build-arg BUILD_VERSION=0.0.0-candidate `
  --build-arg BUILD_REVISION=$revision `
  --build-arg BUILD_CREATED=manual `
  --tag "nutrisense-backend:$revision" backend
```

CI aynı revision için:

- container vulnerability scan;
- CycloneDX `sbom.cdx.json`;
- OpenAPI checksum;
- image arşivi checksum;
- `release-manifest.json` (`BUILT_NOT_DEPLOYED`)

üretir. Registry'ye gönderilecek image tag ile değil registry digest'i ile
seçilmelidir.

## Provider-bağımsız production yerleştirme

`deploy/production/deployment-spec.yaml` çalıştırılabilir cloud manifesti
değil, zorunlu güvenlik sözleşmesidir. Sağlayıcı seçilince şu alanlar gerçek
kaynaklarla eşlenmelidir:

- en az iki backend instance, rolling/blue-green rollout;
- private, dışarıdan erişilemeyen MySQL;
- secret manager;
- TLS terminasyonu ve yalnız HTTPS;
- private metrics endpointi;
- merkezi, erişim kontrollü log/metric sink;
- şifreli backup + PITR;
- outbound provider allowlist/egress kontrolü.

## CI/CD kapıları

Ana CI lint, Flutter/backend/contract/ML/analiz testleri, Alembic up/down/up,
secret scan, dependency/container taraması, sentetik Compose smoke,
backup/restore smoke, SBOM ve checksum üretimini hata gizlemeden çalıştırır.

`.github/workflows/production-readiness.yml` gerçek deploy yapmaz.
`production-approval` GitHub Environment'ında repository yöneticisi required
reviewer tanımlamalıdır. Workflow image digest, farklı rollback digest'i,
backup kanıtı ve migration revision olmadan readiness kaydı üretmez. Bu
GitHub ayarı yapılmadıkça manuel approval kapısı kurulmuş sayılmaz.

## Production rollout ve rollback

Rollout:

1. CI'ın tüm required check'leri yeşil olmalı.
2. Image digest, SBOM, tarama sonucu ve API compatibility sonucu eşleşmeli.
3. Backup alınmalı ve son restore tatbikatı geçerli olmalı.
4. Migration job tek instance olarak çalışmalı.
5. Canary/ilk instance readiness ve smoke testi geçmeli.
6. Error rate, latency, auth anomaly ve queue backlog gözlenmeli.
7. Kademeli trafik artışı sonrası release kanıtı saklanmalı.

Rollback:

1. yeni trafiği durdur;
2. doğrulanmış önceki image digest'ine dön;
3. migration geriye uyumluysa uygulama rollback'i yap;
4. veri şeması uyumsuzsa kör downgrade yapma, incident ilan et ve ileri
   düzeltme migration'ı kullan;
5. veri bozulması varsa restore kararı için veri sorumlusu ve incident
   sorumlusunun onayını al;
6. rollback sonrası smoke ve veri bütünlüğünü doğrula.

## Mobil-backend uyumluluğu

`contracts/openapi.json` kanonik sözleşmedir. Mobil consumer contract testleri
ve backend OpenAPI drift kontrolü aynı CI çalışmasında geçmelidir. Production
mobil build'e gerçek HTTPS API URL'si yalnız public config olarak verilir.
Backend geriye uyumsuz değişiklik için yeni API sürümü ve açık migration
takvimi gerektirir; sessiz fallback yoktur.
