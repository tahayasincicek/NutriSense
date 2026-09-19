# Gerçek e-posta ve SMS kurulumu

NutriSense gerçek e-postayı standart SMTP, gerçek SMS'i Twilio üzerinden
gönderir. Kimlik bilgileri kaynak koda veya Git deposuna yazılmaz.

## Gerekli üretim değişkenleri

Secret store veya sunucu ortamında aşağıdaki değerleri tanımlayın:

```dotenv
NOTIFICATION_MODE=production
SMS_PROVIDER_MODE=twilio

SMTP_HOST=smtp.saglayiciniz.example
SMTP_PORT=587
SMTP_USER=...
SMTP_PASSWORD=...
SMTP_FROM_NAME=NutriSense
SMTP_FROM_EMAIL=dogrulanmis-adres@example.com
SMTP_USE_TLS=false
SMTP_START_TLS=true

TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...
TWILIO_PHONE_NUMBER=+1...
```

Gönderici e-posta adresi SMTP sağlayıcısında, telefon numarası da Twilio
hesabında doğrulanmış olmalıdır. Türkiye'ye gönderimde sağlayıcının ülke,
başlık ve mesajlaşma mevzuatı kısıtlarını ayrıca tamamlayın.

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
SMS_PROVIDER_MODE=twilio
NOTIFICATION_SANDBOX_EMAIL_ALLOWLIST=kendi-adresiniz@example.com
NOTIFICATION_SANDBOX_PHONE_ALLOWLIST=+905xxxxxxxxx

# Yukarıdaki gerçek SMTP ve Twilio değerlerini de doldurun.
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
zorunlu tutar. Telefon ayrıca Twilio hesabında doğrulanmış olmalıdır. Twilio'nun
güncel ücretsiz deneme hesaplarında özel SMS metni yerine önceden tanımlı deneme
içeriği kullanılabilir; uygulamadaki tam “Yeni rapor hazır. Uygulamayı açın.”
metnini gerçek numaraya göndermek için hesabı ücretli sürüme geçirmek gerekebilir.

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

Komut yalnız sağlık verisi içermeyen bir kanal testi gönderir ve sağlayıcı
mesaj kimliklerini verir. Sağlayıcının isteği kabul etmesi son teslim garantisi
değildir; Twilio konsolundaki teslim durumu ve e-posta sağlayıcısının olay
kayıtları ayrıca kontrol edilmelidir.

## Gizlilik

E-posta yalnız danışan kodu ile rapor referansını taşır. SMS yalnız “Yeni rapor
hazır, uygulamayı açın” bildirimidir. Besin adı, miktar, tarih-saat ve kalori
gibi sağlık verileri kimlik doğrulamalı diyetisyen
panelinde kalır. Twilio veya yabancı SMTP sağlayıcısı kullanılıyorsa KVKK m.9
değerlendirmesi ve uygulamadaki açık rıza metni gerçek sağlayıcı adıyla
güncellenmelidir.
