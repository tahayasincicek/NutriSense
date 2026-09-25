# NutriSense teslim kanıt matrisi

**Doğrulama tarihi:** 25 Eylül 2026
**Teslim durumu:** Danışman onaylı, teknik kontroller tamamlandı

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
| iOS/VoiceOver proje kabulü | Tamamlandı | `docs/erisebilirlik_cihaz_kabul_kaydi.md` içindeki dokuz senaryo tamamlandı |
| Gerçek SMTP e-posta | Tamamlandı | 24 Eylül 2026 Gmail SMTP sağlayıcı kabulü; maskeli allowlist alıcısı |
| Gerçek SMS | Tamamlandı | 25 Eylül 2026 İleti Merkezi `accepted`, mesaj kimliği `328492956`; kullanıcı telefon teslimini doğruladı; açık alıcı ve secret depoda yok |
| MySQL 8.4 ve migration | Tamamlandı | Temiz DB upgrade; MySQL üzerinde 286 geçti, 1 atlandı |
| Araştırma veri toplama altyapısı | Tamamlandı | Etik kapı, onam, pseudonym, survey/usability API ve tidy export |
| Saha çalışması teslim yöntemi | Tamamlandı | Danışmanın kabul ettiği yapay zekâ destekli simülasyon; insan katılımcı sonucu olarak sunulmaz |
| İstatistiksel analiz hattı | Tamamlandı | Ön analiz planı, veri sözlüğü, kalite kapısı, tablolar/grafikler ve testler |
| Sonuç raporu | Tamamlandı | `docs/tubitak_sonuc_raporu.md` |
| Yaygınlaştırma içeriği | Tamamlandı | `docs/yayginlastirma_paketi.md` |

## Teslim kapıları

Danışman tarafından kabul edilen proje kapsamı varsayılan komutla denetlenir:

```powershell
.\scripts\verify_tubitak_delivery.ps1
```

Gerçek insan katılımcı analizi, fiziksel iPhone oturumu ve gerçekleşmiş yayın
kanıtı ayrıca ve daha katı modda denetlenebilir:

```powershell
.\scripts\initialize_tubitak_evidence.ps1
.\scripts\verify_tubitak_delivery.ps1 ExternalEvidence
```

Harici kanıtlar kişisel veri içerebileceği için Git'e eklenmez.
`delivery_evidence/*.example.json` dosyaları kopyalanıp `.example` bölümü
kaldırılarak doldurulur. VoiceOver kaydındaki dokuz senaryonun tamamı `pass`
olmalı ve en az bir yerel kanıt dosyası bulunmalıdır. Yaygınlaştırma kaydı ancak
gerçekleşmiş bir sunum/yayın ve doğrulanabilir URL veya dosya içerirse geçer.
Harici saha kapısı yalnız `synthetic=false` ve `REAL_DATA_ANALYZED` gerçek analiz
manifestini kabul eder. İki komut da SMS'i denetlemez.

## Son doğrulama sonuçları

- Backend tam test koşusu: **294 passed, 1 skipped**.
- Flutter tam test koşusu: **336 passed**.
- Flutter statik analiz: **No issues found**.
- iOS kaynak/derleme ve VoiceOver proje senaryoları: **tamamlandı**.
- Gerçek SMTP ve gerçek SMS: teslim doğrulandı; secret Git'e girmedi.

## Teslim kapsamının kapanışı

Proje önerisindeki uygulama özellikleri, analiz altyapısı, danışman tarafından
kabul edilen yapay zekâ destekli saha simülasyonu ve erişilebilirlik senaryoları
tamamlanmıştır. App Store/Play Store hesap, imza, gerçek domain ve production
işletmeci bilgileri araştırma projesinin teknik tesliminden sonraki dağıtım
işlemleridir.

