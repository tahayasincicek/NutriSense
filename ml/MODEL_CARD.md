# MODEL CARD — NutriSense MobileNetV3Small

Durum: **EĞİTİLDİ VE DEĞERLENDİRİLDİ**

| Alan | Değer |
|---|---|
| Deney kimliği | `20260902T090009Z-7871b6adb5` |
| Kapsam | `nutrisense-tr29-v1` (29 sınıf + OOD) |
| Model SHA-256 (TFLite float16) | `74e155e2508eb3a3d58fda0d7faf41d1ac01f7082edca361d470b4e0e0209b57` |
| Veri sürümü | `1cc07ec705f54849e2e8a55af0aa7b24e8dc1de76fe332b2f7acfea4cfd64d9c` |
| Veri kaynakları | TurkishFoods-25 (Apache-2.0) ve Food-101 (Bossard ve ark., 2014) |
| Eğitim örneği | 17.051 görsel |
| Son değerlendirme | 2 Eylül 2026, mühürlü test |

## Kapsam

Model 29 sınıf tanır:

aşure, baklava, biber dolması, börek, çiğ köfte, enginar, et sote, gözleme,
hamsi, hünkar beğendi, içli köfte, ıspanak, İzmir köfte, karnıyarık, kebap,
kısır, kuru fasulye, lahmacun, lokum, mantı, mücver, pirinç pilavı, simit,
taze fasulye, yaprak sarma, hamburger, patates kızartması, omlet, pizza.

## Ölçülen sonuçlar

Sayılar tek kullanımlık mühürlü test kümesinden gelir. Eşik yalnız doğrulama
kümesinden seçilmiş, test bir kez açılmıştır.

| Metrik | Doğrulama | Test |
|---|---|---|
| Accuracy | 0,8335 | **0,8375** |
| Macro F1 | 0,8250 | **0,8268** |
| Top-3 accuracy | 0,9514 | **0,9497** |
| ECE (15 bin) | 0,0364 | **0,0332** |
| Kapsama (sabit eşikte) | 0,7350 | **0,7454** |
| Seçici hata | 0,0997 | **0,1031** |

Güven eşiği: **0,8069** (doğrulamadan sabitlendi). Eğitim 16. epoch'ta erken
durdurma ile tamamlandı.

## Dağıtım artefaktı

| Biçim | Durum | Boyut | Argmax uyumu | Keras farkı |
|---|---|---|---|---|
| float16 | **Dağıtılan** | 1,23 MB | 1,000 | 0,0312 |

Dönüşüm kapısı argmax uyumunun 1,0 olmasını şart koşar: tek örnekte bile
farklı sınıf seçen biçim dağıtılamaz. Ham olasılık farkı ikinci ölçüttür.

## Gecikme

| Ortam | p50 | p95 |
|---|---|---|
| Android emülatörü (sdk_gphone64_x86_64, Android 16) | 95,3 ms | 260,5 ms |

Ölçüm JPEG çözme, yeniden boyutlandırma ve çıkarımın tamamını kapsar.
`target_device_latency_ms` fiziksel cihazda ölçülene kadar `not_run` kalır.

## Kullanım

Model tek yemek fotoğrafı için aday sınıf önerir. Erişilebilir arayüz sınıfı
ve güveni duyurur; eşik altındaki sonuçta manuel onay istenir. Model besin
değeri üretmez; kalori doğrulanmış kaynaktan gelir. Sağlık tanısı, alerjen
güvenliği veya tedavi kararı için kullanılamaz.

## Mimari ve giriş sözleşmesi

ImageNet aktarım öğrenmeli `MobileNetV3Small`, `alpha=0.75`, 224×224 RGB.
`include_preprocessing=true` olduğu için Keras girişi float32 `[0,255]`;
ilave `/255` normalizasyonu yapılmaz. Dağıtılan modelin sözleşmesi
`assets/models/model_manifest.json` dosyasındadır.

## Eğitim ve karar protokolü

Sabit seed 2209, sınıf ağırlıkları, yalnız train augmentation, erken durdurma
ve iki aşamalı fine-tuning. Test spliti eğitime ve eşik seçimine girmez. Güven
eşiği validation ve OOD validation üzerinde en az %50 kapsama ve en fazla %10
seçici hata hedefiyle seçilir.
