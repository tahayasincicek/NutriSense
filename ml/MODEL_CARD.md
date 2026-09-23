# MODEL CARD — NutriSense MobileNetV3Large

Durum: **EĞİTİLDİ VE DEĞERLENDİRİLDİ**

| Alan | Değer |
|---|---|
| Deney kimliği | `20260921T123529Z-029a452dda` |
| Kapsam | `nutrisense-tr137-v1-expanded-camera` (137 sınıf + OOD) |
| Mimari | MobileNetV3Large, alpha 1,0, 224×224 |
| Model SHA-256 (TFLite float32) | `9f464c20e96534cc70a7c8eb9ac02d0220459b46392a05f1b043610f8812b48e` |
| Veri sürümü | `0f3c85ecb129ced53f0cd473ecbf60c5f34ee192ab9cb63a25762f3d5b29f282` |
| Veri kaynakları | TurkishFoods-25 (Apache-2.0), Food-101 (Bossard ve ark., 2014), Turkish-Food-Dataset-Combined (lisans beyanı yok — bkz. `sources/licenses.json`) |
| Manifest örneği | 102.130 görsel (137 sınıf + OOD) |
| Son değerlendirme | 21 Eylül 2026, mühürlü test |

## Kapsam

Model 137 sınıf tanır. Önceki 130 sınıfa ek olarak **elmalı turta, tavuk köri,
churros, kavrulmuş pilav, donmuş yoğurt, humus ve midye** eklenmiştir:

Adana kebap, ananas, ev köftesi, armut, aşure, avokado, ayran, baklava, beyaz lahana sarması, biber dolması, börek, brokoli, Brüksel lahanası, bulgur pilavı, cacık, çay, cheesecake, çiğ köfte, çilek, çipura, kulüp sandviç, çoban salatası, domates, domates çorbası, döner, ekmek, elma, enginar, erik, et sote, patates kızartması, gözleme, hamburger, hamsi, haşlanmış yumurta, havuç, sosisli sandviç, hünkar beğendi, dondurma, içli köfte, incir, İskender, ıspanak yemeği, İzmir köfte, kalburabastı, karides, karnabahar, karnıyarık, karpuz, kavun, kayısı, kazandibi, kebap, Kemalpaşa tatlısı, kiraz, kısır, kivi, kıymalı börek, kıymalı pide, kokoreç, kola, kurabiye, kuru fasulye, lahmacun, levrek, limon, lokma, lokum, mango, mantı, menemen, mercimek çorbası, mercimek köftesi, meyve suyu, midye dolma, midye tava, mısır, mücver, mumbar dolması, muz, nar, omlet, pankek, patates püresi, patates salatası, patlamış mısır, patlıcan kebabı, peynir, pırasa, pirinç pilavı, pizza, portakal, salep, salatalık, salçalı makarna, sandviç, şeftali, şehriye çorbası, simit, siyah zeytin, somon, bolonez spagetti, karbonara spagetti, su böreği, sucuklu yumurta, bamya yemeği, barbunya yemeği, bezelye yemeği, mercimek yemeği, nohut yemeği, patates yemeği, sütlaç, tantuni, tarhana çorbası, taş kebabı, tavuk sote, taze fasulye, tiramisu, tulumba tatlısı, Türk kahvesi, turşu, üzüm, waffle, yaprak sarma, yaş pasta, yayla çorbası, yeşil zeytin, yoğurt, yoğurtlu makarna, zeytinyağlı fasulye.

Kapsam dışı bırakılan 75 batı ve uzakdoğu yemeği (suşi, ramen, pad thai, tako,
paella gibi) desteklenmeyen yemek örneği olarak OOD kümesinde kullanılır; model
bunları isimlendirmez, eşiğin altında kalarak elle onaya düşer.

## Ölçülen sonuçlar

Dağıtılan model 130 sınıftan 137 sınıfa genişletildi. Eklenen sınıflar elmalı
turta, tavuk köri, churros, kavrulmuş pilav, donmuş yoğurt, humus ve midyedir.
Yeni sınıfların her biri 1.000 görselle eğitildi ve doğrulanmış besin kaydına
bağlandı. Sabit doğrulama ve tek kullanımlık mühürlü test sonuçları şöyledir:

| Metrik | Doğrulama | Test |
|---|---:|---:|
| Accuracy | 0,7622 | **0,7683** |
| Macro F1 | 0,7565 | **0,7627** |
| Top-3 accuracy | 0,9022 | **0,9051** |

Güven eşiği **0,9385** değerinde doğrulamadan sabitlendi. Bu eşik 0,5193
kapsama ve 0,09999 seçici hata verir. Mühürlü testte eşik değiştirilmeden
0,5152 kapsama ve 0,0941 seçici hata ölçüldü.

Yeni yedi sınıfın doğrulama macro F1 değeri 0,6486'dır. Midye 0,8182,
donmuş yoğurt 0,7688, churros 0,7170 ve kavrulmuş pilav 0,7148 F1 verdi.
Elmalı turta ve humus daha zor sınıflardır; düşük güvenli sonuçlar bu nedenle
kesin kayıt olarak kullanılmaz ve kullanıcı onayına bırakılır.

### Mobil uygulamadaki uyarlamalı kadraj

Uygulama önce tam görüntü ve %90 merkez kırpmanın yatay çevrilmiş eşleriyle
dört çıkarım yapar. İki ölçeğin en olası sınıfları farklıysa veya birleşik en
yüksek olasılık 0,70'in altındaysa %75, %60 ve %50 merkez kırpmalarla altı
çıkarım daha ekler. Böylece yemek kare içinde küçük kaldığında çevredeki masa,
tabak ve ekran alanının etkisi azaltılır; yüksek güvenli olağan kareler hızlı
yolda kalır.

Her sınıftan 20 örnek içeren 2.740 görsellik dengeli doğrulama alt kümesinde
dört görünüm yolu 0,76788 accuracy ve 0,76747 macro F1 verdi. Uyarlamalı yol
0,77080 accuracy ve 0,77007 macro F1 verdi. Uyarlamalı yolun top-3 accuracy
değeri 0,90511'dir. Uygulama bu üç adayı dokunmatik ve sesli seçimle sunar; yine de
doğru sınıfın ilk üçte bulunması garanti değildir. Gerçek telefon
karelerinde tam görüntüde portakal veya hamburger seçilen iki muz örneği,
uyarlamalı merkez kırpmayla muz sınıfına döndü. Bu sonuç yalnız incelenen saha
kareleri için geçerlidir; tüm kamera koşullarında doğruluk garantisi değildir.

Wikimedia Commons'tan lisans metadatası doğrulanarak seçilen 65 train-only
görselle iki ek ince ayar adayı denendi. Adayların dış saha denetim sonucu 3/8
olarak kaldı ve güvenlik eşiği kapısı geçilemedi. Bu adaylar reddedildi; mobil
uygulamadaki TFLite ağırlıkları değiştirilmedi.

### Önceki 130 sınıflı model

Önceki 130 sınıflı modelin doğrulama macro F1 değeri 0,7725'ti. Genişletilmiş
modelde aynı eski 130 sınıfın macro F1 değeri 0,7623 oldu; yaklaşık bir puanlık
gerileme karşılığında yedi yeni sınıf eklendi. Eğitim farklı cihazların ölçek,
perspektif, ışık, renk, bulanıklık, sensör gürültüsü ve JPEG farklarını taklit
eder; bozulmalar örneklerin %35'ine uygulanarak temiz görüntü bilgisi korunur.

### Bilinen sınırlar

- Doğruluk korunması amacıyla float32 dağıtılır.
- INT8 biçimi dağıtılmaz: nicelemeden sonra argmax uyumu 0,12'ye düşüyor.
  MobileNetV3'ün hard-swish katmanları düz eğitim sonrası nicelemede bozuluyor.
- Sınıf başına başarı eşit değil. Meyve ve sebzeler yüksek F1 verirken
  birbirine benzeyen sulu yemekler 0,40 bandında kalır.
- Eğitim verisinin bir bölümü lisans beyanı olmayan bir kaynaktan gelir;
  görseller yeniden dağıtılmaz.

## Dağıtım artefaktı

| Biçim | Durum | Boyut | Argmax uyumu | Keras farkı |
|---|---|---|---|---|
| float32 | **Dağıtılan** | 11.86 MB | 1.000 | 0.00000313 |

Dönüşüm kapısı argmax uyumunun 1,0 olmasını şart koşar: tek örnekte bile
farklı sınıf seçen biçim dağıtılamaz. Ham olasılık farkı ikinci ölçüttür.

## Gecikme

| Ortam | p50 | p95 |
|---|---|---|
| Samsung Galaxy S8 (SM-G950F), 20 koşu | 3138,28 ms | 3570,78 ms |
| Android emülatörü (sdk_gphone64_x86_64, Android 16), 20 koşu | 1226,83 ms | 1415,61 ms |

Ölçüm JPEG çözme, uyarlamalı çoklu kırpma, yeniden boyutlandırma ve çıkarımın
tamamını kapsar. Sentetik düşük güvenli görüntü derin kırpma yolunu çalıştırır;
bu değerler en ağır olağan çıkarım yolunu temsil eder.

## Kullanım

Model tek yemek fotoğrafı için aday sınıf önerir. Erişilebilir arayüz sınıfı
ve güveni duyurur; eşik altındaki sonuçta manuel onay istenir. Model besin
değeri üretmez; kalori doğrulanmış kaynaktan gelir. Sağlık tanısı, alerjen
güvenliği veya tedavi kararı için kullanılamaz.

## Mimari ve giriş sözleşmesi

ImageNet aktarım öğrenmeli `MobileNetV3Large`, `alpha=1.0`, 224×224 RGB.
`include_preprocessing=true` olduğu için Keras girişi float32 `[0,255]`;
ilave `/255` normalizasyonu yapılmaz. Dağıtılan modelin sözleşmesi
`assets/models/model_manifest.json` dosyasındadır.

## Eğitim ve karar protokolü

Sabit seed 2209, sınıf ağırlıkları, yalnız train augmentation ve erken durdurma
kullanılır. Test spliti eğitime ve eşik seçimine girmez. Güven eşiği validation
ve OOD validation üzerinde en fazla %10 seçici hata hedefiyle seçilir; kapsama
hedefi karşılanmadığında daha fazla sonuç manuel onaya bırakılır.
