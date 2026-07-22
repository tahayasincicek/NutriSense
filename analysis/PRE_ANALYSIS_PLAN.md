# NutriSense ön analiz planı

**Sürüm:** NS-HCI-SAP-1.0-DRAFT

**Durum:** Ham veri görülmeden hazırlanmıştır; etik kurul/danışman onayı bekler.

**Alfa:** İki yönlü aile düzeyi 0,05. İki eş-birincil sonuç Holm ile düzeltilir.

## Araştırma sorusu ve tasarım

Aynı katılımcı altı görevi NutriSense ve standartlaştırılmış yardım koşulunda yapar. AB/BA sıra counterbalance edilir. Analiz birimi görev satırı olsa da bağımsız örneklem birimi katılımcıdır. Bu nedenle bağımsız Mann–Whitney U kanonik test değildir.

## Sonuçlar

Eş-birincil sonuçlar:

1. Katılımcı düzeyinde bağımsız görev başarı oranı. Bağımsız başarı, `success=true` ve `assistance_level=none` olarak tanımlanır.
2. Her iki koşulda bağımsız başarıyla tamamlanan görevler üzerinden katılımcı medyan görev süresi.

İkincil sonuçlar: görev bazında başarı/süre, hata sayısı, yardım düzeyi, abort dağılımı ve q2/q3/q4/q8 madde dağılımları. q4 öznel güvendir; model doğruluğu değildir.

## Hipotez testleri ve etkiler

- İki eş-birincil sonuç için katılımcı düzeyi eşleştirilmiş sign-flip permutation testi.
- Etkiler her zaman NutriSense eksi kontrol yönünde raporlanır.
- Başarı etkisi: eşleştirilmiş katılımcı başarı oranı farkı ve katılımcı bootstrap %95 GA.
- Süre etkisi: eşleştirilmiş medyan saniye farkı, participant bootstrap %95 GA ve paired rank-biserial correlation.
- Wilcoxon signed-rank yalnız önceden belirtilmiş süre duyarlılık analizi olarak verilir; sıfır olmayan en az beş çift gerekir.
- Paired t-test ancak fark dağılımı ve örneklem gerekçesi protokol değişikliğiyle önceden kabul edilirse kullanılabilir. Pipeline bunu otomatik ana test yapmaz.
- Cohen's d, Mann–Whitney çıktısından otomatik türetilmez. Cliff's delta bağımsız gruplara uygun olduğundan bu eşleştirilmiş tasarımda kanonik değildir.
- Koşul başarı oranları için Wilson binomial %95 GA sunulur.
- Altı görev bazlı ikincil test Holm ile düzeltilir.

Yalnız p-değeriyle sonuç kurulmaz; etki, %95 GA, veri kalitesi, örneklem ve sınırlılık birlikte yorumlanır.

## Dahil etme, dışlama ve eksik veri

Yalnız `data_origin=participant`, geçerli protokol/approval reference ve iki koşulu bulunan onamlı pseudonym'ler gerçek analize girer. Aynı participant-task-condition tekrarı, negatif süre, imkânsız başarı/abort birleşimi, bilinmeyen koşul veya eksik t1–t6 kalite hatasıdır; analiz durur ve veri sahibi düzeltmesi gerekir.

Teknik arıza kullanıcı başarısızlığı sayılmaz; `abort_reason=technical_failure` olarak dışlama günlüğünde tutulur. Katılımcı abort'u başarısız görev olarak tanımlanır fakat süre karşılaştırmasına girmez. Eksik çift complete-case eşleştirilmiş analizin dışında kalır; sayı manifestte raporlanır. Veri imputasyonu yapılmaz.

## Süre ve uç değer politikası

Monotonik `duration_seconds` kanoniktir; duvar saati yalnız audit içindir. Birim saniyedir. Negatif, sayısal olmayan veya başarıyla birlikte görev maksimumunu aşan süre hata üretir. Birincil analizde uç değer silinmez. Önceden tanımlı duyarlılıklar:

- tüm kaydedilmiş denemeler,
- yardım düzeyinden bağımsız tamamlananlar,
- yalnız bağımsız başarılar,
- manuel zaman düzeltmeleri hariç.

Başarısız görevi keyfî maksimum süreyle doldurma yapılmaz.

## Anket

q2/q3/q4/q8 tek tek medyan, IQR ve 1–5 dağılımıyla raporlanır. Mevcut sekiz madde tek boyutlu doğrulanmış bir ölçek değildir; toplam puan ve Cronbach alpha üretilmez. q1/q5 kategoriktir. Açık uçlu q6/q7 nicel teste sokulmaz.

## Nitel analiz

Otomatik çıktı yalnız e-posta/telefon redaksiyonu yapılmış metin içerir ve yayımlanmadan insan tarafından disclosure kontrolü gerekir. İki kodlayıcı bağımsız kodlar; kod kitabı pilot yanıtların sonuçları görülmeden sürümlenir; uyuşmazlık uzlaşma toplantısıyla çözülür. Kodlayıcı anlaşması yalnız uygun kategori yapısı ve yeterli veri varsa, formülü belirtilerek hesaplanır.

## Körleme, yeniden üretim ve sapmalar

Pipeline doğrudan pseudonym'i deterministik analiz ID'sine hash'ler ve çıktıda ham kimliği düşürür. Her run input checksum, run ID, tarih, plan/pipeline sürümü ve komut taşır. Plan sapmaları veri analizi çalıştırılmadan ayrı `deviations.md` dosyasında gerekçelendirilmelidir. Eski rapor sayıları veri değildir ve asla input olarak okunmaz.
