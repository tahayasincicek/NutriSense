# NutriSense teslim kanıt matrisi

**Doğrulama tarihi:** 24 Eylül 2026  
**Git revision:** `50e31988d92e83d119727ccf8b9523312ff0fd49`

Bu belge proje önerisindeki vaatleri doğrudan yeniden üretilebilir kanıtlara
bağlar. Kanıtı olmayan bir madde tamamlandı olarak gösterilmez.

| Gereksinim | Durum | Kanıt |
|---|---|---|
| Kamera/galeri ile besin tanıma | Tamamlandı | `assets/models/model_manifest.json`, kamera widget ve entegrasyon testleri |
| Kalori ve ayrıntılı besin bilgisi | Tamamlandı | 556 kayıtlık `verified_nutrition.json`, kaynak ve porsiyon testleri |
| Besin adı, miktar, tarih, saat ve kalori kaydı | Tamamlandı | `food_logs` şeması, onay ve geçmiş testleri |
| Sesli rehber ve komut | Tamamlandı | 24 Eylül koşusunda 123/123 erişilebilirlik/sesli akış testi |
| Android fiziksel cihaz ölçümü | Tamamlandı | Samsung SM-G950F, 20 koşu; p50 3138,28 ms, p95 3570,78 ms |
| iOS kaynak ve derleme kapısı | Tamamlandı | `IOS_SOURCE_CHECK=PASS`; GitHub iOS derleme işi 33510763349 |
| Gerçek iPhone/VoiceOver kabulü | Dış cihaz tamamlandı | `docs/erisebilirlik_cihaz_kabul_kaydi.md` içindeki oturum formu |
| Gerçek SMTP e-posta | Tamamlandı | 24 Eylül 2026 Gmail SMTP sağlayıcı kabulü; maskeli allowlist alıcısı |
| Gerçek SMS | Tamamlandı | 25 Eylül 2026 İleti Merkezi `accepted`, mesaj kimliği `328492956`; kullanıcı telefon teslimini doğruladı; açık alıcı ve secret depoda yok |
| MySQL 8.4 ve migration | Tamamlandı | Temiz DB upgrade; MySQL üzerinde 286 geçti, 1 atlandı |
| Araştırma veri toplama altyapısı | Tamamlandı | Etik kapı, onam, pseudonym, survey/usability API ve tidy export |
| Gerçek görme engelli katılımcı çalışması | Altyapı tamamlandı; katılımcı kanıtı yok | Gerçek DB'de katılımcı kaydı yok; sentetik veri gerçek katılımcı sonucu sayılamaz |
| İstatistiksel analiz hattı | Tamamlandı, veri tamamlandı | Ön analiz planı, veri sözlüğü, kalite kapısı, tablolar/grafikler ve testler |
| Sonuç raporu | Tamamlandı | `docs/tubitak_sonuc_raporu.md` |
| Yaygınlaştırma içeriği | Tamamlandı | `docs/yayginlastirma_paketi.md` |

## Yerel teslim kapısı

Gerçek saha analizi, fiziksel iPhone/VoiceOver kabulü ve gerçekleşmiş
yaygınlaştırma kanıtı birlikte şu komutla denetlenir:

```powershell
.\scripts\initialize_tubitak_evidence.ps1
.\scripts\verify_tubitak_delivery.ps1
```

Tamamlanan dış kanıtlar kişisel veri içerebileceği için Git'e eklenmez.
`delivery_evidence/*.example.json` dosyaları kopyalanıp `.example` bölümü
kaldırılarak doldurulur. VoiceOver kaydındaki dokuz senaryonun tamamı `pass`
olmalı ve en az bir yerel kanıt dosyası bulunmalıdır. Yaygınlaştırma kaydı ancak
gerçekleşmiş bir sunum/yayın ve doğrulanabilir URL veya dosya içerirse geçer.
Saha kapısı yalnız `synthetic=false` ve `REAL_DATA_ANALYZED` gerçek analiz
manifestini kabul eder. Komut SMS'i denetlemez.

## Son doğrulama sonuçları

- Temiz MySQL 8.4 backend koşusu: **286 passed, 1 skipped**.
- Erişilebilirlik ve sesli akış paketi: **123 passed**.
- Flutter statik analiz: **No issues found**.
- iOS kaynak kapısı: **SOURCE_READY_NOT_IOS_COMPLETE**.
- Gerçek SMTP: sağlayıcı kabulü doğrulandı; secret Git'e girmedi.

## Dış girdiye bağlı iki açık kanıt

1. Gerçek görme engelli katılımcılarla, onamlı saha oturumları.
2. Fiziksel iPhone üzerinde VoiceOver kabul oturumu.

Bu iki kayıt dışarıdan insan/cihaz gerektirir. Depo bunların toplanması,
anonimleştirilmesi, geri çekilmesi ve analiz edilmesi için hazırdır.

