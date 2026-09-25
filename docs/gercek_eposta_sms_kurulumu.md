# Gerçek e-posta ve SMS kurulumu

NutriSense gerçek e-postayı standart SMTP, gerçek SMS'i Türkiye için
iletiMerkezi veya alternatif olarak Twilio üzerinden gönderir. Kimlik
bilgileri kaynak koda veya Git deposuna yazılmaz.

## Doğrulanmış e-posta kanıtı

24 Eylül 2026 tarihinde Gmail SMTP üzerinden, sandbox izin listesindeki proje
sahibine ait maskeli test adresine sağlık verisi içermeyen iki gerçek kanal
mesajı gönderilmiştir. Hem doğrudan SMTP denemesi hem uygulamanın mevcut
sandbox/allowlist akışı sağlayıcı tarafından `accepted` sonucu ve Message-ID
ile kabul edilmiştir. Bu kayıt sağlayıcı kabulünü kanıtlar; alıcının mesajı
okuduğunu kanıtlamaz. Secret ve açık alıcı adresi belgeye veya Git'e
yazılmamıştır.

## Doğrulanmış SMS sağlayıcı kabulü

25 Eylül 2026 tarihinde İleti Merkezi sandbox/allowlist akışıyla, proje
sahibinin doğrulanmış ve belgede maskelenen numarasına sağlık verisi
içermeyen tek kanal testi gönderilmiştir. Sağlayıcı isteği `accepted`
durumuyla ve `328492956` mesaj kimliğiyle kabul etmiş, kullanıcı aynı gün
mesajın telefona ulaştığını doğrulamıştır. API anahtarı, hash ve açık telefon
numarası Git deposuna yazılmamıştır.

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

Windows'ta sağlayıcı bilgilerini ekrana yazdırmadan `.env` dosyasına kaydeden
yardımcıyı kullanabilirsiniz:

```powershell
.\scripts\configure_real_sms.ps1 -Provider twilio
# veya
.\scripts\configure_real_sms.ps1 -Provider iletimerkezi
```

Twilio'nun güncel denemesi süre, ülke, doğrulanmış alıcı ve hazır mesaj şablonu
kısıtları uygulayabilir. Türkiye numarasına NutriSense'in özel bildirim metnini
göndermek için canlı hesap ve ülke izni gerekebilir.

```dotenv
NOTIFICATION_MODE=sandbox
SMS_PROVIDER_MODE=iletimerkezi
NOTIFICATION_SANDBOX_EMAIL_ALLOWLIST=kendi-adresiniz@example.com
NOTIFICATION_SANDBOX_PHONE_ALLOWLIST=+905xxxxxxxxx

# Yukarıdaki gerçek SMTP ve iletiMerkezi değerlerini de doldurun.
```

Ardından yalnız sağlık verisi içermeyen kısa SMS denemesini gönderin:

```powershell
cd backend
$env:PYTHONPATH='.'
.\venv\Scripts\python.exe scripts\send_sms_smoke.py `
  --trial `
  --phone '+905xxxxxxxxx' `
  --confirm SEND_REAL_SMS
```

Komut telefonun sandbox izin listesinde olmasını zorunlu tutar. Sağlayıcının
deneme başlığı veya şablonu mesaj metnini değiştirebilir. Canlı hesapta
NutriSense yalnız “Yeni rapor hazır, uygulamayı açın” bildirimini gönderir.

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

Komut gerçek bir kanal testi gönderir ve sağlayıcı mesaj kimliklerini verir.
Sağlayıcının isteği kabul etmesi son teslim garantisi değildir; SMS sağlayıcı
panelindeki teslim durumu ve e-posta sağlayıcısının olay
kayıtları ayrıca kontrol edilmelidir.

## Gizlilik

SMS yalnız “Yeni rapor hazır, uygulamayı açın” bildirimini içerir. Besin adı,
miktar, tarih, saat ve kalori SMS sağlayıcısına gönderilmez; bu ayrıntılar
yalnız kimlik doğrulamalı diyetisyen panelinde gösterilir. Kullanıcıya gösterilen
alıcı ve kanal önizlemesi onaydan önce okunur; sağlayıcı kimlik bilgileri yalnız
backend secret ortamında tutulur.

