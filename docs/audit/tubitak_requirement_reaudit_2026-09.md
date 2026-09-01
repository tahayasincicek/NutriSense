# TÜBİTAK 2209-A Gereksinim Yeniden Denetimi

**Yeniden denetim tarihi:** 1 Eylül 2026
**Temel alınan snapshot:** `docs/audit/tubitak_requirement_traceability.md` (17 Temmuz 2026)
**Denetlenen sürüm:** `main` dalı, commit `fa2a8ac`

## Bu belge neden ayrı

17 Temmuz matrisi yerinde güncellenmedi. İki gerekçe var:

1. O belge kendini açıkça snapshot ilan ediyor. Bulgularının üzerine yazmak,
   denetimin hangi tarihte neyi gördüğünü ortadan kaldırır.
2. PDF'in `OZ-08` gereksinimi "uzman ve kullanıcı geri bildirimiyle iteratif
   geliştirme" kanıtı istiyor. İki tarihli denetimin farkı, tam olarak bu
   iterasyonun kanıtıdır. Snapshot'ı silmek, istenen kanıtı silmek olurdu.

Bu yüzden temmuz matrisi olduğu gibi durur; bu belge yalnız **değişen satırları**
kaydeder. Değişmeyen satırlar için temmuzdaki durum ve gerekçe geçerlidir.

## Değerlendirme kuralı

Temmuz matrisinin kuralları aynen geçerlidir. Özellikle: bir dosyanın veya
sınıfın varlığı tek başına "Tam" sayılmaz. Aşağıdaki her durum değişikliği,
kanıt sütununda gösterilen çalışan test, CI işi veya üretilmiş artefakta
dayanır.

## Yönetici özeti

Temmuzda 62 gereksinimden yalnız 1'i "Tam" idi. Bu denetimde 4 gereksinim
"Tam"a, 6 gereksinim daha zayıf bir durumdan "Kısmi"ye taşındı. Temmuzdaki 6
"Çelişkili" bulgunun 4'ü çözüldü; mobil istemci ile backend arasındaki
sözleşme uyuşmazlığı giderildi ve sözleşme artık CI'da sapma kontrolüyle
korunuyor. Kalan iki çelişki (`IZ-07` sonuç raporu, `BT-02` bütçe kalemi)
kod dışıdır. Ayrıca iOS kaynağı ilk kez gerçekten derlendi; `YN-09`'daki
platform çelişkisi bu sayede kapandı.

Buna karşılık **projenin bilimsel çekirdeği hâlâ boştur**. Eğitilmiş model
yoktur (`OZ-06`, `YN-11`); besin tanıma tamamen dış sağlayıcıya (Google
Vision / Gemini) dayanır. Saha çalışması, etik kurul kararı ve ham veri
bulunmadığından `YN-01`–`YN-07`, `IZ-05`–`IZ-09` ve tüm `YE-*` satırları
temmuzdaki durumlarını korur. Bu satırlar kodla kapatılamaz.

## Durum dağılımı

`YN-09` temmuzda tek bir kutuya girmediği ("Kısmi/Çelişkili") için her iki
sütunda da dışarıda tutuldu; durumu aşağıdaki tabloda ayrıca ele alınıyor.
Kalan 61 gereksinim:

| Durum | 17 Temmuz | 1 Eylül |
|---|---|---|
| Tam | 1 | 5 |
| Kısmi | 19 | 22 |
| Kanıtsız | 30 | 27 |
| Eksik | 5 | 5 |
| Çelişkili | 6 | 2 |

## Değişen satırlar

| ID | Gereksinim | Temmuz | Eylül | Neyin değiştiği ve kanıtı |
|---|---|---|---|---|
| OZ-02 | Kamera görüntüsü YZ ile besin olarak tanınmalı. | Çelişkili | Kısmi | Sözleşme uyuşmazlığı giderildi: istemci `lib/core/constants/app_constants.dart` üzerinden kanonik `/api/v1/analyze-food` yolunu çağırıyor. `contracts/openapi.json` CI'daki sapma kontrolüyle korunuyor. **Kısmi kalma sebebi:** tanıma dış sağlayıcıya ait; depoda model yok. |
| OZ-04 | Besin adı, miktar, tarih-saat ve kalori kaydedilmeli. | Kısmi | Tam | `_MockFoodLog` tamamen kaldırıldı (kod tabanında 0 eşleşme). Kayıt backend testleriyle, görüntüleme `integration_test/p0_fixture_journey_test.dart` ile doğrulanıyor; bu test CI'da gerçek Android emülatöründe koşuyor. |
| OZ-05 | Kayıt/rapor e-posta veya SMS ile diyetisyene iletilmeli. | Kanıtsız | Kısmi | Her iki kanal da sağlayıcı mesaj kimliği üretiyor. E-posta Mailpit ile, SMS `local_outbox` sağlayıcısıyla kanıtlandı (`backend/tests/test_sms_local_outbox.py`, 7 test). **Kısmi kalma sebebi:** hiçbir mesaj gerçek operatöre çıkmadı; Twilio kimlikleri yok. |
| OD-01 | Besin tanıma, kalori ve sesli geri bildirim tek akışta birleşmeli. | Çelişkili | Kısmi | URL/şema ayrışması giderildi; zincir P0 yolculuk testinde uçtan uca koşuyor. **Kısmi kalma sebebi:** test sentetik taşıma katmanı kullanır, canlı backend'e karşı gerçek cihaz kanıtı yoktur. |
| OD-02 | Diyetisyene otomatik veri iletimi sağlanmalı. | Kısmi | Tam | `Future.delayed` simülasyonu kaldırıldı. Karşılıklı onaya dayalı atama akışı uygulandı: bekleyen istek listesi, kabul, red ve iptal uçları `backend/app/routers/food_router.py` içinde; `dietitian_accepted_at` / `rejected_at` alanları `b1c2d3e4f5a6` göçüyle eklendi. Hasta yalnız onayladığı diyetisyene rapor gönderebiliyor. |
| AH-02 | Kamera ile besin tanıma yapılmalı. | Çelişkili | Kısmi | `OZ-02` ile aynı gerekçe. |
| AH-03 | Kalori bilgisi hızlı ve erişilebilir verilmelidir. | Kanıtsız | Kısmi | Sonuç kartı kamera önizlemesinden bağımsız çiziliyor; önizleme yokken sonucun gizlendiği hata giderildi ve P0 testiyle korunuyor. **Kısmi kalma sebebi:** gerçek cihazda süre ölçümü yok. |
| AH-05 | Rapor e-posta/SMS ile otomatik iletilmeli. | Kanıtsız | Kısmi | `OZ-05` ile aynı kanıt. |
| AH-06 | Sesli komutlarla kullanım sağlanmalı. | Kısmi | Kısmi | Durum değişmedi ama kanıt güçlendi: ekrana dokunmadan başlatma için sallama algılama eklendi (`lib/shared/services/shake_detector.dart`, 8 birim testi; yürüme ve masaya bırakma senaryoları dahil). **Kısmi kalma sebebi:** görme engelli kullanıcıyla gerçek cihaz denemesi yok. |
| AH-07 | Kullanıcı sonucu onayladıktan sonra rapor oluşturulmalı. | Kısmi | Tam | Karar akışı (`FoodAnalysisDecisionRequest`/`Response`) backend'de zorunlu; onaysız kayıt oluşmuyor. P0 yolculuk testi "tarama onayı" adımını emülatörde geçiyor. |
| YN-06 | t-testi, varsayımlar sağlanıyorsa yapılmalı. | Çelişkili | Kanıtsız | Çelişki giderildi: sapma artık ön-kayıtlı. `analysis/PRE_ANALYSIS_PLAN.md` ana testin Wilcoxon signed-rank olduğunu, paired t-testin ancak protokol değişikliğiyle kabul edilebileceğini yazıyor. **Kanıtsız kalma sebebi:** gerçek veri yok. |
| YN-10 | Backend/veri katmanında MySQL kullanılmalı. | Kanıtsız | Tam | `backend/docker-compose.yml` MySQL 8.4 kullanıyor; Alembic göçleri CI'da boş veritabanında up/down/up olarak doğrulanıyor. SQLite yolu kaldırıldı. |
| YN-09 | Android ve iOS desteklenmeli. | Kısmi/Çelişkili | Kısmi | Çelişki giderildi. Temmuzda iOS kaynağı hazırdı ama hiç derlenmemişti; `scripts/qa/ios_release_checks.py` kendi belgesinde Xcode derlemesi iddia etmediğini yazıyordu. CI'ya macOS runner üzerinde imzasız derleme yapan `iOS Derleme` işi eklendi ve ilk koşuda geçti (koşu `33510763349`). Android tarafı emülatörde P0 yolculuk testiyle zaten kanıtlı. **Kısmi kalma sebebi:** imzalı arşiv, TestFlight dağıtımı ve gerçek iPhone/VoiceOver kanıtı yok; imzalama sertifikası gerekiyor. |
| KVKK-01 | *(yeni satır)* Sağlık verisi ve yurtdışı aktarım açık rızaya bağlanmalı. | — | Kısmi | KVKK m.6 ve m.9 gereği rıza artık uygulanabilir bir kapıdır: `image_cross_border_transfer` rızası yoksa `/analyze-food` 403 döner. Rıza kayıtları `/consents` uçlarıyla saklanır ve geri alınabilir. **Kısmi kalma sebebi:** aydınlatma metni yayımlanmadı (`privacy_notice_version=taslak-yayinlanmadi`). |

## Değişmeyen kritik satırlar

Aşağıdaki satırlar temmuzdaki durumlarını **aynen korur**. Hiçbiri kodla
kapatılamaz; her biri sende olmayan bir kaynağa veya senin bir kararına bağlıdır.

| ID | Gereksinim | Durum | Neden kapanmadı |
|---|---|---|---|
| OZ-06 | Etiketli veri seti ve makine öğrenmesi kullanılmalı. | Kanıtsız | `ml/MODEL_CARD.md`: "NOT RUN — model artefaktı yok". `ml/artifacts/` yalnız örnek indeks içerir. Etiketli veri kümesi gerekiyor. |
| YN-11 | Python/TensorFlow ile YZ geliştirilmelidir. | Kanıtsız | `ml/requirements.lock` içinde TensorFlow yalnız yorum satırlarında geçiyor; eğitim çalıştırılmadı. |
| OD-03 | Hipotez: sesli geri bildirim öğrenmeyi hızlandırır. | Kanıtsız | Ham veri, ön-kayıtlı analiz çıktısı yok. `analysis/results_manifest.json` çalıştırma kimliğini `NO-REAL-DATA-...` olarak veriyor. |
| YN-01, YN-02, YN-13, YN-14 | Anket, kullanılabilirlik testi, etik onam. | Kanıtsız / Eksik | Etik kurul kararı yok; katılımcı çalışması başlatılamaz. |
| IZ-05 – IZ-09 | Saha testi, sonuç raporu, konferans, paylaşım. | Kanıtsız / Çelişkili | Saha çalışması yapılmadı. |
| BT-01 – BT-04 | Bütçe kalemleri. | Kanıtsız / Çelişkili | Satın alma ve harcama belgeleri depoda değil. |
| YE-01 – YE-07 | Yaygın etki taahhütleri. | Kanıtsız | Çıktılar üretilmedi. |
| KY-01 | Kaynakça en az 20 çalışmayı desteklemeli. | Eksik | Depoda literatür tarama belgesi bulunamadı. |

## Denetim sınırları

- Bu denetim yalnız depodaki koda, testlere ve CI çıktılarına dayanır.
- Gerçek cihaz, gerçek kullanıcı ve gerçek sağlayıcı kanıtı üretilmemiştir.
- "Tam" işaretlenen satırlar, gereksinimin **yazılım tarafının** kanıtlandığını
  gösterir; hiçbiri saha geçerliliği iddia etmez.
- Sır değerleri okunmadı; `.env` yalnız yer tutucu/dolu olarak değerlendirildi.
