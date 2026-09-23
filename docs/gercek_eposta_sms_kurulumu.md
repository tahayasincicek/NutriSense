# Gerçek e-posta ve SMS kurulumu

NutriSense gerçek e-postayı standart SMTP, gerçek SMS'i Türkiye için
iletiMerkezi veya alternatif olarak Twilio üzerinden gönderir. Kimlik
bilgileri kaynak koda veya Git deposuna yazılmaz.

## Gerekli üretim değişkenleri

Secret store veya sunucu ortamında aşağıdaki değerleri tanımlayın:

```dotenv
NOTIFICATION_MODE=production
SMS_PROVIDER_MODE=iletimerkezi

SMTP_HOST=smtp.saglayiciniz.example
SMTP_PORT=587
SMTP_USER=...
SMTP_PASSWORD=...
SMTP_FROM_NAME=NutriSense
SMTP_FROM_EMAIL=dogrulanmis-adres@example.com
SMTP_USE_TLS=false
SMTP_START_TLS=true

ILETIMERKEZI_API_KEY=...
ILETIMERKEZI_API_HASH=...
ILETIMERKEZI_SENDER=APITEST
```

Gönderici e-posta adresi SMTP sağlayıcısında doğrulanmış olmalıdır.
iletiMerkezi ücretsiz geliştirici hesabında 100 deneme SMS kredisi sunar.
Başlık onayı tamamlanana kadar `APITEST` kullanılabilir; bu başlık gönderilen
metni sağlayıcının sabit deneme metniyle değiştirir. Gerçek rapor metni için
onaylı gönderici başlığı gerekir.

## Hazırlık kontrolü

Backend başladıktan sonra:

```text
GET /health/ready
```

Yanıttaki `notifications.email`, `notifications.sms` ve
`notifications.ready` değerleri `true` olmalıdır. Yanıt hiçbir kimlik
bilgisi döndürmez.

## Ücretsiz deneme: yalnız kendi doğrulanmış alıcılarınız

Proje gösteriminde üretim modunu açmadan gerçek sağlayıcıları denemek için
`backend/.env` içinde sandbox modu ve yalnız kendi e-posta/telefonunuzu içeren
izin listelerini kullanın:

```dotenv
NOTIFICATION_MODE=sandbox
SMS_PROVIDER_MODE=iletimerkezi
NOTIFICATION_SANDBOX_EMAIL_ALLOWLIST=kendi-adresiniz@example.com
NOTIFICATION_SANDBOX_PHONE_ALLOWLIST=+905xxxxxxxxx

# Yukarıdaki gerçek SMTP ve iletiMerkezi değerlerini de doldurun.
```

Ardından sağlık verisi içermeyen deneme mesajını gönderin:

```powershell
cd backend
$env:PYTHONPATH='.'
.\venv\Scripts\python.exe scripts\send_notification_smoke.py `
  --trial `
  --email 'kendi-adresiniz@example.com' `
  --phone '+905xxxxxxxxx' `
  --confirm SEND_REAL_NOTIFICATIONS
```

Komut, iki alıcının da sandbox izin listesinde olmasını gönderimden önce
zorunlu tutar. `APITEST` ile gerçek telefona sağlayıcının sabit deneme mesajı
ulaşır ve ücretsiz krediden düşer. Onaylı başlık sonrasında uygulamanın besin
adı, miktar, tarih, saat ve kalori içeren gerçek rapor metni gönderilir.

## Açık onaylı canlı kanal testi

Bu üretim komutu ücretli gerçek gönderim yapar. Alıcıların test mesajını kabul etmiş
olması gerekir:

```powershell
cd backend
$env:PYTHONPATH='.'
.\venv\Scripts\python.exe scripts\send_notification_smoke.py `
  --email 'onayli-alici@example.com' `
  --phone '+905xxxxxxxxx' `
  --confirm SEND_REAL_NOTIFICATIONS
```

Komut sentetik bir kanal testi gönderir ve sağlayıcı mesaj kimliklerini verir.
Sağlayıcının isteği kabul etmesi son teslim garantisi değildir; SMS sağlayıcı
panelindeki teslim durumu ve e-posta sağlayıcısının olay
kayıtları ayrıca kontrol edilmelidir.

## Gizlilik

Kullanıcının her rapor için ayrıca onayladığı besin adı, miktar, tarih, saat ve
kalori bilgileri e-posta ve SMS'e yazılır. Aynı bilgiler kimlik doğrulamalı
diyetisyen panelinde de bulunur. Kullanıcıya gösterilen alıcı ve kanal önizlemesi
onaydan önce okunur; kimlik bilgileri yalnız backend secret ortamında tutulur.
