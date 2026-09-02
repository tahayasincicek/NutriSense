# MODEL CARD — NutriSense MobileNetV3Small

Durum: **EĞİTİLDİ VE DEĞERLENDİRİLDİ**

| Alan | Değer |
|---|---|
| Deney kimliği | `20260902T061831Z-3a32310432` |
| Kapsam | `nutrisense-food101-5-v1` (5 sınıf + OOD) |
| Model SHA-256 | `987b384e8f90602770586ec8c08e06a91256974e37d7acc2537ad5dcc107cb65` |
| Veri sürümü | `e0a618475df7d548ab13cef15999c7943da52fbb8af58f1eae0d3aa46a936642` |
| Veri kaynağı | Food-101 (Bossard ve ark., 2014) |
| Son değerlendirme | 2 Eylül 2026, mühürlü test |

## Kapsam uyarısı

Bu model, planlanan 10 sınıfın **5'ini** kapsar: baklava, hamburger, pizza,
omlet, patates kızartması. Simit, lahmacun, mantı, mercimek çorbası ve menemen
hiçbir açık veri kümesinde bulunmadığından bu sürüme girmemiştir; bunlar için
`configs/mvp_v1.json` kapsamı ve kendi çekim protokolü geçerlidir. Kullanıcı
bu beş sınıf dışında bir yemek çektiğinde model güvenilir davranamaz; OOD
reddi bu yüzden zorunludur.

## Ölçülen sonuçlar

Aşağıdaki sayılar tek kullanımlık mühürlü test kümesinden gelir. Eşik yalnız
doğrulama kümesinden seçilmiş, test bir kez açılmıştır.

| Metrik | Doğrulama | Test |
|---|---|---|
| Accuracy | 0,9280 | **0,9267** |
| Macro F1 | 0,9279 | **0,9264** |
| Top-3 accuracy | 0,9907 | **0,9907** |
| ECE (15 bin) | 0,0220 | **0,0266** |
| Kapsama (sabit eşikte) | 0,7253 | **0,6933** |
| Seçici hata | 0,1000 | **0,0963** |
| OOD yanlış kabul | 56 / 300 | **51 / 300** |

Güven eşiği: **0,9773** (doğrulamadan sabitlendi).

Test ve doğrulama sonuçlarının birbirine yakınlığı, eşiğin doğrulama kümesine
aşırı uydurulmadığını gösterir.

### Sınıf bazlı test sonuçları

| Sınıf | Precision | Recall | F1 | Örnek |
|---|---|---|---|---|
| baklava | 0,933 | 0,927 | 0,930 | 150 |
| hamburger | 0,898 | 0,923 | 0,910 | 143 |
| pizza | 0,953 | 0,922 | 0,937 | 153 |
| omlet | 0,907 | 0,901 | 0,904 | 151 |
| patates kızartması | 0,942 | 0,961 | 0,951 | 153 |

En sık karışma omlet ile pizza arasındadır (test kümesinde 8 + 4 örnek).

## Dağıtım artefaktı

| Biçim | Durum | Boyut | Keras farkı | Argmax uyumu |
|---|---|---|---|---|
| float32 | **Kabul** | 2,34 MB | 7,5e-06 | 1,000 |
| float16 | Reddedildi | — | 0,0220 (tolerans 0,02) | — |
| int8 | **Reddedildi** | — | 0,996 (tolerans 0,08) | 0,697 |

INT8 dönüşümü kabul edilmedi ve bu bir tolerans meselesi değildir: 300 örnek
üzerinde ölçüldüğünde doğruluk 0,920'den **0,697'ye** düşmektedir. MobileNetV3'ün
hard-swish aktivasyonları ve modelin içindeki `[0,255]` ön işleme katmanı tam
tamsayı kuantizasyonunda ağır bozulma üretir. Dağıtımda float32 kullanılır;
INT8 istenirse ayrı bir kuantizasyona-duyarlı eğitim çalışması gerekir.

Fiziksel cihaz gecikmesi hâlâ `not_run`dır; masaüstünde float32 medyan çıkarım
süresi 3,5 ms ölçülmüştür ancak bu bir telefon ölçümü değildir.

## Planlanan kullanım

Model, MVP kapsamındaki tek yemek fotoğrafları için aday sınıf önerir. Erişilebilir arayüz, sınıf ve güveni duyurabilir; ancak eşik altındaki sonuçta “Tanıyamadım, lütfen tekrar çekin veya manuel seçin” davranışı zorunludur. Sağlık tanısı, alerjen güvenliği, tedavi kararı, kesin kalori veya porsiyon ölçümü için kullanılamaz.

## Mimari ve giriş sözleşmesi

Plan: ImageNet aktarım öğrenmeli `MobileNetV3Small`, `alpha=0.75`, 224×224 RGB. Büyük varyant yerine Small seçimi mobil boyut/gecikme ve çevrimdışı erişilebilirlik hedefi nedeniyledir. `include_preprocessing=true` olduğu için Keras girişi float32 `[0,255]`; ilave `/255` normalizasyonu yapılmaz. Kesin sözleşme `contracts/preprocessing.json`, sınıf sırası `contracts/labels.txt` içindedir.

## Eğitim ve karar protokolü

Sabit seed 2209, sınıf ağırlıkları, yalnız train augmentation, early stopping ve iki aşamalı fine-tuning kullanılır. Test spliti eğitime/eşik seçimine girmez. Güven eşiği validation ve OOD validation üzerinde en az %50 desteklenen örnek kapsaması ve en fazla %10 seçici hata hedefiyle seçilir. Bu hedef karşılanmazsa dağıtım bloke edilir; hedeflerin varlığı başarı garantisi değildir.

## Raporlanması zorunlu metrikler

Accuracy, macro F1, top-3 accuracy, sınıf bazlı precision/recall/F1, confusion matrix, 15-bin ECE, validationdan sabitlenmiş eşikte coverage/selective error, OOD false-accept, Keras/TFLite farkı, byte boyutu ve adı/işletim sistemi belirtilmiş fiziksel cihaz p50/p95 latency. Quantization öncesi/sonrası test metriği, boyut ve latency aynı protokolde karşılaştırılır.

Bu metriklerin tamamı yukarıda raporlanmıştır. Tek istisna fiziksel cihaz
gecikmesidir; o ölçülene kadar `not_run` kalır ve cihaz performansına dair
hiçbir sayı bu karttan türetilemez.

## Riskler

- Benzer yemekler (pizza/lahmacun, omlet/menemen, baklava/börek) yüksek güvenle karışabilir.
- Çoklu yemek, kötü kadraj, yansıma, düşük ışık ve alan dışı görüntüler güvenli reddetme gerektirir.
- Calibration kümesi kullanım ortamını temsil etmezse softmax güveni yanıltıcıdır.
- Görme engelli kullanıcılar yanlış sesli sonuca daha fazla güvenebilir; manuel onay ve yeniden çekim yönlendirmesi erişilebilir olmalıdır.
- Model yalnız sınıf önerir; besin değerleri ayrı ve doğrulanmış kaynaktan gelmelidir.

## Dağıtım kapısı

Gerçek test raporu, validation `decision.json`, TFLite eşdeğerlik, checksum, model/etiket/preprocessing sürüm eşleşmesi ve fiziksel cihaz benchmarkı olmadan `assets/models` içine model dağıtılmaz. Mobil arayüz model yokken bulut/manuel akışı açıkça göstermeli; model varmış gibi davranmamalıdır.
