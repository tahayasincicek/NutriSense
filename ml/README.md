# NutriSense ML — yeniden üretilebilir araştırma hattı

## Mevcut doğrulama durumu

Bu depo **eğitilmiş bir besin tanıma modeli içermez**. Veri seti, checkpoint, gerçek `metrics.json`, TFLite modeli ve hedef cihaz gecikme ölçümü yoktur. Bu nedenle model doğruluğu hakkında nicel başarı iddiası kurulamaz. Makine tarafından okunabilir güvenli başlangıç kaydı `runs/NOT_RUN/metrics.json` dosyasındadır.

Güncel kapsam `configs/tr222_v1.json` içinde **221 sınıf** olarak dondurulmuştur (`scope_id: nutrisense-tr222-v1`); yaklaşık 90'ı Türk mutfağıdır. Kapsamı değiştirmek yeni `scope_id`, veri kartı revizyonu ve önceden belirlenmiş değerlendirme planı gerektirir; mevcut test sonucuna bakarak sınıf eklenemez/çıkarılamaz.

Bu turda ayrı bir `__ood__` negatif sınıfı **yoktur**. Kapsam dışı fotoğraflar eğitilmiş bir negatif sınıfla değil, validation üzerinde seçilen güven eşiğiyle reddedilir. Sınırı açıkça yazmak gerekirse: negatif örnek görmeden eğitilen model kapsam dışı girdide fazla özgüvenli olabilir, bu yüzden reddetme yükünün tamamı eşiğin üzerindedir ve OOD yanlış kabul oranı bu turda ölçülemez.

## Tasarım ilkeleri

- Otomatik görsel kazıma yoktur; her kaynak elle incelenip `sources/licenses.json` içine kaydedilir.
- Bir istisna bilinçli olarak kabul edilmiştir: `alpsahin/Turkish-Food-Dataset-Combined` veri kümesinin kartında lisans beyanı yoktur. Proje sahibi 2026-09-07'de bu kaynakla eğitim yapmaya karar vermiştir. Şartları bilinmediği için görseller yalnız yerelde tutulur, yeniden dağıtılmaz ve model kartında bu durum açıkça belirtilir.
- Her örnek kaynak, lisans, çekim grubu, SHA-256 ve algısal hash ile manifestte kayıtlıdır.
- Aynı çekim grubu, birebir kopya veya yakın kopya farklı splitlere giremez.
- Augmentation yalnızca `train` veri akışında uygulanır.
- Eğitim kodu test splitini okumaz. Doğrulama eşiği yalnızca validation + OOD validation üzerinde seçilir.
- Test değerlendirmesi deney başına bir kez mühürlenir. Yeni karar için yeni deney gerekir.
- Düşük güven veya desteklenmeyen girdi “bilmiyorum / manuel onay gerekli” sonucudur.
- TFLite dönüşümü gerçek model, gerçek kalibrasyon verisi ve validation eşiği olmadan kapanır.

## Referans ortam

Python 3.11 kullanın. GPU zorunlu değildir; CPU deneyi daha yavaştır. CUDA/cuDNN sürümleri, GPU modeli ve işletim sistemi `provenance.json` yanında ayrıca kaydedilmelidir.

```powershell
cd C:\Users\TAHA\Desktop\2209\nutrisense\ml
py -3.11 -m venv .venv
.\.venv\Scripts\python -m pip install --upgrade pip
.\.venv\Scripts\python -m pip install -r requirements.lock
.\.venv\Scripts\python -m pip install -e . --no-deps
.\.venv\Scripts\python -m pytest
```

## 1. Onaylı veri hazırlama

`intake.example.csv` şemasını kopyalayın. `group_id` aynı fiziksel tabak/çekim serisi için aynı olmalıdır; kişi veya hesap UUID’si yazılmamalıdır. `split_hint` yalnızca harici kaynağın önceden yayımlanmış resmi testi gibi değiştirilemez bir ayrım varsa kullanılır.

```powershell
python -m nutrisense_ml.manifest `
  --intake data\intake.csv `
  --data-root data\raw `
  --config configs\mvp_v1.json `
  --licenses sources\licenses.json `
  --output data\versions\mvp_v1\manifest.csv
```

Komut bozuk görselleri raporlar, çelişkili etiketli kopyada veya lisans onayı yoksa hata verir. `manifest.report.json` içindeki `dataset_version` deney kimliğinin parçasıdır. Manifest üretildikten sonra ham dosyalar salt okunur arşive alınmalıdır.

## 2. Eğitim

```powershell
python -m nutrisense_ml.train `
  --config configs\mvp_v1.json `
  --manifest data\versions\mvp_v1\manifest.csv `
  --data-root data\raw `
  --runs-dir runs
```

Model `MobileNetV3Small(alpha=0.75)` kullanır. MobileNetV3Small, büyük varyanta göre mobilde daha küçük ve düşük gecikmeli bir başlangıç noktasıdır. ImageNet aktarımı, sınıf ağırlıkları, yalnız train augmentation, erken durdurma ve iki aşamalı fine-tuning yapılandırmada sürümlüdür. Mixed precision yalnız GPU bulunduğunda açılır.

## 3. Eşik seçimi ve mühürlü test

```powershell
python -m nutrisense_ml.evaluate --run runs\<EXPERIMENT_ID> --data-root data\raw --split validation
python -m nutrisense_ml.evaluate --run runs\<EXPERIMENT_ID> --data-root data\raw --split test
```

Validation çıktısı güvenlik kısıtlarını karşılayamazsa `decision.json` yazılmaz ve dağıtım bloke olur. Test komutu bu dosyayı zorunlu tutar; testten eşik seçmez. Test verisi açıldığı anda `TEST_EVALUATION_STARTED.seal` yazılır ve komut yarıda kalsa bile aynı deney test için yeniden kullanılamaz. Çıktı accuracy, macro F1, top-3, sınıf bazlı precision/recall/F1, confusion matrix, calibration grafiği, ECE, OOD yanlış kabulü, seçici kapsama ve hata oranını içerir. Fiziksel cihaz latency alanı cihazda ölçülene kadar `not_run` kalır.

## 4. TFLite ve mobil sözleşmesi

```powershell
python -m nutrisense_ml.convert `
  --run runs\<EXPERIMENT_ID> `
  --data-root data\raw `
  --output artifacts\<EXPERIMENT_ID> `
  --formats float32 float16 int8
```

INT8 kalibrasyonu yalnız gerçek train örneklerinden gelir. Her biçim Keras çıktısıyla validation örneklerinde karşılaştırılır; tolerans aşılırsa dosya silinir ve komut başarısız olur. Çıktıda model SHA-256, `labels.txt`, `preprocessing.json`, `decision.json` ve `conversion_report.json` bulunur. Quantized modelin accuracy farkı, sabit test protokolüyle ayrıca ölçülmeden `null` kalır.

Büyük modeller Git’e konmaz. Özel artefakt deposuna yüklenen model `artifacts/index.example.json` şemasında HTTPS URL + SHA-256 ile kaydedilir ve şu şekilde indirilir:

```powershell
python -m nutrisense_ml.fetch_artifact --url <HTTPS_URL> --sha256 <SHA256> --output ..\assets\models\nutrisense_int8.tflite
```

## Eski betikler

`ai_model/01_data_preparation.py`, `02_model_training.py` ve `04_model_converter.py` uyumluluk giriş noktalarıdır ve bu hattı çağırır. Eski otomatik indirme/kazıma, 200 sınıflı varsayılan config, rastgele INT8 kalibrasyonu ve demo model üretimi kaldırılmıştır. `03_calorie_calculator.py` yalnız besin/kalori eşleme prototipidir; görsel model başarısının kanıtı değildir. Kullandığı `calorie_database.json` kaynak ve uzman doğrulaması içermediğinden meta alanında açıkça doğrulanmamış prototip olarak işaretlidir; araştırma sonucu veya sağlık doğruluğu kanıtı sayılamaz.

## Kanıt kabul kapısı

Bir model ancak aşağıdakilerin tümü varsa mobil dağıtıma adaydır: onaylı lisans manifesti, değişmez test split, gerçek deney kimliği, validation kararı, tek seferlik test raporu, confusion/calibration grafikleri, TFLite eşdeğerlik raporu, model/etiket/preprocessing checksumları ve adı belirtilmiş fiziksel cihaz latency raporu. Bunlardan biri eksikse TÜBİTAK raporunda başarı sonucu olarak kullanılmamalıdır.
