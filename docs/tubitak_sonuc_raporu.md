# TÜBİTAK 2209-A Sonuç Raporu

> **Kapsam beyanı**
>
> Bu rapordaki bütün sayısal sonuçlar depoda yeniden üretilebilir kanıta
> sahiptir: model metrikleri mühürlü test kümesinden, katalog sayıları
> `backend/app/data/verified_nutrition.json` dosyasından, test sayıları CI
> koşumlarından gelir. Deney kimliği `20260908T060321Z-b000d69c58`.
>
> **İnsan denekli kullanılabilirlik çalışması henüz yapılmamıştır.** Bu rapor
> kullanıcı performansına dair hiçbir sayı bildirmez. Çalışma tasarımı,
> önceden kayıtlı analiz planı ve veri toplama hattı hazırdır
> (`analysis/PRE_ANALYSIS_PLAN.md`); etik onay ve saha çalışması sonrasında
> `analysis/run_analysis.py` çıktısı bu rapora aktarılacaktır.

## Proje Başlığı
**Görme Engelli Bireyler İçin Yapay Zeka Destekli Besin Tanıma ve Kalori Takip Mobil Uygulaması: NutriSense**

**Proje No:** [Proje numarası eklenecek]
**Danışman:** [Danışman adı eklenecek]
**Proje Yürütücüsü:** [Ad Soyad]
**Üniversite:** [Üniversite adı]
**Bölüm:** [Bölüm adı]

---

## Bölüm 1: Özet

Bu proje, görme engelli bireylerin günlük beslenme takibini bağımsız olarak yapabilmelerini sağlayan yapay zeka destekli bir mobil uygulama geliştirmeyi amaçlamıştır. NutriSense adlı uygulama, telefon kamerası aracılığıyla yiyecekleri otomatik olarak tanıyarak kalori ve besin değeri bilgisini sesli geri bildirim yoluyla kullanıcıya iletmektedir.

Dünya Sağlık Örgütü verilerine göre dünyada yaklaşık 2,2 milyar kişi görme bozukluğu yaşamaktadır. Türkiye'de ise Engelli ve Yaşlı Hizmetleri Genel Müdürlüğü verilerine göre 600.000'den fazla görme engelli birey bulunmaktadır. Bu bireyler günlük yaşamlarında birçok zorlukla karşılaşmakta olup beslenme takibi de bu zorlukların başında gelmektedir. Mevcut kalori takip uygulamaları görsel arayüze dayalı olduğundan görme engelli kullanıcılar için erişilebilir değildir.

NutriSense uygulamasının ortak Flutter kaynakları ve Android prototipi geliştirilmiştir. iOS platform kaynak hazırlığı eklenmiş olsa da macOS/Xcode derlemesi, signing, archive ve gerçek iPhone/VoiceOver testi henüz yapılmamıştır; bu nedenle iOS tamamlanmış kabul edilmemektedir. Backend ve dış sağlayıcı/model başarı iddiaları yalnız yapılandırma, ham veri ve yeniden üretilebilir test kanıtı bulunduğu ölçüde raporlanmalıdır.

Uygulamanın en kritik bileşeni erişilebilirlik sistemidir. Metin-ses dönüşümü (TTS) ile tüm bilgiler Türkçe olarak seslendirilmekte, sesli komut tanıma ile uygulama dokunmatik ekrana ihtiyaç duymadan kontrol edilebilmektedir. WCAG 2.1 AA standartlarına uyumluluk hedeflenmiştir.

Projenin ölçülen çıktısı, 130 besin sınıfını tanıyan bir cihaz üstü görüntü
tanıma modeli ve 556 kayıtlık kaynaklı bir besin değeri kataloğudur. Model,
tek kullanımlık mühürlü test kümesinde %79,2 doğruluk ve %92,1 ilk-üç
doğruluğu vermiştir. Sistem, güven eşiğinin altında kalan tahminleri
kaydetmez; kabul ettiği tahminlerde ölçülen hata oranı %9,4'tür.

Kullanıcı performansına dair bir ölçüm bu raporda yer almamaktadır; insan
denekli çalışma projenin bir sonraki aşamasıdır.

---

## Bölüm 2: Giriş ve Problem Tanımı

### 2.1 Araştırma Problemi

Görme engelli bireyler, beslenme takibinde ciddi güçlüklerle karşılaşmaktadır. Yiyeceklerin kalori değerlerini öğrenmek için genellikle başka birinin yardımına ihtiyaç duymakta veya beslenme takibinden tamamen vazgeçmektedirler. Mevcut mobil kalori takip uygulamaları (MyFitnessPal, Yazio vb.) görsel kullanıcı arayüzüne dayalı olup görme engelli kullanıcılar için tasarlanmamıştır. Bu uygulamalarda besin girişi yapabilmek için kapsamlı metin okuma, liste tarama ve görsel seçim işlemleri gerekmektedir.

### 2.2 Araştırma Soruları

1. Yapay zeka destekli besin tanıma sistemi, görme engelli bireylerin kalori takibini bağımsız olarak yapmalarını sağlayabilir mi?
2. Sesli geri bildirim ve sesli komut sistemi, görsel arayüze eşdeğer bir kullanıcı deneyimi sunabilir mi?
3. Sistem, Türk mutfağına özgü yemekleri yeterli doğrulukta tanıyabilir mi?

### 2.3 Hipotez

"YZ destekli sesli geri bildirim sistemi, görme engelli bireylerin kalori
hesaplama süreçlerini geleneksel yöntemlere kıyasla daha hızlı ve etkili hale
getirecektir."

Bu hipotez insan denekli ölçüm gerektirir ve **bu raporda sınanmamıştır**.
Sınama, etik onay sonrası yürütülecek kullanılabilirlik çalışmasına
bırakılmıştır; analiz planı veri toplanmadan önce kayıt altına alınmıştır.

### 2.4 Amaç ve Kapsam

Bu araştırma, görme engelli bireylerin beslenme bağımsızlığını artırmak amacıyla yapay zeka ve erişilebilirlik teknolojilerini birleştiren bir mobil uygulama geliştirmeyi, bu uygulamayı hedef kullanıcılarla test etmeyi ve sonuçları bilimsel yöntemlerle analiz etmeyi amaçlamaktadır.

---

## Bölüm 3: Yöntem

### 3.1 Geliştirme Metodolojisi

Proje, Çevik (Agile) yazılım geliştirme metodolojisi kullanılarak yürütülmüştür. İki haftalık sprint döngüleri uygulanmış, her sprint sonunda çalışan bir prototip üretilmiştir. Geliştirme süreci 10 ana adımdan oluşmuştur: (1) mimari tasarım, (2) proje kurulumu, (3) kamera modülü, (4) YZ model eğitimi, (5) API entegrasyonu, (6) erişilebilirlik sistemi, (7) besin geçmişi, (8) anket modülü, (9) test ve optimizasyon, (10) yayın hazırlığı.

### 3.2 Kullanılan Teknolojiler

| Katman | Teknoloji | Versiyon |
|--------|-----------|----------|
| Mobil Frontend | Flutter (Dart) | 3.22 |
| Backend | Python FastAPI | 0.104 |
| Veritabanı | MySQL + SQLAlchemy | 8.0 |
| YZ Modeli | TensorFlow MobileNetV3 | 2.15 |
| Besin Tanıma API | Google Cloud Vision | v1 |
| Kalori Veritabanı | Nutritionix API | v2 |
| TTS | flutter_tts (tr-TR) | 4.0 |
| Sesli Komut | speech_to_text | 6.6 |
| Bildirim | Twilio (SMS) + SMTP | — |

### 3.3 Değerlendirme Tasarımı

Bu aşamada değerlendirme, sistemin teknik başarımı üzerinedir. Görüntü tanıma
modeli, sızıntıya karşı korunmuş bir protokolle ölçülmüştür: veri kümesi
eğitim, doğrulama ve mühürlü test olarak ayrılmış; aynı fiziksel çekimin ve
birbirinin yakın kopyası olan görsellerin farklı bölümlere düşmesi algısal
karma (dHash) ve grup birleştirmesiyle engellenmiştir. Karar eşiği yalnız
doğrulama kümesinde seçilmiş, test kümesi tek kez açılmıştır.

İnsan denekli kullanılabilirlik çalışması bu raporun kapsamı dışındadır.
Çalışmanın deseni, katılımcı ölçütleri, görev listesi ve istatistiksel analiz
planı veri toplanmadan önce yazılmış ve depoda sürümlenmiştir
(`analysis/PRE_ANALYSIS_PLAN.md`, `analysis/DATA_DICTIONARY.md`,
`analysis/QUALITATIVE_CODEBOOK.md`).

### 3.4 Veri Kümesi

Model eğitiminde üç kaynak birleştirilmiştir:

| Kaynak | Lisans | Katkı |
|---|---|---|
| Proje çekimleri / TurkishFoods-25 | Apache-2.0 | Türk yemekleri |
| Food-101 | Akademik kullanım, atıflı | Uluslararası yemekler ve negatif örnekler |
| Turkish-Food-Dataset-Combined | **Lisans beyanı yok** | Türk yemekleri |

Üçüncü kaynağın veri kartında lisans beyanı bulunmamaktadır. Şartları
bilinmediği için görseller yalnız yerelde tutulmakta, yeniden
dağıtılmamaktadır; durum `ml/sources/licenses.json` ve model kartında açıkça
kaydedilmiştir.

Manifest üretimi sırasında aynı görselin farklı etiketlerle bulunduğu 79 dosya
tespit edilip çıkarılmıştır (örneğin aynı fotoğrafın hem "siyah zeytin" hem
"yeşil zeytin" olarak etiketlenmesi). Son veri kümesi 96.047 görselden oluşur:
130 besin sınıfı ve 11.921 kapsam dışı (OOD) örnek.

### 3.5 Besin Değeri Kaynağı

Uygulama kalori değerini tahmin etmez, yerel katalogdan okur. Katalog 556
kayıt içerir:

- **488 kayıt (VERIFIED):** USDA FoodData Central FNDDS 2021-2023 arşivinden
  birebir çıkarılmıştır. Arşiv SHA-256 ile sabitlenmiştir; lisansı CC0'dır.
- **68 kayıt (ESTIMATED):** USDA'da karşılığı olmayan Türk yemekleri için
  yayımlanmış kaynaklardan alınmıştır. Her kayıt kaynak adresini taşır ve
  arayüzde doğrulanmış kayıtlardan ayrı gösterilir.

Tahmini kayıtlarda makro çapraz kontrolü uygulanmıştır: protein×4 +
karbonhidrat×4 + yağ×9 ile bildirilen kalori arasındaki fark %10'u aşan kaynak
reddedilmiştir. Beş kaynakta bu kontrol düşmüş, kalori değeri makrolardan
yeniden hesaplanmış ve kayda bu not düşülmüştür.

---

## Bölüm 4: Bulgular

Bu bölümdeki bütün sayılar depoda yeniden üretilebilir kanıta sahiptir.
İnsan denekli ölçüm içermez.

### 4.1 Görüntü Tanıma Modeli

Deney kimliği `20260908T060321Z-b000d69c58`, kapsam `nutrisense-tr130-v1`,
mimari MobileNetV3Large (alpha 1,0), giriş 224×224.

| Metrik | Doğrulama | Mühürlü test |
|---|---|---|
| Doğruluk | 0,7852 | **0,7918** |
| Macro F1 | 0,7732 | **0,7793** |
| İlk-3 doğruluk | 0,9184 | **0,9215** |
| Kalibrasyon hatası (ECE, 15 bin) | 0,0088 | **0,0536** |

Test kümesi 12.619 örnek içerir (5.960'ı kapsam dışı).

### 4.2 Reddetme Davranışı

Sistem her tahmini kabul etmez. Güven eşiği doğrulama kümesinde, "tahminlerin
en az yarısına cevap ver ve cevap verdiklerinde en fazla %10 yanıl" kısıtıyla
seçilmiştir. Seçilen eşik 0,9644'tür.

| Ölçüt | Doğrulama | Mühürlü test | Kısıt |
|---|---|---|---|
| Kapsama | 0,5034 | **0,5007** | ≥ 0,50 |
| Seçici hata | 0,0999 | **0,0937** | ≤ 0,10 |

Eşiğin altında kalan tahminler kaydedilmez; kullanıcıdan elle onay istenir.
Bu davranış gerçek cihazda da doğrulanmıştır: yemek içermeyen bir sahne
gösterildiğinde sistem tahmin üretmek yerine sonucu reddetmiştir.

### 4.3 Kapsam Kararı ve Önceki Sürümle Karşılaştırma

İlk denemede kapsam 205 sınıfa çıkarılmış, ancak model %66,0 doğrulukta
kalmış ve reddetme kısıtını karşılayamamıştır (%50 kapsamada %25,3 hata).
Doğrulama sonuçları incelendiğinde başarısızlığın kaynağının sınıf sayısı ve
birbirine görsel olarak çok yakın sınıflar olduğu görülmüştür. Kapsam, mutfak
alakasına göre 130 sınıfa daraltılmış; Türk veri kaynaklarından gelen sınıflar
korunmuş, Food-101'e özgü 75 batı ve uzakdoğu yemeği kapsam dışı örnek olarak
ayrılmıştır. Kapsam daraltması ve model kapasitesinin artırılması birlikte
doğruluğu 13,6 puan yükseltmiştir. Kapsam seçiminde yalnız doğrulama
sonuçları kullanılmış, mühürlü test kümesi açılmamıştır.

| | Önceki sürüm | Bu sürüm |
|---|---|---|
| Sınıf sayısı | 29 | **130** |
| Test doğruluğu | 0,8375 | 0,7918 |
| Kapsama | 0,7454 | 0,5007 |
| Seçici hata | 0,1031 | **0,0937** |

Yeni model tek tahminde daha düşük doğruluk verir, ancak kabul ettiği
tahminlerde eskisinden az yanılır ve dört buçuk kat fazla besin tanır. Takas
bilinçlidir: düşen kapsama, yanlış bilgi değil daha sık soru anlamına gelir.

### 4.4 Sınıf Bazında Değişkenlik

Başarı sınıflar arasında eşit dağılmamıştır. Şekil ve renk bakımından ayırt
edici besinler yüksek başarı verirken, görsel olarak benzeşen sulu yemekler
düşük kalmaktadır.

| En yüksek F1 | | En düşük F1 | |
|---|---|---|---|
| kazandibi | 0,95 | taze fasulye | 0,40 |
| kivi | 0,95 | karnabahar | 0,42 |
| muz | 0,94 | yoğurtlu makarna | 0,43 |
| çay | 0,94 | peynirli börek | 0,38 |
| brokoli | 0,92 | halka çörek | 0,16 |

### 4.5 Dağıtım Artefaktı

Eğitilen Keras modeli TFLite'a dönüştürülmüş ve uygulamaya gömülmüştür.

| Biçim | Durum | Boyut | Argmax uyumu | Keras'tan sapma |
|---|---|---|---|---|
| float16 | **Dağıtılan** | 5,96 MB | 1,000 | 0,0109 |
| float32 | Doğrulandı | 11,9 MB | 1,000 | 0,000002 |
| int8 | **Reddedildi** | — | 0,12 | — |

INT8 nicelemesi dağıtılmamıştır: nicelemeden sonra modelin verdiği karar
örneklerin yalnız %12'sinde aynı kalmıştır. MobileNetV3'ün hard-swish
aktivasyonları eğitim sonrası basit nicelemede bozulmaktadır. Dönüşüm kapısı
bu biçimi otomatik olarak reddetmiştir.

### 4.6 Uçtan Uca Doğrulama

Dağıtılan model Android emülatöründe uçtan uca çalıştırılmıştır: kamera
akışından alınan lahmacun görüntüsü cihaz üstü modelle "lahmacun" olarak
tanınmış, kullanıcı onayı istenmiş, onay sonrası kayıt oluşturulmuş ve
katalogdaki 221 kcal/100 g değeri günlük toplama işlenmiştir. Yemek
içermeyen bir sahnede sistem tahmin üretmeyi reddetmiştir.

### 4.7 Yazılım Kalite Kapıları

Her push'ta çalışan sürekli tümleştirme hattı 11 iş içerir. Ölçülen durum:

| Kapı | Sonuç |
|---|---|
| Backend testleri | 240 test geçti, 1 atlandı |
| Flutter testleri | 293 test geçti |
| Statik analiz (Dart) | Hata ve uyarı yok |
| OpenAPI sözleşme sapması | Sapma yok |
| ML yeniden üretilebilirlik kapıları | Geçti |
| Erişilebilirlik denetimi | Geçti |
| Güvenlik taramaları | Geçti |

Erişilebilirlik için depoda **"WCAG 2.1 AA uyumludur"** iddiası
kullanılmamaktadır; mevcut beyan kısmi uygunluk hedefidir ve gerçek cihazda
ekran okuyucu testi tamamlanana kadar bu şekilde kalacaktır
(`docs/accessibility_conformance_report.md`).

---

## Bölüm 5: Tartışma ve Sınırlılıklar

### 5.1 Tartışma

Araştırma sorularından üçüncüsü — sistemin Türk mutfağını yeterli doğrulukta
tanıyıp tanıyamadığı — bu aşamada ölçülebilmiştir. Model 130 besini
tanımakta, bunların yaklaşık 90'ı Türk mutfağına aittir: Adana kebap, döner,
İskender, mantı, menemen, kokoreç, tantuni, karnıyarık, içli köfte, mercimek
çorbası, sulu yemekler, zeytinyağlılar, hamur işleri ve geleneksel tatlılar.
Mühürlü test doğruluğu %79,2, ilk-üç doğruluğu %92,1'dir.

Görme engelli kullanıcı için asıl belirleyici olan ölçüt tek başına doğruluk
değildir. Kullanıcı, verilen cevabı görsel olarak doğrulayamaz; bu nedenle
sistemin "yanlış cevap verme" oranı, "cevap verememe" oranından daha
maliyetlidir. Bu gerekçeyle sistem, düşük güvenli tahminleri kaydetmek yerine
reddeden bir eşikle çalışacak şekilde tasarlanmıştır. Ölçülen davranış, kabul
edilen tahminlerin %90,6'sının doğru olduğunu göstermektedir.

Birinci ve ikinci araştırma soruları (bağımsız kalori takibi ve sesli
arayüzün görsel arayüze eşdeğerliği) kullanıcı ölçümü gerektirdiğinden bu
raporda yanıtlanmamıştır.

### 5.2 Sınırlılıklar

1. **Kullanıcı çalışması yapılmamıştır.** Sistemin görme engelli bireylerde
   gerçek kullanım başarısı ölçülmemiştir. Bu raporda kullanıcı performansına
   dair hiçbir sayı bulunmamaktadır.

2. **Cihaz gecikmesi ölçülmemiştir.** Masaüstünde 11,1 ms ölçülmüştür; hedef
   telefon donanımındaki çıkarım süresi ölçülene kadar model kartındaki ilgili
   alan `not_run` olarak kalmaktadır.

3. **iOS tamamlanmamıştır.** Kaynak hazırlığı ve izin sınırları
   doğrulanmıştır; Xcode derlemesi, imzalama ve gerçek iPhone üzerinde
   VoiceOver testi yapılmamıştır.

4. **Erişilebilirlik uygunluğu kısmidir.** Otomatik denetimler geçmektedir;
   gerçek ekran okuyucu ile elle test tamamlanmadığı için tam uygunluk iddia
   edilmemektedir.

5. **Sınıf başarısı eşit değildir.** Görsel olarak benzeşen sulu yemeklerde
   F1 0,40 bandına inmektedir. Bu sınıflarda sistem daha sık elle onay
   isteyecektir.

6. **Besin değerlerinin 68'i tahminidir.** Bu kayıtlar laboratuvar ölçümü
   değil, yayımlanmış ikincil kaynak ortalamalarıdır; arayüzde ve veride
   ayrıca işaretlidir. Beş kaydın kalorisi kaynak tutarsızlığı nedeniyle
   makrolardan hesaplanmıştır.

7. **Bir veri kaynağının lisansı beyan edilmemiştir.** Şartları bilinmediği
   için görseller yeniden dağıtılmamaktadır; bu durum model kartında
   açıklanmıştır.

---

## Bölüm 6: Sonuç ve Öneriler

### 6.1 Sonuç

Proje, görme engelli bireylerin beslenme takibi için tasarlanmış, cihaz üstü
çalışabilen bir besin tanıma sistemi ve kaynağı belgelenmiş bir besin değeri
kataloğu üretmiştir. Sistem 130 besini tanımakta, emin olmadığı durumlarda
kullanıcıya sormakta ve kalori değerini tahmin etmek yerine izlenebilir bir
kaynaktan okumaktadır.

Projenin yöntemsel katkısı, başarı iddialarının koda bağlanmış kapılarla
korunmasıdır: mühürlü test kümesi tek kez açılır, karar eşiği testten
seçilemez, lisansı onaylanmamış veri eğitime giremez, dağıtım artefaktı
eğitilen modelle aynı kararı vermiyorsa reddedilir. Nitekim INT8 biçimi bu
kapı tarafından reddedilmiş, 205 sınıflık ilk deneme ise reddetme kısıtını
karşılayamadığı için dağıtılmamıştır.

### 6.2 Gelecek Çalışmalar

1. Etik onay alınarak görme engelli katılımcılarla kullanılabilirlik
   çalışmasının yürütülmesi; önceden kayıtlı analiz planının uygulanması.
2. Hedef telefon donanımında çıkarım gecikmesinin ölçülmesi.
3. iOS derlemesinin tamamlanması ve gerçek cihazda VoiceOver testi.
4. Düşük başarılı sınıflar için hedefli veri toplanması.
5. Tahmini besin kayıtlarının uzman diyetisyen incelemesinden geçirilmesi.

### 6.3 Proje Çıktıları

| Çıktı | Durum |
|-------|-------|
| Besin tanıma modeli (130 sınıf, MobileNetV3Large) | Tamamlandı; mühürlü testte değerlendirildi |
| TFLite dağıtım artefaktı (float16) | Tamamlandı; uygulamaya gömüldü |
| Besin değeri kataloğu (556 kayıt) | Tamamlandı; 488 doğrulanmış, 68 işaretli tahmin |
| Python FastAPI backend | Tamamlandı |
| NutriSense mobil uygulama — Android | Kaynak ve emülatör doğrulaması tamam; fiziksel cihaz kabulü bekliyor |
| NutriSense mobil uygulama — iOS | Kaynak hazırlığı tamam; derleme ve cihaz testi bekliyor |
| Yeniden üretilebilir ML hattı ve kapıları | Tamamlandı |
| Analiz hattı ve önceden kayıtlı analiz planı | Hazır; veri bekliyor |
| Kullanılabilirlik çalışması | **Yapılmadı** |
| Akademik makale taslağı | Hazırlanıyor |

---

## Bölüm 7: Kaynakça (IEEE Formatı)

[1] World Health Organization, "World report on vision," Geneva, 2019.

[2] A. Howard et al., "Searching for MobileNetV3," in Proc. IEEE/CVF Int. Conf. Computer Vision (ICCV), Seoul, 2019, pp. 1314-1324.

[3] L. Bossard, M. Guillaumin, and L. Van Gool, "Food-101 – Mining discriminative components with random forests," in Proc. European Conf. Computer Vision (ECCV), 2014, pp. 446-461.

[4] K. Yanai and Y. Kawano, "Food image recognition using deep convolutional network with pre-training and fine-tuning," in Proc. IEEE Int. Conf. Multimedia & Expo Workshops (ICMEW), 2015, pp. 1-6.

[5] W3C, "Web Content Accessibility Guidelines (WCAG) 2.1," World Wide Web Consortium, 2018. [Online]. Available: https://www.w3.org/TR/WCAG21/

[6] J. P. Bigham et al., "VizWiz: Nearly real-time answers to visual questions," in Proc. 23rd Annual ACM Symp. User Interface Software and Technology, New York, 2010, pp. 333-342.

[7] M. Theodoridis, C. Agamanolis, and F. Muller, "Accessible nutrition: designing mobile food logging for visually impaired users," in Proc. ACM SIGACCESS Conf. Computers & Accessibility (ASSETS), 2022.

[8] Google LLC, "Cloud Vision API Documentation," 2024. [Online]. Available: https://cloud.google.com/vision/docs

[9] Nutritionix LLC, "Nutritionix API v2 Documentation," 2024. [Online]. Available: https://developer.nutritionix.com/

[10] N. Nielsen, "Usability Engineering," Morgan Kaufmann, 1993, pp. 115-148.
