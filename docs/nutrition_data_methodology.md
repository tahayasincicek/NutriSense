# NutriSense beslenme verisi metodolojisi

Sürüm: 1.0

Erişim ve doğrulama tarihi: 18 Temmuz 2026

Kapsam kimliği: `nutrisense-mvp-tr-10-v1`

## 1. Kapsam ve sorumluluk sınırı

NutriSense tıbbi teşhis, hastalık riski değerlendirmesi veya kişiselleştirilmiş diyet tedavisi sunmaz. Görüntü tanıma sonucu, seçilen besin kaydı ve kullanıcının onayladığı porsiyon üzerinden **tahmini** besin bilgisi verir. Sonuçlar klinik kararın, hekim veya diyetisyen görüşünün yerine geçmez.

Bu sınırlandırma hatalı, kaynaksız veya eksik veriyi kabul edilebilir yapmaz. Sistem; kaynağı ve porsiyonu izlenemeyen bir değeri başarı olarak kaydetmez, bilinmeyen bir besini sıfır kalorili göstermez ve doğrulanmamış alerjen/sağlık iddiası üretmez.

## 2. Kaynak modeli ve izlenebilirlik

Her başarılı besin sonucu aşağıdaki alanlarla birlikte taşınır ve saklanır:

- `source`: `nutritionix`, `local_verified`, `user_entered` veya `other_verified`;
- `source_item_id`: sağlayıcıdaki değişmez kayıt kimliği;
- `locale`: kaynak kaydın dili/bölgesi;
- `retrieved_at`: UTC, timezone-aware ISO-8601 erişim zamanı;
- `serving_unit` ve `serving_grams`: kaynağın porsiyon temeli;
- `license_name` ve `attribution`: kullanım/atıf izi;
- `canonical_food_id` ve `normalization_version`: dil bağımsız ürün kimliği;
- `portion_value`, `portion_unit`, `portion_grams`, `portion_method` ve `portion_is_estimate`.

Bir alan eksikse veri `NutritionProvenance` doğrulamasından geçmez. Mobil binary içine sağlayıcı anahtarı konmaz. Nutritionix cevapları normal çalışma sırasında backend tarafından alınır; otomatik testler canlı API yerine sürümlü fixture kullanır.

| Kaynak | Kullanım | Güvenlik kapısı |
|---|---|---|
| Nutritionix | Sağlayıcıdan gelen besin ve porsiyon verisi | Sağlayıcı kimliği, zaman, lisans/atıf ve makrolar eksiksiz olmalı; hata/not-found başarıya çevrilmez |
| Doğrulanmış yerel veri | Kurumca incelenip sürümlenmiş kayıt | Kaynak URL/kayıt kimliği, lisans, erişim tarihi ve doğrulayan sürüm zorunlu |
| Kullanıcı girişi | Kullanıcının manuel besin/porsiyon beyanı | `user_entered` olarak açıkça etiketlenir; sağlayıcı ölçümü gibi sunulmaz |
| Gelecekteki kaynak | Yeni resmî/izinli sağlayıcı | Ayrı adaptör, fixture, lisans incelemesi ve sözleşme testi olmadan etkinleşmez |

Eski `ai_model/calorie_database.json` küçük bir prototip listesidir. Kaynak kimliği ve lisans izi olmadığı için `UNVERIFIED` kabul edilir ve başarılı runtime fallback olarak kullanılmaz.

### 7 Eylül 2026: çalışma zamanı kaynak doğrulaması

Varsayılan yerel katalog artık `backend/app/data/verified_nutrition.json` dosyasıdır.
Docker imajına `app/` ile birlikte girer; geliştirme dizinine bağlı bir volume
gerektirmez. `CALORIE_DB_PATH` ile verilen özel kataloglar da aynı kayıt bazlı
doğrulamadan geçer. Eski prototipteki veriler korunmuştur, ancak doğrulanmış
kalori sonucu olarak kullanılmaz.

USDA'nın resmî FNDDS 2021-2023 arşivi 7 Eylül 2026'da indirilip kimlik ve besin
değerleri doğrudan karşılaştırıldı. Katalog 86 kayıt içerir: içecekler (süt, çay,
Türk kahvesi, portakal suyu, kola), temel gıdalar (ekmek, yumurta, yoğurt, beyaz
peynir, zeytin, ceviz), ana yemek ve garnitürler (pilav, makarna, bulgur,
haşlanmış patates, tavuk göğsü, kuzu eti, humus, nohut), çorbalar, meyve ve
sebzeler, kuruyemişler ile hazır yemekler (baklava, hamburger, pizza, omlet,
patates kızartması). Kayıtlar USDA açıklamasına sadık adlandırılır: "Köfte
(soslu, et türü belirtilmemiş)" ya da "Peynirli börek benzeri hamur işi" gibi.
Böylece kullanıcı elindeki kaydın tam karşılık mı yoksa yakın bir referans mı
olduğunu görür. Tarif ayrımları Türkçe sonuç adında görünür. Her kayıtta FDC
kimliği, resmî URL, erişim zamanı, CC0 lisansı, atıf ve beş besin değeri bulunur.
`VERIFIED`, kaynak verisinden doğrulanmış çıkarım demektir; uzman değerlendirmesi,
kişinin tabağı için ölçüm veya klinik doğrulama anlamına gelmez.

Porsiyon birimleri (adet, dilim, kâse, mililitre) aynı arşivin `foodPortions`
kayıtlarından alınır ve her satır ölçümün geldiği satırı `source_measure` ile
gösterir; örneğin "1 medium or regular slice = 28 g". Mililitre yoğunluğu, hacim
ölçüsünün gram ağırlığı hacme bölünerek bulunur; sabit "1 mL = 1 g" varsayılmaz.
Hacim birimi yalnız içecek olarak incelenmiş kayıtlara verilir: katılarda "1 su
bardağı" bir hacim ölçüsüdür ama yoğunluk değildir. Ölçüm satırı olmayan besinde
birim hiç sunulmaz; uydurulmuş bir ağırlık yerine yalnız gram girilir.

Su, sıfır kalorili olduğu için kataloga alınmadı: sıfır kalori dönen bir sonuç
"bilinmeyen besini sıfır kalorili gösterme" korumasından geçemez. Su takibi
uygulamada ayrı bir akışla yapılır.

Görüntü tanıma modelinin 29 sınıfından 17'si karşılanır. Eşleme yalnız USDA
kaydı gerçekten aynı yemek olduğunda kurulur: biber dolması, yaprak sarma,
şiş kebap, karnıyarık, enginar, hamsi, ıspanak, taze fasulye gibi. Yakın ama
aynı olmayan kayıtlar katalogda kendi dürüst adıyla durur, model sınıfına
bağlanmaz: buharda hamur mantı sayılmaz, jel şeker lokum sayılmaz, sade
fritter mücver sayılmaz, tabbouleh kısır sayılmaz. Bu ayrımı
`test_no_silent_substitution_for_unsupported_food` testi koruyor.

Katalog, modelin 29 sınıfının tamamını kapsamaz. Mantı, lahmacun, menemen gibi
desteklenmeyen sorgular benzer yiyecekle ikame edilmez. Yapılandırılmış
Nutritionix sağlayıcısından geçerli sonuç alınabilir; aksi halde yerel kaynak
bulunamadığı bildirilir. TürKomp doğrulama fixture'ları çalışma zamanı kataloğuna
aktarılmadı; özellikle çiğ mantı kaydı pişmiş mantı için kullanılmaz.

Başlangıç 100 gramı yalnız hesaplama temelidir ve tahmin olarak işaretlenir.
Gerçek bir adet/dilim/kase ağırlığı uydurulmaz. Kullanıcı gramı değiştirip
onaylayabilir; kaynak ve makrolar aynı analiz kaydından günlük kaydına taşınır.
Tarif ve gerçek porsiyon belirsizliği devam eder.

Kaynak envanteri bulunması tek başına yeterli değildir. Her kayıt ayrı
`VERIFIED` durumu, kaynak kimliği, HTTPS kaynak URL'si, tarih, atıf, lisans ve
eksiksiz sonlu besin değerleri taşımalıdır. Eksik/bozuk kayıt ile `Mock Data`
kaynağı reddedilir. Nutritionix'in eksik makroları da sıfırla tamamlanmaz.

Yeniden üretim (backend dizininde, resmî arşiv indirildikten sonra):

```text
python scripts/build_nutrition_catalog.py --archive /path/to/FoodData_Central_survey_food_json_2024-10-31.zip
```

Betik ağ çağrısı yapmaz; arşivin SHA-256 değerini kontrol eder, seçilen FDC
kimliklerini, açıklamalarını ve birimlerini doğrular. Farklı arşivde durur;
yeni sürüme geçiş açık inceleme gerektirir. Kaynak ve indirme bağlantıları
aşağıdaki USDA bölümündedir. Katalog arama/kayıt entegrasyonu ve olumsuz veri
senaryoları `backend/tests/test_verified_nutrition_catalog.py` ile korunur.

## 3. Resmî referanslar ve lisans kararı

Hesaplama doğrulama fixture'ı [nutrition_validation_mvp_v1.json](../backend/tests/fixtures/nutrition_validation_mvp_v1.json) dosyasındadır. Bu dosya uygulamanın çalışma zamanı besin veri tabanı değildir.

### USDA FoodData Central

[USDA FoodData Central API kılavuzu](https://fdc.nal.usda.gov/api-guide/) verilerin CC0 1.0 kapsamında kamu malı olduğunu ve kaynak gösterilmesini istediğini belirtir. [Veri türü dokümantasyonu](https://fdc.nal.usda.gov/data-documentation/) FNDDS kayıtlarının besin ve porsiyon değerleri için derlenmiş araştırma verisi olduğunu açıklar. Katalogdaki kayıtlar, [FNDDS 2021-2023 resmî indirme paketi](https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_survey_food_json_2024-10-31.zip) içinden FDC kimliğiyle alınmıştır. API anahtarı repoya veya mobil uygulamaya konmaz.

Atıf: U.S. Department of Agriculture, Agricultural Research Service. FoodData Central, 2019. [fdc.nal.usda.gov](https://fdc.nal.usda.gov/).

### TürKomp

[TürKomp kullanım şartları](https://turkomp.tarimorman.gov.tr/useofdata) ticari olmayan yazılı kullanımda görünür atıf ister; izinsiz kopyalama/dağıtımı sınırlar. Bu nedenle depoda TürKomp'un toplu bir kopyası tutulmaz. Sadece hesaplama doğrulamasında kullanılan iki kayıt, özgün sayfaya bağlantı ve zorunlu atıfla tutulur. Üretim dağıtımı veya ticari kullanım öncesi kurumdan yazılı izin/lisans değerlendirmesi gerekir.

Zorunlu atıf: “TürKomp, Ulusal Gıda Kompozisyon Veri Tabanı, versiyon 1.0, [https://turkomp.tarimorman.gov.tr/](https://turkomp.tarimorman.gov.tr/)”.

## 4. Kanonik adlandırma ve Türkçe eşleme

Görünen ad, veri kimliği değildir. `backend/app/domain/nutrition.py` içindeki `tr-en-canonical-v1` eşlemesi locale ile birlikte çalışır. Böylece:

- İngilizce `pasta` → `food.pasta` → “Makarna”;
- Türkçe `pasta` → `food.cake` → “Pasta”;
- İngilizce `lentil soup` ve Türkçe `mercimek çorbası` → `food.mercimek_corbasi`;
- İngilizce `French fries` ve Türkçe `patates kızartması` → `food.french_fries`.

Eşlenemeyen adlar `food.unmapped.<dil>.<slug>` olur ve `mapped=false` taşır. Sessizce benzer bir besine bağlanmaz. Normalizasyon tablosu değişirse sürüm artırılır; eski loglar kendi sürümünü korur. Alerjen veya “sağlıklı/sağlıksız” gibi iddialar yalnızca besin adından türetilmez.

## 5. Porsiyon yöntemi ve erişilebilirlik

Tek fotoğraftan gram tahmini bu MVP'de doğrulanmış değildir. Model veya kaynak başlangıç porsiyonu önerebilir; bu değer `portion_is_estimate=true` ve `portion_method=source_default` olarak işaretlenir. Sonuç ekranda ve Türkçe TTS ile şu anlama gelen açık mesajla sunulur: **“Tahmini 100 gram; değiştirmek ister misiniz?”**

Kullanıcı:

- dokunarak 50/100/150/200 gram hızlı seçeneklerinden birini;
- manuel gram alanını;
- Türkçe sesli sayı girişini;
- yalnızca backend'in kaynağıyla birlikte sunduğu `adet`, `dilim` veya `kase` dönüşümünü

seçebilir. `adet/dilim/kase` için evrensel gram değeri yoktur. Dönüşüm anahtarı `(canonical_food_id, unit)` şeklindedir ve `grams_per_unit`, `source_item_id`, `source_name` olmadan kabul edilmez. Kaynağı olmayan birim butonu gösterilmez.

Domain ve mobil sözleşme; negatif, sıfır, 2000 gram üzeri, `NaN`, `Infinity`, `null` ve sayısal olmayan değerleri reddeder. Adet benzeri sayımlar 0–20 aralığındadır. Değer değiştiğinde aynı analiz kaydı sunucuda yeniden hesaplanır; yeni bir tanıma çağrısı veya ikinci food log üretilmez.

## 6. Tek hesaplama kuralı

Tüm sonuçlar backend domain fonksiyonuyla hesaplanır:

```text
faktor = portion_grams / 100
toplam_kalori = calories_per_100g × faktor
protein = protein_per_100g × faktor
karbonhidrat = carbs_per_100g × faktor
yağ = fat_per_100g × faktor
lif = fiber_per_100g × faktor
makro_kalorisi = protein × 4 + karbonhidrat × 4 + yağ × 9
makro_farkı = makro_kalorisi − kaynak_toplam_kalorisi
```

Hesaplama `Decimal` ile yapılır. Veritabanı `Numeric(14,6)` hassasiyetiyle saklar; yuvarlama yalnızca ekranda/PDF sunumunda yapılır. Sonuç ekranı, geçmiş ve diyetisyen raporu aynı saklanan kanonik hesaplamayı kullanır. Makro kalorisi farkı kalite sinyalidir; sistem kaynak toplamını veya 4/4/9 hesabını otomatik olarak “doğru” ilan etmez. Lifin enerji hesabı ve sağlayıcı yöntemleri farklı olabileceği için fark beklenebilir.

## 7. Hata, bilinmeyen besin ve sağlayıcı kesintisi

`not_found`, sağlayıcı timeout'u, yetkilendirme hatası veya eksik provenance halinde:

1. kalori ve makrolar `null` kalır;
2. analiz onaylanabilir food log durumuna geçmez;
3. “0 kcal başarı” üretilmez;
4. kullanıcıya yeniden deneme, manuel arama veya manuel düzeltme sunulur;
5. sağlayıcı hatası ile “besin bulunamadı” ayrı hata kodları olarak saklanır.

Manuel veri de kaynaksız değildir: açıkça kullanıcı beyanı olarak işaretlenir ve raporda sağlayıcı ölçümü gibi sunulmaz.

## 8. Doğrulama veri seti ve kapsam durumu

Fixture donmuş on ML sınıfının tümünü listeler. Yedi sınıfta exact/uygun resmî kayıt vardır; üç sınıf için sessiz yaklaşık eşleşme yapılmamıştır.

| MVP sınıfı | Referans | Durum / sınır |
|---|---|---|
| baklava | USDA FDC 2708044 | Var; genel tarif, bölgesel çeşit değil |
| hamburger | USDA FDC 2706920 | Var; “not further specified” |
| pizza | USDA FDC 2708614 | Var; peynirli restoran/fast-food örneği |
| omelette | USDA FDC 2707205 | Var; ilave yağ içermeyen örnek |
| french_fries | USDA FDC 2709458 | Var; taze patatesten kızartma |
| simit | TürKomp 12.02.0021 | Var; İzmir simidi |
| manti | TürKomp 12.02.0063 | Var; çiğ Kayseri mantısı |
| lahmacun | — | Eksik exact referans; pizza ile ikame edilmez |
| mercimek_corbasi | — | Eksik exact pişmiş çorba; kuru karışımla ikame edilmez |
| menemen | — | Eksik exact referans; omletle ikame edilmez |

Her mevcut kayıtta 50/100/150/200 gram senaryosu ve beklenen kalori bulunur. `0.000001 kcal` toleransı yalnızca Decimal/serileştirme kontrolüdür; biyolojik doğruluk toleransı değildir. Tarif, bölge, marka, pişirme ve su kaybı belirsizliği için kanıtlı bir yüzde henüz yoktur; fixture bunu `not_calibrated` olarak işaretler.

Yeni sınıf “doğrulandı” sayılmadan önce exact kaynak seçimi, lisans incelemesi, en az dört porsiyon senaryosu, makro alanları, kaynak kimliği ve bağımsız fixture testi gerekir.

## 9. Örnek hesaplamalar

Bu örneklerde sunum yuvarlaması yapılmamıştır.

1. **USDA FNDDS baklava (FDC 2708044) → 50 g:** 440 kcal/100 g × 50/100 = **220 kcal**. Protein 3.29 g, karbonhidrat 18.8 g, yağ 14.65 g, lif 1.25 g. Kaynak tipi: `other_verified`; porsiyon: kullanıcı onaylı gram.
2. **TürKomp Simit, İzmir (12.02.0021) → 150 g:** 368 kcal/100 g × 150/100 = **552 kcal**. Protein 18.21 g, karbonhidrat 57.63 g, yağ 24.69 g, lif 13.41 g. Bu değer bir simidin otomatik olarak 150 g olduğu anlamına gelmez.
3. **TürKomp Mantı, çiğ, Kayseri (12.02.0063) → 200 g:** 292 kcal/100 g × 200/100 = **584 kcal**. Protein 25.26 g, karbonhidrat 91.04 g, yağ 11.42 g, lif 8.02 g. Pişmiş/soslu mantı için kullanılamaz.

## 10. Test ve yeniden üretim

Backend kökünde:

```powershell
python -m pytest tests/test_nutrition_domain.py tests/test_nutritionix_service.py tests/test_nutrition_validation_dataset.py -q
python -m pytest -q
python -m flake8 app tests
```

Flutter kökünde:

```powershell
flutter test
flutter analyze
```

Testler canlı Nutritionix veya USDA API çağrısı yapmaz. Nutritionix sözleşmesi `backend/tests/fixtures/nutritionix_apple.json`, resmî hesaplama referansları `backend/tests/fixtures/nutrition_validation_mvp_v1.json` üzerinden çalışır. Canlı sandbox testi ayrı, açık bir komut ve yalnızca CI secret store üzerinden sağlanan anahtarla yürütülmelidir; secret değeri loglanmaz.

## 11. Güncelleme ve kabul kapısı

Kaynak veriler periyodik değişebilir. Güncellemede eski fixture üzerine sessizce yazılmaz:

1. yeni `source_item_id`/kaynak sürümü ayrı dalda alınır;
2. lisans ve atıf tekrar kontrol edilir;
3. per-100 g alanları ve porsiyon temeli doğrulanır;
4. fixture ve contract testleri çalıştırılır;
5. makro-kalori farkı incelenir;
6. değişiklik changelog/commit ile sürümlenir;
7. eski food loglar özgün provenance ve normalizasyon sürümünü korur.

Üretim kabulü için kalan dış gereksinimler: Nutritionix sözleşme/lisansının kurumsal hesap için onaylanması, TürKomp üretim yeniden kullanım izninin netleştirilmesi, lahmacun/mercimek çorbası/menemen exact referanslarının seçilmesi, kaynaklı adet-dilim-kase gram dönüşümlerinin eklenmesi ve gerçek tarif/cihaz çalışmasıyla belirsizlik aralığının kalibre edilmesidir.
