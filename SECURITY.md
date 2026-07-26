# NutriSense güvenlik politikası

Son teknik inceleme: **2026-07-26**

Bu belge teknik güvenlik durumunu açıklar; KVKK uygunluk görüşü, hukuk
görüşü veya etik kurul kararı değildir.

## Güvenlik açığı bildirme

Bir açıkta token, parola, kişisel veri veya sağlık/beslenme verisi bulunuyorsa
herkese açık issue açmayın ve değeri ekran görüntüsüne koymayın. GitHub
deposundaki **Security → Report a vulnerability** özel bildirimi kullanılmalıdır.
Bu özellik kapalıysa depo sahibi özel kanal tanımlayana kadar hassas ayrıntı
paylaşılmamalıdır. Alındı/hedef çözüm SLA'sı henüz kurumca belirlenmemiştir.

Desteklenen güvenlik dalı `main` dalıdır. Production dağıtımı henüz kanıtlanmış
bir desteklenen sürüm olarak ilan edilmemiştir.

## Kanıtlanmış kontroller

| Kontrol | Uygulama kanıtı | Doğrulama |
|---|---|---|
| Secret ve hassas artefakt engeli | `.gitignore`, `backend/.dockerignore` | `python scripts/security/secret_scan.py --history` |
| Production fail-closed ayarları | `backend/app/config.py` | `tests/test_security_hardening.py` |
| JWT issuer/audience/type/expiry/jti | `backend/app/middleware/auth.py` | auth ve hardening testleri |
| Refresh rotation/revocation/logout | `refresh_tokens`, auth endpointleri | auth lifecycle testleri |
| Kullanıcı sahipliği/IDOR engeli | `get_current_active_user` ve sahiplik sorguları | API izolasyon testleri |
| Görüntü sınırı ve yeniden kodlama | `_sanitized_image_base64` | bozuk/büyük/decompression testleri |
| Log redaksiyonu | `backend/app/security/logging.py` | log redaction testi |
| Rapor onayı/idempotency/alıcı doğrulama | consent, assignment, outbox modelleri | report delivery testleri |
| Veri erişimi/düzeltme/export/silme | `/api/v1/users/me*` | privacy ve auth testleri |
| Araştırma etik kapısı/çekilme | `research_mode`, consent/withdraw endpointleri | research ethics testleri |
| Dependency/container kapısı | GitHub Actions `security` işi | pip-audit ve Trivy |

## Bilinçli sınırlar

- TLS uygulama içinde sonlandırılmaz. Production `PUBLIC_BASE_URL=https://...`
  zorunludur; TLS sertifikası, protokol/cipher politikası ve proxy yapılandırması
  deployment sahibi tarafından kanıtlanmalıdır. Bu nedenle “TLS 1.3
  uygulanmıştır” denmez.
- Veritabanı disk/yedek şifrelemesi altyapı sağlayıcısına bağlıdır ve depoda
  kanıtı yoktur. Bu nedenle “AES-256 ile saklanır” denmez.
- Kullanıcı sahipliği ve doğrulanmış diyetisyen ilişkisi kontrolleri vardır;
  genel amaçlı yönetici/diyetisyen kimlik sistemi tamamlanmadığı için “tam RBAC”
  iddiası kullanılmaz.
- Firebase/Crashlytics yapılandırılmamış ve kapalıdır. Mobil uygulama uzaktan
  crash verisi göndermez. Etkinleştirme; ayrı onam/politika, platform
  credentials, redaksiyon ve retention incelemesi gerektirir.
- Mevcut rate limit süreç içi bellektedir. Çok instance production için ortak
  Redis/gateway limiti gerekir.
- Şifre sıfırlama endpointi açıkça `501 Not Implemented` döndürür.
- `ios/` platform projesi ve gerçek VoiceOver cihaz kanıtı yoktur.

## Yerel doğrulama

Windows PowerShell:

```powershell
cd C:\Users\TAHA\Desktop\2209\nutrisense
python scripts/security/secret_scan.py --history
cd backend
.\venv\Scripts\python.exe scripts\security_smoke.py
.\venv\Scripts\python.exe -m pytest -q
.\venv\Scripts\python.exe -m pip_audit -r requirements.txt
cd ..
docker build --target production --tag nutrisense-backend:security-local backend
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.70.0 image --exit-code 1 --ignore-unfixed --severity HIGH,CRITICAL --scanners vuln nutrisense-backend:security-local
```

Dinamik smoke testi yalnız `APP_ENVIRONMENT=test` ve izole SQLite ile çalışır;
başka bir veritabanında veya production ortamında çalışmayı reddeder.

## Production yayın kapıları

1. `docs/security_findings_register.md` içindeki açık P1 maddeleri kapatılmalı.
2. Secret'lar yönetilen secret store'dan verilmeli ve ilk yayın öncesi
   rotasyon kaydı tutulmalı.
3. TLS/proxy, DB/yedek şifreleme ve restore-silme kanıtı alınmalı.
4. Üniversite veri sorumlusu, etik kurul ve hukuk birimi veri akışını
   onaylamalı.
5. Gerçek cihazda güvenli depolama, ağ trafiği ve log sızıntısı testi yapılmalı.
