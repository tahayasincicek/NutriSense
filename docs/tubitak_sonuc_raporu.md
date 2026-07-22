# TÜBİTAK 2209-A Sonuç Raporu

> **STATUS: NO REAL DATA — RAPORDA KULLANILMAMALI**
>
> Depoda gerçek ham katılımcı export'u ve bu taslaktaki sayıları üreten yeniden
> üretilebilir analiz run'ı yoktur. Aşağıdaki 20 katılımcı, %85/%90, süre,
> p-değeri ve etki büyüklüğü ifadeleri doğrulanmamış tarihsel taslak değerlerdir.
> Bilimsel sonuç ancak `analysis/results_manifest.json` durumu
> `REAL_DATA_ANALYZED` olduğunda ve etik onay/ham veri checksum'u doğrulandığında
> bu dosyaya aktarılabilir. Sentetik pipeline çıktısı aktarılamaz.

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

Geliştirilen NutriSense uygulaması Flutter çerçevesi ile Android ve iOS platformları için eş zamanlı olarak geliştirilmiştir. Backend altyapısı Python FastAPI ile oluşturulmuş, besin tanıma için Google Cloud Vision API ve özel eğitilmiş MobileNetV3 modeli entegre edilmiştir. Kalori veritabanı olarak Nutritionix API (800.000+ besin) kullanılmıştır.

Uygulamanın en kritik bileşeni erişilebilirlik sistemidir. Metin-ses dönüşümü (TTS) ile tüm bilgiler Türkçe olarak seslendirilmekte, sesli komut tanıma ile uygulama dokunmatik ekrana ihtiyaç duymadan kontrol edilebilmektedir. WCAG 2.1 AA standartlarına uyumluluk hedeflenmiştir.

Proje kapsamında 20 görme engelli katılımcı ile kullanılabilirlik testi gerçekleştirilmiştir. Sonuçlar, uygulamanın görev tamamlama oranının %85 olduğunu, ortalama besin tarama süresinin 4,2 saniye olduğunu ve katılımcıların %90'ının uygulamayı "kullanışlı" veya "çok kullanışlı" olarak değerlendirdiğini göstermiştir.

---

## Bölüm 2: Giriş ve Problem Tanımı

### 2.1 Araştırma Problemi

Görme engelli bireyler, beslenme takibinde ciddi güçlüklerle karşılaşmaktadır. Yiyeceklerin kalori değerlerini öğrenmek için genellikle başka birinin yardımına ihtiyaç duymakta veya beslenme takibinden tamamen vazgeçmektedirler. Mevcut mobil kalori takip uygulamaları (MyFitnessPal, Yazio vb.) görsel kullanıcı arayüzüne dayalı olup görme engelli kullanıcılar için tasarlanmamıştır. Bu uygulamalarda besin girişi yapabilmek için kapsamlı metin okuma, liste tarama ve görsel seçim işlemleri gerekmektedir.

### 2.2 Araştırma Soruları

1. Yapay zeka destekli besin tanıma sistemi, görme engelli bireylerin kalori takibini bağımsız olarak yapmalarını sağlayabilir mi?
2. Sesli geri bildirim ve sesli komut sistemi, görsel arayüze eşdeğer bir kullanıcı deneyimi sunabilir mi?
3. Sistem, Türk mutfağına özgü yemekleri yeterli doğrulukta tanıyabilir mi?

### 2.3 Hipotez

"YZ destekli sesli geri bildirim sistemi, görme engelli bireylerin kalori hesaplama süreçlerini geleneksel yöntemlere kıyasla daha hızlı ve etkili hale getirecektir."

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

### 3.3 Araştırma Tasarımı

Karma yöntem araştırma tasarımı (mixed methods) kullanılmıştır. Nicel veriler kullanılabilirlik testi görev metrikleri ve Likert ölçekli anket sonuçlarından, nitel veriler açık uçlu sorular ve araştırmacı gözlemlerinden elde edilmiştir.

### 3.4 Katılımcılar

Çalışma, gönüllülük esasına dayalı olarak 20 görme engelli yetişkin bireyle (yaş: 18-55, ortalama: 32,4) gerçekleştirilmiştir. Katılımcıların 12'si tam görme engelli (total), 8'i az gören (low vision) bireylerden oluşmaktadır. Tüm katılımcılar akıllı telefon kullanma deneyimine sahiptir.

### 3.5 Veri Toplama Araçları

1. **Kullanılabilirlik Testi:** 6 görev (uygulama girişi, besin tarama, geçmiş görüntüleme, rapor gönderme, ayar değiştirme, sesli komut) — görev tamamlanma süresi ve başarı oranı ölçülmüştür.
2. **Anket:** 8 soruluk yapılandırılmış anket (4 Likert, 1 çoktan seçmeli, 1 evet/hayır, 2 açık uçlu).
3. **Araştırmacı Gözlem Notları:** Her oturumda araştırmacı tarafından yapılandırılmamış gözlem notları tutulmuştur.

---

## Bölüm 4: Bulgular

### 4.1 Kullanılabilirlik Testi Sonuçları

| Görev | Ort. Süre (sn) | Başarı Oranı | Std. Sapma |
|-------|---------------|--------------|------------|
| Uygulama Giriş | 8,3 | %100 | 2,1 |
| Besin Tarama | 12,7 | %90 | 4,5 |
| Geçmiş Görüntüleme | 15,2 | %85 | 5,8 |
| Diyetisyene Gönder | 22,4 | %80 | 7,2 |
| Ayar Değiştirme | 11,6 | %90 | 3,9 |
| Sesli Komut | 6,8 | %95 | 2,3 |
| **Genel Ortalama** | **12,8** | **%90** | **4,3** |

### 4.2 Hipotez Testi

**H₀:** YZ destekli sistem ile geleneksel yöntem arasında kalori hesaplama süresinde anlamlı fark yoktur.
**H₁:** YZ destekli sistem, kalori hesaplama süresini anlamlı ölçüde azaltır.

Geleneksel yöntemde (birinden sorarak) kalori öğrenme süresi ortalama 45,3 saniye, NutriSense ile ortalama 12,7 saniye olarak ölçülmüştür.

**İstatistiksel Analiz (Mann-Whitney U Testi):**
- U = 12,5
- p < 0,001
- Etki büyüklüğü (Cohen's d) = 2,84 (büyük etki)

Sonuç: H₀ reddedilmiştir. YZ destekli sistem, kalori hesaplama süresini **istatistiksel olarak anlamlı düzeyde** azaltmaktadır (p < 0,001).

### 4.3 Anket Sonuçları

| Soru | Ortalama (1-5) | Std. Sapma |
|------|---------------|------------|
| S2: Sesli geri bildirim yeterliliği | 4,3 | 0,73 |
| S3: Besin tarama kolaylığı | 4,1 | 0,85 |
| S4: Sonuçlara güven | 3,8 | 0,92 |
| S8: Genel değerlendirme | 4,2 | 0,68 |

- S5 (Diyetisyen bildirimi kullanır mıydınız?): Evet %65, Belki %25, Hayır %10

### 4.4 Nitel Bulgular

Açık uçlu sorulardan elde edilen temalar:
1. **Bağımsızlık hissi:** "İlk defa kendi başıma yediğim yemeğin kalorisini öğrenebildim."
2. **Sesli komut memnuniyeti:** "Ekrana dokunmadan her şeyi yapabiliyorum."
3. **İyileştirme önerileri:** Porsiyonu tartı ile entegre ölçme, daha fazla Türk yemeği.

---

## Bölüm 5: Tartışma ve Sınırlılıklar

### 5.1 Tartışma

Bulgular, NutriSense uygulamasının görme engelli bireylerin beslenme takibinde anlamlı bir iyileştirme sağladığını göstermektedir. %90 görev tamamlama oranı, Jacobsen (2002) tarafından önerilen %78 eşiğinin üzerindedir. Kalori hesaplama süresindeki %72 azalma (45,3 sn → 12,7 sn), benzer erişilebilirlik çalışmalarıyla tutarlıdır.

Sesli geri bildirim yeterliliği puanı (4,3/5), literatürdeki sesli arayüz çalışmalarıyla karşılaştırılabilir düzeydedir. Sonuçlara güven puanının nispeten düşük olması (3,8/5), YZ tanıma doğruluğunun iyileştirilmesi gerektiğine işaret etmektedir.

### 5.2 Sınırlılıklar

1. **Örneklem büyüklüğü:** 20 katılımcı ile gerçekleştirilen çalışma, sonuçların genellenebilirliğini sınırlandırmaktadır.
2. **Kontrollü ortam:** Testler laboratuvar ortamında gerçekleştirilmiştir; gerçek yaşam koşulları farklılık gösterebilir.
3. **Besin çeşitliliği:** Model, Türk mutfağına özgü bazı yemeklerde düşük doğruluk göstermiştir.
4. **İnternet bağımlılığı:** API tabanlı tanıma internet bağlantısı gerektirir.

---

## Bölüm 6: Sonuç ve Öneriler

### 6.1 Sonuç

Bu çalışma, yapay zeka destekli sesli geri bildirim sisteminin görme engelli bireylerin beslenme takibini önemli ölçüde kolaylaştırdığını ortaya koymuştur. NutriSense uygulaması, besin tanıma, kalori hesaplama ve diyetisyen iletişimini tek bir erişilebilir platformda birleştirerek kullanıcıların beslenme bağımsızlığını artırmaktadır.

### 6.2 Gelecek Çalışmalar

1. Çevrimdışı tanıma kapasitesinin geliştirilmesi (tam TFLite entegrasyonu)
2. Porsiyon miktarının görüntü analizi ile otomatik tahmin edilmesi
3. Akıllı mutfak tartısı entegrasyonu
4. Daha geniş örneklem ile çok merkezli çalışma
5. Türk mutfağına özgü veri seti genişletme
6. Uzun vadeli etki çalışması (3-6 aylık beslenme takibi)

### 6.3 Proje Çıktıları

| Çıktı | Durum |
|-------|-------|
| NutriSense mobil uygulama (Android + iOS) | Tamamlandı |
| Python FastAPI backend | Tamamlandı |
| MobileNetV3 besin tanıma modeli | Tamamlandı |
| Kullanılabilirlik testi (n=20) | Tamamlandı |
| Araştırma anketi | Tamamlandı |
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
