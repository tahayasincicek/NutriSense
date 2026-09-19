# NutriSense Teslim Kontrol Listesi

**Son güncelleme:** 19 Eylül 2026

**Kod sürümü:** `1ba2c647338541028fe4668faa4ddc32ad219388`

Bu belge teslim öncesi tek durum kaynağıdır. Eski tarihli denetim belgeleri
tarihsel snapshot olarak korunur; güncel kabul kararı burada ve
`docs/audit/tubitak_requirement_reaudit_2026-09.md` dosyasında bulunur.

## TÜBİTAK özellik kapsamı

| Gereksinim | Durum | Güncel kanıt |
|---|---|---|
| Türkçe Android/iOS Flutter uygulaması | Yazılım tamam | Flutter istemci, Android CI; iOS kaynak ve imzasız CI derlemesi |
| Kamera ile besin tarama | Tamam | Kamera akışı, izin yönetimi, cihaz üstü TFLite ve Android P0 testi |
| Galeriden fotoğraf seçme | Tamam | `image_picker` akışı ve kamera ekranı testleri |
| Yapay zekâ ile besin tanıma | Tamam | 130 sınıflık MobileNetV3Large, mühürlü test ve model manifesti |
| Doğru, kaynaklı kalori/besin bilgisi | Tamam | 556 kayıtlık yerel katalog; kaynak ve tahmin etiketi |
| Besin adı, miktar, tarih-saat, kalori kaydı | Tamam | Onay kapılı kayıt API'si, gerçek geçmiş ekranı ve sahiplik testleri |
| Sonucu sesli okuma | Tamam | Merkezi TTS kuyruğu, tekrar okutma ve erişilebilirlik testleri |
| Sesli komutlarla ana işlemler | Yazılım tamam | Bağlama duyarlı STT, kritik işlemlerde çift onay; fiziksel cihaz testi bekliyor |
| Diyetisyen eşleştirme | Tamam | Karşılıklı istek/kabul/red/iptal ve erişim kontrolü |
| Güvenli diyetisyen paneli | Tamam | Rapor ayrıntıları yalnız kimlik doğrulamalı panelde |
| SMTP e-posta bildirimi | Kod tamam | Gerçek SMTP transportu, TLS ve readiness kontrolü; hesap kimliği dış girdi |
| SMS bildirimi | Kod tamam | Yalnız “Yeni rapor hazır. Uygulamayı açın.”; Twilio hesabı dış girdi |
| Anket ve kullanılabilirlik veri hattı | Yazılım tamam | Onam/etik kapısı, anonim export ve analiz hattı |
| Literatür taraması | Tamam | 22 doğrulanmış kaynak ve kaynak-ürün karar matrisi |
| Android demo APK | Tamam | `app-dev-debug.apk`, SHA-256 aşağıda |

## Doğrulanan kalite kapıları

| Kontrol | Sonuç |
|---|---|
| Backend test/lint/migration | 277 geçti, 1 atlandı; CI geçti |
| Flutter analyze/test/contract/accessibility | 314 test; CI geçti |
| ML güvenlik ve belge tutarlılığı | 8 test; CI geçti |
| Secret taraması | CI geçti; yerel `.env` Git dışında |
| Container/SBOM/zafiyet taraması | CI geçti |
| Sentetik staging ve backup/restore | CI geçti |
| Android P0 emülatör yolculuğu | CI ile doğrulanıyor |

Güncel demo APK:

```text
build/app/outputs/flutter-apk/app-dev-debug.apk
Boyut: 213789128 bayt
SHA-256: E78359E03390B8FCAF9C70C169DE68C0DEE85D24581B147B2A58FD7DE903B073
```

Bu dosya debug demo paketidir; Play Store paketi değildir.

## Teslimden önce ekip tarafından sağlanacak dış girdiler

Bu satırlar yazılım üretilerek veya sahte veriyle kapatılamaz:

| Dış girdi | Neden gerekli | Tamamlanınca yapılacak işlem |
|---|---|---|
| TÜBİTAK proje numarası | Sonuç raporunda kurumun verdiği kimlik | `docs/tubitak_sonuc_raporu.md` içindeki alanı doldur |
| Etik kurul kararı ve kurum izni | İnsan katılımcılı saha çalışmasının önkoşulu | Gerçek karar no/tarih ile araştırma runtime kapısını aç |
| Gerçek katılımcı/onam kayıtları | Kullanılabilirlik ve hipotez sonucu için | Anonim export alıp `analysis/run_analysis.py` çalıştır |
| Kendi SMTP ve Twilio hesapları | Gerçek dış kanal teslimi için | Sırları yalnız `backend/.env`/secret store'a koy ve smoke testi çalıştır |
| Kurum Android application ID ve upload key | İmzalı AAB/Play Store için | `docs/android_release_runbook.md` adımlarını uygula |
| Apple Team/signing ve gerçek iPhone | IPA/TestFlight ve VoiceOver için | iOS release/VoiceOver kabul matrisini doldur |
| Fiziksel Android cihaz | TalkBack, kamera, mikrofon ve adım sensörü için | Manuel ekran okuyucu planını iki Android sürümünde uygula |

## Teslime konulmayacak dosyalar

- `backend/.env`, anahtarlar, parolalar ve sağlayıcı tokenları
- Gerçek kullanıcı e-posta/telefon/sağlık kayıtları
- `analysis/outputs/synthetic/` altındaki sentetik pipeline çıktıları gerçek
  saha sonucu olarak
- Lisansı yeniden dağıtıma izin vermeyen ham model eğitim görselleri
- Debug APK'yı mağaza sürümü gibi gösteren bir beyan

## Gösterim günü sırası

1. Docker Desktop'ı açın; `backend` klasöründe
   `docker compose up -d --build` ile yerel backend'i başlatın.
2. `GET http://localhost:8000/health/ready` yanıtını kontrol edin.
3. Android emülatör için uygulamayı README'deki `--flavor dev` komutuyla
   çalıştırın veya güncel APK'yı kurun.
4. Sentetik demo hesabıyla kamera/galeri, sesli sonuç, onay, geçmiş ve geri alma
   akışlarını gösterin.
5. Diyetisyen eşleştirme ve rapor panelini gösterin. Canlı sağlayıcı hesabı
   yoksa Mailpit/local outbox sonucunu açıkça “yerel test” olarak adlandırın.
6. Model kartını, literatür matrisini ve GitHub Actions yeşil çalışmasını kanıt
   olarak açın.

## Teslim kararı

Yazılım prototipi ve yeniden üretilebilir teknik kanıt paketi teslim
edilebilir durumdadır. İnsan katılımcılı araştırma sonucu, mağaza yayını ve
canlı sağlayıcı teslimi yukarıdaki dış girdiler olmadan tamamlanmış olarak
sunulmamalıdır.
