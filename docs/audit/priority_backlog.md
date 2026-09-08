# Öncelikli Düzeltme ve Kanıt Backlog’u

**Denetim tarihi:** 17 Temmuz 2026  
**Efor birimi:** odaklı kişi-gün; araştırma kurulu/kurum bekleme süreleri hariçtir.  
**Kural:** Bu backlog mevcut denetimin önerisidir; bu turda uygulama kodu değiştirilmemiştir.

## Öncelik modeli

- **P0 — Bloklayıcı:** Bilimsel dürüstlük, kişisel veri/secret güvenliği veya ana ürün zincirini doğrudan engeller. Sonraki geliştirme bu maddeleri görmezden gelemez.
- **P1 — Zorunlu:** Beta/saha çalışması/release için gereklidir.
- **P2 — Kalite:** Yeniden üretilebilirlik, bakım, erişilebilirlik ve kanıt kalitesini tamamlar.
- **P3 — Yaygınlaştırma:** Ürün/araştırma çekirdeği doğrulandıktan sonra yapılır.

## P0 — Bloklayıcı işler

| ID | İş | Bağımlılık | Efor | Başlıca risk | Definition of Done |
|---|---|---|---:|---|---|
| P0-01 ✅ | **Kapandı (8 Eylül 2026):** doğrulanmamış araştırma sayıları taslaklardan çıkarıldı; yerlerine mühürlü test ölçümleri yazıldı | Bu audit ve danışman onayı | 0,5 | n=20, %90, p<0,001, d=2,84 gibi değerlerin gerçek sonuç diye sunulması | `tubitak_sonuc_raporu.md` ve `akademik_makale_taslak.md` başında görünür “DOĞRULANMAMIŞ TASLAK — RAPORDA KULLANILMAMALI” bandı; her ampirik tablo bu register ID’lerine bağlı; veri gelmeden yeni sayı üretilmiyor. |
| P0-02 | Etik kurul ve kurum izni olmadan saha çalışmasını durdurma kapısı koy | Danışman/üniversite etik süreç bilgisi | 1 belge hazırlığı + dış bekleme | Yetkisiz insan araştırması ve geçersiz sonuç | Tarih/karar numaralı etik kurul kararı, kurum izni, onaylı protokol ve onam sürümü alınmadan veri toplama etkinleştirilmiyor; karar öncesi veri “araştırma verisi” sayılmıyor. |
| P0-03 | Onam metnindeki ses kaydı çelişkisini çöz ve veri minimizasyonu planı oluştur | P0-02 | 0,5–1 | “Ses kaydı yapılmaz” ile “sesli onam kaydedilir” çelişkisi; hassas veri riski | Etik kurulca onaylanmış tek prosedür; kayıt varsa hukuki dayanak, saklama/erişim/silme süresi; yoksa tanık/alternatif onam; metinler tutarlı. |
| P0-04 | Gerçek `.env` dosyasını sürüm kontrolü dışında tut ve olası sırları değerlendir | Yok | 0,5 | Secret sızıntısı, hesap kötüye kullanımı | `.env`, credential JSON’ları, key/cert ve `backend/venv` ignore edilir; placeholder `.env.example` korunur; secret taraması temiz; daha önce paylaşılmış her `SET` secret rotate edilir ve yalnız secret store’da tutulur. Değerler loglanmaz. |
| P0-05 | Flutter bağımlılık çözümünü ve analyzer hatalarını gider | P0-04 | 1–3 | Test ve build’in başlamaması; eski APK’ya yanlış güven | SDK ile uyumlu `intl`; kaynakta kullanılan tüm paketler beyanlı; `flutter pub get`, `dart analyze` exit 0; lockfile güncel; temiz ortam komutları kayda alınmış. |
| P0-06 | Tek API tabanı ve kamera analiz sözleşmesi seç | P0-05 | 2–4 | Aktif kamera 404/422 veya parse hatası verir | Tek base URL ortam yapılandırmasından gelir; aktif endpoint backend ile aynı; istek `image_base64`, `meal_type` ve JWT’yi doğru gönderir; yanıt `total_calories`, nutrients ve confidence ile aynı OpenAPI şemasına uyar; contract testi hata durumlarını da kapsar. |
| P0-07 | Başlangıç/auth akışını gerçek backend’e bağla | P0-05, P0-06 | 3–5 | Yetkisiz kullanım, sahte login, token bozulması | Başlangıç auth state’e göre Login/AppShell seçer; register/login gerçek API; access token yenileme endpoint’i; refresh token rotasyonu/iptali; logout backend + güvenli yerel temizlik; 401 retry tek sefer; entegrasyon testleri geçer. |
| P0-08 | Refresh ve logout backend endpoint’lerini güvenli biçimde tamamla | P0-07 | P0-07’ye dahil veya 1–2 | Mobilin çağırdığı endpoint’lerin yokluğu; çalınmış refresh token | Hash/allowlist veya token version stratejisi belgeli; logout sonrası token kullanılamaz; expired/replayed token testleri geçer; sırlar loglanmaz. |
| P0-09 | Aktif geçmiş ekranını mock veriden gerçek kullanıcı verisine geçir | P0-06, P0-07 | 2–3 | Kullanıcıya yanlış kayıt gösterilmesi; demo verinin gerçek sanılması | `AppShell` gerçek `FoodHistoryScreen`/repository kullanır; kullanıcı sahipliği backend’de doğrulanır; loading/empty/error/offline durumları erişilebilir; taranan kayıt aynı kullanıcı geçmişinde görünür; mock yalnız test fixture’dır. |
| P0-10 | Android ana manifest izinleri ve güvenli release yapılandırmasını düzelt | P0-05 | 1–2 | Release’de kamera/ağ/mikrofon çalışmaması; debug anahtarlı dağıtım | Minimum `INTERNET`, `CAMERA`, gerekiyorsa `RECORD_AUDIO` izinleri ana manifestte; runtime izin reddi akışı; özgün application ID; release keystore CI secret store’da; debug signing yok; imzalı release APK/AAB smoke testi geçer. |
| P0-11 | Anket/kullanılabilirlik endpoint’lerini kimlik doğrulama ve veri erişim kontrolüyle koru | P0-02, P0-07 | 2–4 | Public stats/export üzerinden hassas araştırma verisi sızıntısı | Araştırmacı rolü olmadan export/stats erişilemez; veri transit/at-rest korunur; audit log; rate limit; kişisel veri alanları minimizasyonu; yetkisiz erişim testleri 401/403. |
| P0-12 | Ürün sonuçları ile demo/fallback sonuçlarını açıkça ayır | P0-06 | 1 | Demo model veya yerel varsayılanın gerçek YZ başarısı diye sunulması | Her sonuç `recognition_source`, model/service sürümü ve fallback nedenini taşır; demo build release’de kapalı; araştırma analizleri demo/fallback satırlarını önceden tanımlı kuralla ayırır. |

## P1 — Beta ve araştırma öncesi zorunlu işler

| ID | İş | Bağımlılık | Efor | Başlıca risk | Definition of Done |
|---|---|---|---:|---|---|
| P1-01 | Backend proje test paketini kur | P0-06–P0-11 | 3–6 | Auth, sahiplik, veri ve bildirim regresyonları | İzole test DB; auth/register/login/refresh/logout; analyze/history; dietitian; survey authorization; hata/fallback testleri; pytest exit 0; JUnit/coverage artefaktı. |
| P1-02 | Flutter testlerini gerçek ürün koduna yönelt | P0-05–P0-09 | 3–5 | Mock widget testleri sahte güven verir | Varsayılan Counter testi kaldırılmış/düzeltilmiş; gerçek Login, Camera, History, Report ekranları import edilir; repository/API mock sınırında test; unit/widget/integration testleri exit 0 ve rapor üretir. |
| P1-03 | CI başarısızlık maskelemesini kaldır ve kanıt artefaktları yayımla | P1-01, P1-02 | 1–2 | `pytest ... || echo` nedeniyle kırmızı testin yeşil görünmesi | Hiçbir zorunlu adım `|| echo` ile maskelenmez; analyze/test/release build zorunlu; JUnit, LCOV, APK/AAB, SBOM ve SHA-256 artefaktları run/commit’e bağlı yayımlanır. |
| P1-04 | DB migrasyonlarını oluştur ve temiz kurulum testi ekle | P1-01 | 2–4 | `create_all` ile kontrolsüz şema drift’i ve veri kaybı | Alembic baseline + sürümlü migration; boş DB upgrade; mevcut şema upgrade denemesi; rollback/backup planı; CI MySQL container testi. |
| P1-05 | Diyetisyen davet, doğrulama, atama ve iptal akışını kur | P0-07, P1-04 | 4–7 | Yanlış alıcıya sağlık verisi; simülasyon ekranı | Doğrulanmış diyetisyen hesabı; hasta açık onayı; tekil atama/iptal; rol ve sahiplik kontrolleri; audit log; UI gerçek API durumunu gösterir; E2E test geçer. |
| P1-06 | SMTP ve gerekiyorsa Twilio sandbox entegrasyonunu doğrula | P1-05, P0-04 | 2–3 | Teslim edilmeyen veya yanlış kişiye giden rapor | SMTP/Twilio sandbox secret’ları secret store’da; test alıcı onayı; message-id/SID redakte edilerek artefakta yazılır; retry/idempotency ve hata UI’ı testli; gerçek kullanıcıya mesaj atılmaz. |
| P1-07 | YZ veri yönetişim paketini oluştur | Lisans/etik danışmanlığı | 3–7 + veri toplama | Lisans ihlali, veri sızıntısı, train-test leakage | Dataset card; kaynak/URL/lisans; dosya SHA-256 manifesti; sınıf eşleme; duplicate/leakage kontrolü; kişi verisi incelemesi; deterministik split manifestleri. |
| P1-08 | Gerçek model eğitimini yeniden üretilebilir çalıştır | P1-07 | 3–10 + GPU | Model yok; demo modelin gerçek sanılması | Kilitli ortam; seed; komut/run ID; checkpoint/final model; metrik JSON; confusion matrix; eğitim grafiği; model hash’i; hiçbir demo fallback başarı olarak raporlanmaz. |
| P1-09 | Mobil TFLite veya doğrulanmış bulut modeli stratejisini kesinleştir | P1-08, P0-06 | 3–6 | İki belirsiz YZ yolu ve tutarsız sonuç | Mimari karar kaydı; seçilen model sürümü; TFLite ise gerçek model asset ve cihaz benchmark; bulut ise servis SLA/fallback; çıktı şeması aynı; model card güncel. |
| P1-10 | Hazırlanan iOS platformunu Xcode ve gerçek iPhone/VoiceOver ile doğrula veya resmi kapsam değişikliği yap | P0-05, P0-06, P0-07 | 3–8 | Kaynak hazırlığının release ve erişilebilirlik kanıtı sanılması | Seçenek A: macOS CI build, kurumsal bundle ID/signing, gerçek cihaz VoiceOver, IPA/TestFlight ve kabul kaydı. Seçenek B: danışman/onay veren kurumca gerekçeli kapsam değişikliği ve tüm raporlarda düzeltme. |
| P1-11 | Erişilebilirlik kritik görev kabul testi yap | P0-06–P0-10, P1-05 | 3–5 | Hedef kullanıcı ana görevleri tamamlayamaz | TalkBack (ve iOS varsa VoiceOver) ile login, tarama, düzeltme/onay, geçmiş, rapor, ayar; odak/etiket/hint/kontrast/metin ölçekleme; otomatik + manuel rapor; engelleyici hata yok. |
| P1-12 | Araştırma protokolü ve istatistik analiz planını önceden sabitle | P0-02, ürün beta kabulü | 3–5 | Sonuca göre hipotez/test seçimi, geçersiz p/değer | Araştırma sorusu, birincil/ikincil sonuç, örneklem gerekçesi, dahil/dışla, eksik veri, aykırı değer, test seçimi, çoklu test, etki büyüklüğü ve nitel analiz yöntemi sürümlü/tarihli; etik kurul sürümüyle eşleşir. |
| P1-13 | Etik onaydan sonra güvenli ham veri toplama/export zinciri kur | P0-02, P0-03, P0-11, P1-12 | 3–6 + saha | Kimliklenebilir veri, silinmiş kayıt, analiz edilemeyen format | Anonim/pseudonim ID; onam referansı ayrı güvenli depoda; immutable raw export; veri sözlüğü; checksum manifesti; erişim kaydı; retention; yedek; kullanıcı verisi audit dışı komutlarla değiştirilmez. |
| P1-14 | Analizi tek komutla yeniden üret | P1-13 | 3–6 | Rapor sayıları elle yazılır veya çelişir | Kilitli ortam + `run_analysis.py`; doğrulama/varsayım kontrolleri; tam sayımlar, güven aralığı, kesin p, etki formülü; tablo/grafik/JSON otomatik; CLM kayıtları output anahtarına bağlı; kod review geçer. |
| P1-15 | Sonuç raporu ve makaleyi yalnız yeniden üretilmiş çıktılarla düzelt | P1-14 | 2–4 | Eski taslak değerlerin kalması | Tüm nicel değerler analiz artefaktından alınır; %85/%90 ve 4,2/12,7 çelişkileri çözülür; sınırlamalar ve etik karar no yer alır; bağımsız iz sürme kontrolü tamamlanır. |

## P2 — Kalite, yeniden üretilebilirlik ve yönetişim

| ID | İş | Bağımlılık | Efor | Başlıca risk | Definition of Done |
|---|---|---|---:|---|---|
| P2-01 | README ve çalıştırma kılavuzunu yeniden yaz | P0/P1 mimari kararları | 1–2 | Proje temiz ortamda kurulamıyor | Desteklenen SDK’lar; Flutter/backend/MySQL kurulumu; env anahtar adları; migrasyon; test; build; model; araştırma analizi; troubleshooting; hiçbir secret değeri yok; yeni makinede doğrulandı. |
| P2-02 | OpenAPI ve istemci contract üretimini otomatikleştir | P0-06 | 2–3 | Sözleşme tekrar ayrışır | Backend OpenAPI CI’da export edilir; mobil model/client doğrulanır veya üretilir; breaking-change kontrolü; contract testleri. |
| P2-03 | Uygulama yapılandırmasını ortam bazlı yap | P0-04, P0-06 | 1–2 | Sabit prod/emülatör URL’leri yanlış build’e girer | Dev/test/prod config; HTTPS zorunluluğu; build-time doğrulama; secret olmayan config belgeli; prod build localhost/10.0.2.2 içermez. |
| P2-04 | Gözlemlenebilirlik ve mahremiyet uyumlu hata kayıtları ekle | P0-11 | 2–4 | Hata teşhis edilemez veya loglarda kişisel veri/sır sızar | Correlation ID; structured logs; PII/secret redaction testleri; servis hata oranı/latency; retention; kullanıcı görüntüsü/base64 loglanmaz. |
| P2-05 | Kalori veritabanı kaynağı ve güncellik politikasını tanımla | P1-09 | 2–4 + uzman | Yanlış sağlık/beslenme bilgisi | Her kayıt kaynak, birim, porsiyon varsayımı, tarih ve sürüm taşır; diyetisyen/uzman review; tazelik uyarısı; regresyon testleri. |
| P2-06 | Sağlık bilgisi sınırları ve kullanıcı uyarılarını ekle | P2-05 | 1–2 | Kalori tahmininin tıbbi tavsiye sanılması | Tahmin/güven/fallback açık; acil/medikal tavsiye vermediği belirtilir; yanlış tanımayı düzeltme; erişilebilir metin; hukuk/etik review. |
| P2-07 | SBOM, lisans ve güvenlik taraması ekle | P1-03 | 1–2 | Açık/vulnerable veya uyumsuz lisanslı bağımlılık | Flutter/Python SBOM; SCA ve lisans raporu; eşik politikası; kritik açık yok veya risk kabulü belgeli. |
| P2-08 | Yaşayan risk register oluştur | Bu audit | 0,5–1 | PDF riskleri izlenmiyor | Sahip, olasılık, etki, tetikleyici, azaltım, B planı, durum ve kanıt; aylık review; kapanış kriteri. |
| P2-09 | Literatür taraması ve kaynak doğrulamasını tamamla | Danışman/alan uzmanı | 2–4 | 20 kaynak eşiği ve hatalı kaynaklar | En az 20 doğrulanmış yayın; DOI/yayıncı; arama dizgisi/tarih; dahil-dışla; iddia-atıf matrisi; mükerrer/hatalı kayıt yok. |
| P2-10 | Bütçe plan-gerçekleşen ve mali kanıt envanterini oluştur | Danışman/kurum mali süreç | 1–2 | 4.500+4.500 kalemlerinin yanlış raporu | Onaylı bütçe; birim/adet/fiyat; fatura/ödeme/teslim referansı; 9.000 TL mutabakatı; kişisel/mali hassas alanlar redakte. |
| P2-11 | Build provenance ve sürümleme ekle | P1-03 | 1–2 | APK’nın hangi kaynakla üretildiği bilinmiyor | SemVer; git commit; toolchain; CI run; imza sertifika fingerprint’i; SHA-256; release notes; yeniden build karşılaştırması. |
| P2-12 | Kullanıcı el kitabını doğrulanmış UI ile güncelle | P1-11 | 1–2 | Belge ile ürün akışı farklı | Gerçek ekran/komutlar; TalkBack/VoiceOver adımları; izin/hata/offline; veri ve rapor paylaşımı; erişilebilir format; sürüm numarası. |

## P3 — Yaygınlaştırma ve sonraki araştırma

| ID | İş | Bağımlılık | Efor | Başlıca risk | Definition of Done |
|---|---|---|---:|---|---|
| P3-01 | Konferans/makale gönderimi yap | P1-15, P2-09 | 3–7 | Doğrulanmamış veriyle yayın | Hedef etkinlik uygun; etik/veri paylaşım beyanı; gönderim ID; makale çıktıları analiz artefaktına bağlı; yazar katkıları yazılı. |
| P3-02 | Kurumlar ve görme engelli toplulukları için erişilebilir demo paketi hazırla | P1-11, release kabulü | 2–4 | Erişilemeyen veya aşırı iddialı tanıtım | Erişilebilir sunum/video/metin; bilinen sınırlamalar; gerçek başarı ölçüleri; tarihli paylaşım ve geri bildirim kaydı. |
| P3-03 | Store yayınını tamamla | P0-10, P1-03, P1-10 kararı | 2–5 | Güvensiz/kanıtsız release | Privacy/data safety formları doğru; imzalı build; accessibility açıklaması; destek URL; crash/rollback planı; mağaza sürüm kimliği. |
| P3-04 | Çok merkezli ve uzun dönem çalışma fizibilitesini hazırla | P1-15 | 3–6 | İlk çalışmanın kanıtı olmadan kapsam büyütme | Yeni hipotez, güç analizi, merkez sorumlulukları, veri yönetim planı, etik değişiklik/başvuru ve 3–6 ay takip protokolü. |
| P3-05 | Sürdürülebilirlik/SDG etkisini ölçülebilir hale getir | Doğrulanmış kullanım verisi | 2–3 | Pazarlama tipi ölçüsüz etki iddiası | İsraf/bağımsızlık gibi açık gösterge, veri kaynağı, baseline, sınırlar ve raporlama periyodu. |

## Kritik bağımlılık akışı

```text
Araştırma: P0-01 → P0-02/P0-03 → P1-12 → P1-13 → P1-14 → P1-15 → P3-01

Ürün:       P0-04 → P0-05 → P0-06 → P0-07/P0-08 → P0-09/P0-10
                                         ↓
                            P1-01/P1-02 → P1-03 → release

YZ:         P1-07 → P1-08 → P1-09 → P0-06/P1-11

Diyetisyen: P0-07 → P1-04 → P1-05 → P1-06
```

## Sonraki prompt için zorunlu giriş koşulları

Bir sonraki prompt kod değiştirecekse başlamadan önce kullanıcı/ekip şu seçimleri ve sınırları açıkça vermelidir:

1. **Proje kökü:** Yalnız `C:\Users\TAHA\Desktop\2209\nutrisense` mi, yoksa `NutriSense_New` ana dal mı? İki proje kanıtı karıştırılmamalı.
2. **Öncelik:** İlk uygulama turu yalnız P0 ürün güvenliği/çalıştırılabilirlik maddelerini kapsamalı; araştırma sonucu uydurmamalı.
3. **API kararı:** Nihai backend sözleşmesi olarak mevcut FastAPI `/api/v1` yolu onaylanmalı veya alternatif açıkça seçilmeli.
4. **Platform kararı:** hazırlanan iOS kaynakları için gerçek bundle ID/Apple Team, Mac/Xcode ve iPhone doğrulaması sağlanacak mı; sağlanmayacaksa TÜBİTAK kapsam değişikliği mi istenecek?
5. **Sır güvenliği:** Gerçek değerler paylaşılmadan secret rotasyonu/ignore politikası onaylanmalı.
6. **Araştırma kapısı:** Etik karar yoksa saha verisi oluşturma, doldurma, simüle etme veya sonuç hesaplama kesinlikle kapsam dışı kalmalı.
7. **Çalışma ağacı:** Mevcut kullanıcı değişiklikleri korunmalı; kod promptu önce `git init`/snapshot stratejisi için kullanıcı onayı veya güvenli yedek yaklaşımı belirlemeli.

Önerilen bir sonraki uygulama promptunun kapsamı: **P0-04, P0-05 ve ardından P0-06 için test-öncelikli düzeltme**. Başarı kapısı `flutter pub get`, `dart analyze`, gerçek mobil-backend contract testleri ve hiçbir secret değerinin çıktıya düşmemesidir.
