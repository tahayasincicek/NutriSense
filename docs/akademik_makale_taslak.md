# AI-Powered Nutritional Assistance for Visually Impaired Individuals:
# A Mobile Application with Voice Feedback

> **Kapsam beyanı**
>
> Bu taslakta bildirilen bütün sayılar depoda yeniden üretilebilir kanıta
> sahiptir (deney `20260908T060321Z-b000d69c58`, mühürlü test). Taslak insan
> denekli değerlendirme içermez; kullanıcı çalışması yapılmamıştır ve
> yapılmadan kullanıcı performansı bildirilmeyecektir.

## Akademik Makale Taslağı (IEEE Conference Format)

**Hedef Konferanslar:** IEEE EMBC, ACM ASSETS, CHI, MobileHCI

---

## Title

**AI-Powered Nutritional Assistance for Visually Impaired Individuals: A Mobile Application with Voice Feedback**

## Authors

Taha Yasin Çiçek¹, Furkan Öztürk¹, Hakan Gündüz¹

¹ Kocaeli Üniversitesi, Yazılım Mühendisliği Bölümü, Kocaeli, Türkiye

---

## Abstract (English — 250 words)

Visually impaired individuals face significant challenges in independently tracking their nutritional intake, as existing calorie-counting applications rely heavily on visual user interfaces. This paper presents NutriSense, a mobile application that leverages artificial intelligence and multimodal accessibility features to enable independent food recognition and nutritional tracking for visually impaired users.

NutriSense employs a dual-model approach for food recognition: Google Cloud Vision API for cloud-based label detection and a custom-trained MobileNetV3 model (INT8 quantized) for on-device inference. The application integrates the Nutritionix API, providing access to a database of over 800,000 food items with detailed nutritional information. All user interactions are facilitated through Turkish text-to-speech (TTS) synthesis and voice command recognition, eliminating the need for visual screen interaction.

The system architecture follows a feature-first Flutter framework for cross-platform deployment (Android/iOS) with a Python FastAPI backend. Accessibility compliance targets WCAG 2.1 AA guidelines, implementing semantic labeling, minimum touch targets (44×44dp), high-contrast mode, and priority-based TTS queuing.

We report the technical evaluation of the system. An on-device MobileNetV3Large classifier covering 130 food classes, roughly 90 of them Turkish dishes, reaches 79.2% top-1 and 92.1% top-3 accuracy on a single-use sealed test set of 12,619 images. Because a blind user cannot visually verify an answer, the system rejects low-confidence predictions rather than logging them: at a confidence threshold selected on the validation split alone, it answers 50.1% of inputs and is correct in 90.6% of the answers it gives. Nutrition values are not estimated by the model but read from a 556-record local catalogue, 488 records extracted verbatim from a SHA-256 pinned USDA FNDDS archive. A usability study with visually impaired participants has not yet been conducted; no user performance figures are reported here.

**Keywords:** assistive technology, computer vision, accessibility, nutrition tracking, visually impaired, mobile application, deep learning, voice interface

---

## Özet (Türkçe — 250 kelime)

Görme engelli bireyler, mevcut kalori takip uygulamalarının görsel arayüze dayalı yapısı nedeniyle beslenme takibinde önemli güçlüklerle karşılaşmaktadır. Bu çalışma, yapay zeka ve çok modlu erişilebilirlik özelliklerini kullanarak görme engelli kullanıcıların bağımsız besin tanıma ve beslenme takibi yapmasını sağlayan NutriSense mobil uygulamasını sunmaktadır.

NutriSense, besin tanıma için ikili model yaklaşımı kullanmaktadır: bulut tabanlı etiket tespiti için Google Cloud Vision API ve cihaz üzerinde çıkarım için özel eğitilmiş MobileNetV3 modeli (INT8 kuantize). Uygulama, 800.000'den fazla besin öğesi içeren Nutritionix API ile entegre edilmiştir. Tüm kullanıcı etkileşimleri Türkçe metin-ses sentezi (TTS) ve sesli komut tanıma aracılığıyla gerçekleştirilmektedir.

Sistem mimarisi, çapraz platform dağıtımı (Android/iOS) için feature-first Flutter çerçevesi ve Python FastAPI backend kullanmaktadır. Erişilebilirlik uyumluluğu WCAG 2.1 AA yönergelerini hedeflemektedir.

Bu çalışmada sistemin teknik değerlendirmesi bildirilmektedir. 130 besin sınıfını kapsayan cihaz üstü MobileNetV3Large sınıflandırıcısı — yaklaşık 90'ı Türk yemeği — 12.619 örneklik tek kullanımlık mühürlü test kümesinde %79,2 ilk-bir ve %92,1 ilk-üç doğruluğuna ulaşmaktadır. Görme engelli kullanıcı verilen cevabı görsel olarak doğrulayamadığından sistem, düşük güvenli tahminleri kaydetmek yerine reddeder: yalnız doğrulama kümesinde seçilen güven eşiğinde girdilerin %50,1'ine cevap verir ve verdiği cevapların %90,6'sı doğrudur. Besin değerleri model tarafından tahmin edilmez; 556 kayıtlık yerel katalogdan okunur, bunların 488'i SHA-256 ile sabitlenmiş USDA FNDDS arşivinden birebir çıkarılmıştır. Görme engelli katılımcılarla kullanılabilirlik çalışması henüz yapılmamıştır; bu çalışmada kullanıcı performansına dair sayı bildirilmemektedir.

**Anahtar Kelimeler:** yardımcı teknoloji, bilgisayarlı görü, erişilebilirlik, beslenme takibi, görme engelli, mobil uygulama, derin öğrenme, sesli arayüz

---

## I. Introduction

[Bu bölüm problem tanımı, motivasyon ve katkıları içerecek — TÜBİTAK raporu Bölüm 2 baz alınarak genişletilecek]

---

## II. Related Work

### A. Food Recognition Systems

Food recognition using deep learning has advanced significantly in recent years. Bossard et al. [1] introduced Food-101, a benchmark dataset comprising 101 food categories with 1,000 images each. Yanai and Kawano [2] demonstrated the effectiveness of CNN-based transfer learning for food image classification. More recently, MobileNet architectures [3] have enabled efficient on-device food recognition suitable for mobile deployment.

### B. Assistive Technology for Visually Impaired Users

Bigham et al. [4] developed VizWiz, a system that provides near real-time answers to visual questions from blind users. BeSpecular [5] and Seeing AI [6] have demonstrated the viability of AI-powered visual assistance. However, these systems are general-purpose and do not specifically address nutritional tracking needs.

### C. Accessible Nutrition Applications

Limited research exists on nutrition-specific accessibility. Theodoridis et al. [7] explored accessible food logging interfaces but relied primarily on manual text entry. Our work differs by integrating automatic visual food recognition with comprehensive voice feedback, eliminating the need for text-based interaction.

---

## III. System Architecture

[Figür 1: Sistem Mimarisi Diyagramı gerekli]

### A. Mobile Client (Flutter)
### B. Backend API (FastAPI)
### C. Food Recognition Pipeline
### D. Accessibility Layer

---

## IV. Evaluation Protocol

### A. Dataset and Leakage Control

96,047 images across 130 food classes plus 11,921 out-of-scope samples, drawn
from three sources (Apache-2.0 Turkish set, Food-101, and one Turkish set with
no declared licence, used locally and never redistributed). Splits are assigned
by capture group; exact and near-duplicate images (perceptual dHash) are unioned
into the same group so that a dish photographed twice cannot straddle train and
test. 79 files carrying conflicting labels across sources were removed.

### B. Decision Threshold

A blind user cannot visually verify an answer, so a wrong answer costs more than
a refusal. The system therefore abstains below a confidence threshold. The
threshold is selected on the validation split only, under the constraint
"answer at least 50% of inputs and be wrong in at most 10% of the answers
given". The sealed test set is opened once and never used for selection.

### C. Deployment Equivalence

The exported TFLite artefact must reproduce the trained model's decision on
every checked sample; a format whose argmax disagrees even once is rejected.

### D. Usability Study — Not Yet Conducted

The study design, participant criteria, task list and statistical plan are
registered before data collection. No participant data has been collected and
no user-performance result is reported in this paper.

---

## V. Results

### A. Recognition Accuracy

| Metric | Validation | Sealed test |
|---|---|---|
| Top-1 accuracy | 0.7852 | **0.7918** |
| Macro F1 | 0.7732 | **0.7793** |
| Top-3 accuracy | 0.9184 | **0.9215** |
| ECE (15 bins) | 0.0088 | **0.0536** |

### B. Selective Prediction

| Measure | Validation | Sealed test | Constraint |
|---|---|---|---|
| Coverage | 0.5034 | **0.5007** | ≥ 0.50 |
| Selective error | 0.0999 | **0.0937** | ≤ 0.10 |

Threshold 0.9644, fixed from validation.

### C. Scope Ablation

An initial 205-class scope reached only 0.660 accuracy and failed the selective
constraint (25.3% error at 50% coverage). Narrowing the scope to 130 classes by
cuisine relevance and increasing backbone capacity raised accuracy by 13.6
points. Scope selection used validation results only.

### D. Deployment Artefact

| Format | Status | Size | Argmax agreement |
|---|---|---|---|
| float16 | Deployed | 5.96 MB | 1.000 |
| float32 | Verified | 11.9 MB | 1.000 |
| int8 | **Rejected** | — | 0.12 |

Post-training INT8 quantisation broke the model's decisions; MobileNetV3's
hard-swish activations do not survive naive quantisation. The equivalence gate
rejected the format automatically.

---

## VI. Discussion

The contribution is twofold. First, a Turkish-cuisine food recogniser that runs
on device and covers 130 foods with a documented nutrition source for every
class. Second, an evaluation protocol in which the accuracy claims are enforced
by gates in the codebase rather than asserted in prose: the sealed test opens
once, the threshold cannot be chosen on test data, unlicensed data cannot enter
training, and a deployment artefact that disagrees with the trained model is
refused. Both the INT8 format and the 205-class scope were rejected by these
gates during this work.

The main limitation is that no user-facing claim is yet supported: whether the
system actually improves nutrition tracking for blind users remains untested.

---

## VII. Conclusion

We present an on-device Turkish food recognition system with source-traceable
nutrition data and an abstention mechanism tuned for users who cannot verify
the answer visually. On a sealed test set the system answers half of the inputs
and is correct in 90.6% of those answers. A usability study with visually
impaired participants is the next step.

---

## Gerekli Figürler Listesi

| Figür No | Açıklama | Tip |
|----------|----------|-----|
| Fig. 1 | Sistem mimarisi (Flutter → FastAPI → Vision API → Nutritionix) | Blok diyagram |
| Fig. 2 | MobileNetV3 model eğitim süreci (accuracy/loss eğrileri) | Grafik |
| Fig. 3 | Uygulama ekran görüntüleri (kamera, sonuç, geçmiş) | Ekran görüntüsü |
| Fig. 4 | Besin tanıma pipeline akışı | Akış diyagramı |
| Fig. 5 | Kapsama–seçici hata eğrisi ve seçilen eşik | Çizgi grafik |
| Fig. 6 | Sınıf bazlı F1 dağılımı | Histogram |
| Fig. 7 | Erişilebilirlik katmanı mimarisi (TTS + Voice Command) | UML bileşen |

---

## References (IEEE Format)

[1] L. Bossard, M. Guillaumin, and L. Van Gool, "Food-101 – Mining discriminative components with random forests," in *Proc. European Conf. Computer Vision (ECCV)*, 2014, pp. 446-461.

[2] K. Yanai and Y. Kawano, "Food image recognition using deep convolutional network with pre-training and fine-tuning," in *Proc. IEEE Int. Conf. Multimedia & Expo Workshops (ICMEW)*, 2015, pp. 1-6.

[3] A. Howard et al., "Searching for MobileNetV3," in *Proc. IEEE/CVF Int. Conf. Computer Vision (ICCV)*, Seoul, 2019, pp. 1314-1324.

[4] J. P. Bigham et al., "VizWiz: Nearly real-time answers to visual questions," in *Proc. 23rd Annual ACM Symp. User Interface Software and Technology*, New York, 2010, pp. 333-342.

[5] BeSpecular, "BeSpecular: Help the blind see," 2018. [Online]. Available: https://www.bespecular.com/

[6] Microsoft, "Seeing AI: A free app for people who are blind," 2024. [Online]. Available: https://www.microsoft.com/en-us/seeing-ai

[7] M. Theodoridis, C. Agamanolis, and F. Muller, "Accessible nutrition: Designing mobile food logging for visually impaired users," in *Proc. ACM SIGACCESS Conf. Computers & Accessibility (ASSETS)*, 2022.

[8] W3C, "Web Content Accessibility Guidelines (WCAG) 2.1," World Wide Web Consortium, 2018. [Online]. Available: https://www.w3.org/TR/WCAG21/

[9] Google LLC, "Cloud Vision API Documentation," 2024. [Online]. Available: https://cloud.google.com/vision/docs

[10] Nutritionix LLC, "Nutritionix API v2 Documentation," 2024. [Online]. Available: https://developer.nutritionix.com/

[11] World Health Organization, "World report on vision," Geneva, 2019.

[12] J. Nielsen, "Usability Engineering," Morgan Kaufmann, 1993, pp. 115-148.
