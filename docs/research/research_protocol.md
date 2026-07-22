# NutriSense insan katılımcılı araştırma protokolü

**Durum:** Etik kurul başvuru taslağı; onay değildir.

**Protokol sürümü:** Kurum ve araştırmacı tarafından atanacak.

**Etik kurul referansı:** Bekleniyor; boş bırakılmalıdır.
**Sorumlu araştırmacı / danışman / kurum:** Araştırmacı kararı gerekiyor.

## 1. Amaç ve araştırma soruları

Amaç, NutriSense'in görme engelli bir kullanıcının besin tarama, sonucu doğrulama, porsiyon düzeltme, geçmişi dinleme ve onaylı raporu gönderme görevlerini bağımsız tamamlamasına etkisini değerlendirmektir. Sistem tıbbi tanı veya kişiselleştirilmiş diyet tedavisi vermez.

Birincil araştırma sorusu: NutriSense, standartlaştırılmış “bir kişiden yardım isteme” yöntemine kıyasla görev tamamlama bağımsızlığını ve süreyi nasıl etkiler?

İkincil sorular:

- Görev başarısı, hata sayısı ve yardım düzeyi koşullara göre değişir mi?
- Katılımcıların algılanan kullanım kolaylığı, sesli geri bildirim yeterliliği ve sonuç güveni nasıldır?
- Görme düzeyi ve erişilebilir teknoloji deneyimi, sonuçların yorumunu etkileyen bağlamsal değişkenler midir?

## 2. Önceden tanımlı hipotezler

- H1: NutriSense koşulunda yardımsız tamamlanan görev oranı kontrol koşulundan yüksektir.
- H2: NutriSense koşulunda görev süresi kontrol koşulundan farklıdır. Yön, pilot olmadan kesin başarı iddiası olarak belirlenmez.
- H3: NutriSense koşulunda gereken araştırmacı yardımı azalır.

Hipotezler veri görülmeden protokol sürümüne sabitlenir. Keşifsel analizler doğrulayıcı analizlerden ayrı etiketlenir.

## 3. Tasarım ve sıra etkisi

Önerilen tasarım, iki koşullu **within-subject ve counterbalanced** tasarımdır:

- A: NutriSense.
- B: Standartlaştırılmış geleneksel yöntem.
- Sıra AB veya BA, pseudonym UUID'sinin son hexadecimal basamağının tek/çift oluşuna göre atanır. Araştırmacı sonucu elle değiştiremez; zorunlu sapma audit notuyla kaydedilir.
- Koşullar arasında kısa mola ve farklı fakat eşdeğer sentetik besin senaryosu kullanılır.

“Birinden sorma” kontrol koşulu şu şekilde standartlaştırılır: katılımcı, araştırma ekibindeki eğitimli yardımcıya aynı görev cümlesini söyler; yardımcı yalnız önceden hazırlanmış referans kartındaki besin adı, standart porsiyon ve tahmini kalori bilgisini okur. Ek yönlendirme, uygulama karşılaştırması veya beslenme tavsiyesi vermez. Yardım isteme ve yanıtın bitişi zaman damgası sınırlarıdır.

## 4. Ortam, süre ve oturum akışı

Sessiz, erişilebilir, özel bir oda; katılımcının kendi kulaklığına izin; kişisel bildirimler kapalı; sentetik test hesabı ve kişisel veri içermeyen test yiyecekleri kullanılır. Planlanan toplam süre yaklaşık 50–70 dakikadır; kesin süre pilot sonrası etik kurul değişiklik prosedürüyle güncellenir.

1. Erişilebilir bilgilendirme ve soru-cevap.
2. Onam ve geri çekilme kodunun güvenli teslimi.
3. Gerekli, minimal demografik/bağlamsal sorular.
4. Eğitim dışı kısa alıştırma.
5. Counterbalanced iki koşul ve altı görev.
6. Anket.
7. Debrief, veri kullanımı ve geri çekilme hatırlatması.

## 5. Dahil etme ve dışlama

Önerilen dahil etme ölçütleri:

- Kurulca onaylanacak yaş alt sınırını karşılamak.
- Kendisini görme engelli/az gören olarak tanımlamak.
- Türkçe bilgilendirmeyi anlayıp özgür onam verebilmek.
- Akıllı telefon görevlerini fiziksel olarak deneyebilmek; gerekli erişilebilir uyarlamalar dışlama nedeni değildir.

Dışlama ölçütleri:

- Onam kapasitesinin veya gönüllülüğün kurulca belirlenen prosedürle sağlanamaması.
- Araştırma ekibiyle bağımlılık ilişkisi nedeniyle özgür kararın tehlikeye girmesi ve ek güvence bulunmaması.
- Oturum güvenliğini etkileyen akut rahatsızlık/yorgunluk.
- Protokolün desteklemediği dil gereksinimi.

Görme düzeyi, cihaz/ekran okuyucu tercihi veya düşük teknoloji deneyimi tek başına dışlama nedeni olamaz.

## 6. Örneklem ve güç yaklaşımı

Katılımcı sayısı şu anda belirlenmemiştir; “20 kişi” sonuç veya yeterlilik olarak kabul edilmez. Birincil sonlanım “yardımsız görev başarısı”dır. Nihai örneklem kararı için:

1. Kurul onaylı küçük sentetik/pilot süreçle görev anlaşılabilirliği ve ölçüm varyansı değerlendirilir; pilot ana analize katılacaksa önceden belirtilir.
2. Eşleştirilmiş ikili sonuç için McNemar veya katılımcı/görev rastgele etkili lojistik model; süre için eşleştirilmiş sağlam yöntem varsayılır.
3. Anlamlı en küçük fark, danışman ve alan uzmanıyla **veri görülmeden** belirlenir.
4. Güç hesabında alfa, hedef güç, beklenen eşleşme/korelasyon, kayıp ve altı görevin kümelenmesi belgelenir.
5. Hesap betiği, sürüm ve seed analiz planına eklenir. Bu karar tamamlanmadan sayı yazılmaz.

Küçük örneklemde normal dağılım otomatik varsayılmaz. Sürelerde dağılım grafikleri, medyan/IQR, eşleştirilmiş permutation veya Wilcoxon; başarıda kesin güven aralıkları raporlanır. Etki büyüklüğü ve güven aralığı p-değerinden önce gelir. Çoklu ikincil sonuçlar keşifsel olarak etiketlenir veya düzeltme planı uygulanır.

## 7. Sonlanımlar ve analiz birimi

Birincil: her görev için yardımsız başarı (`success=true`, `assistance_level=none`).

İkincil: monotonik süre, hata sayısı, yardım düzeyi, abort nedeni, anket maddeleri.
Analiz birimi görev-katılımcı-koşul satırıdır; aynı katılımcının görevleri bağımsız kabul edilmez.

Eksik veri nedeni (`technical_failure`, `participant_abort`, `researcher_abort`, `not_attempted`) ayrı tutulur. Teknik arıza başarısız kullanıcı performansı olarak kodlanmaz. Protokolden sapmalar audit edilir.

## 8. Riskler ve güvenlik

Çalışma “risksiz” değildir. Olası riskler: yorgunluk, performans kaygısı, yanlış besin/kalori duyurusu, kamera veya ses kullanımında mahremiyet, açık uçlu yanıtta kişisel veri, düşme/çarpma riski ve yetkisiz veri erişimi.

Kontroller:

- Sonuçlar yalnız araştırma görevi içindir; tüketim veya tedavi kararı verilmez.
- Düşük güven sonucunda kesin besin/kalori söylenmez; yeniden deneme veya manuel doğrulama gerekir.
- Katılımcı yürürken kamera görevi yaptırılmaz; yiyecek sabit masadadır.
- İstediği an mola/bitirme; gerekçe zorunlu değildir.
- Araştırmacı müdahalesi kademeli ve kaydedilir.
- Görüntü varsayılan olarak saklanmaz; yüz, belge, adres veya çevresel kimlik bilgisi kadraja alınmaz.
- Açık uçlu alanlarda kişisel veri yazmama uyarısı gösterilir.
- Beklenmeyen olay aynı gün sorumlu araştırmacıya, kurum prosedüründeki sürede kurula bildirilir.

## 9. Onam ve geri çekilme

Onam sonuç verisinden ayrı tabloda tutulur. Varsayılan erişilebilir alternatif, ses kaydı yapılmayan tanıklı sözlü onamdır. Kayıtlı sözlü onam yalnız kurul kararında açıkça izin verilmişse ve `RESEARCH_AUDIO_CONSENT_APPROVED=true` ise mümkündür. Ayrıntı [onam ve geri çekilme prosedüründedir](accessible_consent_and_withdrawal.md).

## 10. Etik onay kapısı

Gerçek veri toplamadan önce backend ve mobil yapılandırmada şu dört alan doğrulanır:

- `RESEARCH_MODE=approved`
- gerçek `RESEARCH_PROTOCOL_VERSION`
- gerçek `RESEARCH_CONSENT_VERSION`
- gerçek `RESEARCH_APPROVAL_REFERENCE`

Boş, TODO, placeholder veya örnek değer kapıyı açmaz. Onay öncesi yalnız `synthetic` kaynaklı fixture kabul edilir; sentetik kayıtlar araştırma istatistiğine dahil edilmez.

## 11. Değişiklik yönetimi

Protokol, görev, anket, onam veya veri saklama değişikliği sürümlenir. Katılımcı toplamaya başladıktan sonraki esaslı değişiklik kurul değişiklik onayı olmadan uygulanmaz. Kod commit'i, migration revision'ı ve doküman sürümü oturum export'una bağlanır.
