# MODEL CARD — NutriSense MobileNetV3Large

Durum: **EĞİTİLDİ VE DEĞERLENDİRİLDİ**

| Alan | Değer |
|---|---|
| Deney kimliği | `20260908T060321Z-b000d69c58` |
| Kapsam | `nutrisense-tr130-v1` (130 sınıf + OOD) |
| Mimari | MobileNetV3Large, alpha 1,0, 224×224 |
| Model SHA-256 (TFLite float16) | `270ae6ff459e942324df66387b1df1f6bf4c3e50a5e0811ef76e292c756a7d72` |
| Veri sürümü | `1ea7e7ab1c469cabacfe2510bcd770200c3f218a55a9c4a4c5bc820efec23eb7` |
| Veri kaynakları | TurkishFoods-25 (Apache-2.0), Food-101 (Bossard ve ark., 2014), Turkish-Food-Dataset-Combined (lisans beyanı yok — bkz. `sources/licenses.json`) |
| Eğitim örneği | 96.047 görsel (130 sınıf + 11.921 OOD) |
| Son değerlendirme | 8 Eylül 2026, mühürlü test |

## Kapsam

Model 130 sınıf tanır:

Adana kebap, ananas, ev köftesi, armut, aşure, avokado, ayran, baklava, beyaz lahana sarması, biber dolması, börek, brokoli, Brüksel lahanası, bulgur pilavı, cacık, çay, cheesecake, çiğ köfte, çilek, çipura, kulüp sandviç, çoban salatası, domates, domates çorbası, döner, ekmek, elma, enginar, erik, et sote, patates kızartması, gözleme, hamburger, hamsi, haşlanmış yumurta, havuç, sosisli sandviç, hünkar beğendi, dondurma, içli köfte, incir, İskender, ıspanak yemeği, İzmir köfte, kalburabastı, karides, karnabahar, karnıyarık, karpuz, kavun, kayısı, kazandibi, kebap, Kemalpaşa tatlısı, kiraz, kısır, kivi, kıymalı börek, kıymalı pide, kokoreç, kola, kurabiye, kuru fasulye, lahmacun, levrek, limon, lokma, lokum, mango, mantı, menemen, mercimek çorbası, mercimek köftesi, meyve suyu, midye dolma, midye tava, mısır, mücver, mumbar dolması, muz, nar, omlet, pankek, patates püresi, patates salatası, patlamış mısır, patlıcan kebabı, peynir, pırasa, pirinç pilavı, pizza, portakal, salep, salatalık, salçalı makarna, sandviç, şeftali, şehriye çorbası, simit, siyah zeytin, somon, bolonez spagetti, karbonara spagetti, su böreği, sucuklu yumurta, bamya yemeği, barbunya yemeği, bezelye yemeği, mercimek yemeği, nohut yemeği, patates yemeği, sütlaç, tantuni, tarhana çorbası, taş kebabı, tavuk sote, taze fasulye, tiramisu, tulumba tatlısı, Türk kahvesi, turşu, üzüm, waffle, yaprak sarma, yaş pasta, yayla çorbası, yeşil zeytin, yoğurt, yoğurtlu makarna, zeytinyağlı fasulye.

Kapsam dışı bırakılan 75 batı ve uzakdoğu yemeği (suşi, ramen, pad thai, tako,
paella gibi) desteklenmeyen yemek örneği olarak OOD kümesinde kullanılır; model
bunları isimlendirmez, eşiğin altında kalarak elle onaya düşer.

## Ölçülen sonuçlar

Sayılar tek kullanımlık mühürlü test kümesinden gelir. Eşik yalnız doğrulama
kümesinden seçilmiş, test bir kez açılmıştır.

| Metrik | Doğrulama | Test |
|---|---|---|
| Accuracy | 0,7852 | **0.7918** |
| Macro F1 | 0,7732 | **0.7793** |
| Top-3 accuracy | 0,9184 | **0.9215** |
| ECE (15 bin) | 0,0088 | **0.0536** |
| Kapsama (sabit eşikte) | 0,5034 | **0.5007** |
| Seçici hata | 0,0999 | **0.0937** |

Güven eşiği: **0.9644** (doğrulamadan sabitlendi). Baş eğitimi 13, ince ayar 8
epoch'ta erken durdurma ile tamamlandı.

### Önceki sürümle karşılaştırma

Bir önceki dağıtılan model (`nutrisense-tr29-v1`) 29 sınıfta 0,8375 doğruluk ve
0,7454 kapsama veriyordu. Yeni model sınıf sayısını 4,5 katına çıkarırken
sınıf başına doğruluğun bir kısmını bırakır: tek tahminde 0,7918, kapsamada
0,5007. Cevap verdiğinde isabet oranı ise korunur (0,9063'e karşı 0,8969).
Takas bilinçlidir: uygulama emin olmadığında sormaya devam eder, bu yüzden
düşen kapsama yanlış bilgi değil daha sık soru anlamına gelir.

### Bilinen sınırlar

- INT8 biçimi dağıtılmaz: nicelemeden sonra argmax uyumu 0,12'ye düşüyor.
  MobileNetV3'ün hard-swish katmanları düz eğitim sonrası nicelemede bozuluyor.
- Sınıf başına başarı eşit değil. Meyve ve sebzeler 0,90 üstü F1 verirken
  birbirine benzeyen sulu yemekler 0,40 bandında kalır.
- Eğitim verisinin bir bölümü lisans beyanı olmayan bir kaynaktan gelir;
  görseller yeniden dağıtılmaz.

## Dağıtım artefaktı

| Biçim | Durum | Boyut | Argmax uyumu | Keras farkı |
|---|---|---|---|---|
| float16 | **Dağıtılan** | 5.96 MB | 1.000 | 0.0109 |

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
