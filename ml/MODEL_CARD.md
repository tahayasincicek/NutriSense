# MODEL CARD — NutriSense MobileNetV3Small MVP v1

Durum: **NOT RUN — model artefaktı yok**  
Model kimliği/checksum: yok  
Veri sürümü: yok  
Son değerlendirme: yapılmadı

## Planlanan kullanım

Model, MVP kapsamındaki tek yemek fotoğrafları için aday sınıf önerir. Erişilebilir arayüz, sınıf ve güveni duyurabilir; ancak eşik altındaki sonuçta “Tanıyamadım, lütfen tekrar çekin veya manuel seçin” davranışı zorunludur. Sağlık tanısı, alerjen güvenliği, tedavi kararı, kesin kalori veya porsiyon ölçümü için kullanılamaz.

## Mimari ve giriş sözleşmesi

Plan: ImageNet aktarım öğrenmeli `MobileNetV3Small`, `alpha=0.75`, 224×224 RGB. Büyük varyant yerine Small seçimi mobil boyut/gecikme ve çevrimdışı erişilebilirlik hedefi nedeniyledir. `include_preprocessing=true` olduğu için Keras girişi float32 `[0,255]`; ilave `/255` normalizasyonu yapılmaz. Kesin sözleşme `contracts/preprocessing.json`, sınıf sırası `contracts/labels.txt` içindedir.

## Eğitim ve karar protokolü

Sabit seed 2209, sınıf ağırlıkları, yalnız train augmentation, early stopping ve iki aşamalı fine-tuning kullanılır. Test spliti eğitime/eşik seçimine girmez. Güven eşiği validation ve OOD validation üzerinde en az %50 desteklenen örnek kapsaması ve en fazla %10 seçici hata hedefiyle seçilir. Bu hedef karşılanmazsa dağıtım bloke edilir; hedeflerin varlığı başarı garantisi değildir.

## Raporlanması zorunlu metrikler

Accuracy, macro F1, top-3 accuracy, sınıf bazlı precision/recall/F1, confusion matrix, 15-bin ECE, validationdan sabitlenmiş eşikte coverage/selective error, OOD false-accept, Keras/TFLite farkı, byte boyutu ve adı/işletim sistemi belirtilmiş fiziksel cihaz p50/p95 latency. Quantization öncesi/sonrası test metriği, boyut ve latency aynı protokolde karşılaştırılır.

Şu anda bu metriklerin tamamı `not run`dır. `%90`, `p<0,001` veya benzeri hiçbir sayı bu model kartından türetilemez.

## Riskler

- Benzer yemekler (pizza/lahmacun, omlet/menemen, baklava/börek) yüksek güvenle karışabilir.
- Çoklu yemek, kötü kadraj, yansıma, düşük ışık ve alan dışı görüntüler güvenli reddetme gerektirir.
- Calibration kümesi kullanım ortamını temsil etmezse softmax güveni yanıltıcıdır.
- Görme engelli kullanıcılar yanlış sesli sonuca daha fazla güvenebilir; manuel onay ve yeniden çekim yönlendirmesi erişilebilir olmalıdır.
- Model yalnız sınıf önerir; besin değerleri ayrı ve doğrulanmış kaynaktan gelmelidir.

## Dağıtım kapısı

Gerçek test raporu, validation `decision.json`, TFLite eşdeğerlik, checksum, model/etiket/preprocessing sürüm eşleşmesi ve fiziksel cihaz benchmarkı olmadan `assets/models` içine model dağıtılmaz. Mobil arayüz model yokken bulut/manuel akışı açıkça göstermeli; model varmış gibi davranmamalıdır.
