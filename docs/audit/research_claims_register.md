# Araştırma İddiaları Kayıt Defteri

**Denetim tarihi:** 17 Temmuz 2026  
**Kapsam:** Kaynak TÜBİTAK PDF’indeki sayısal hedefler ile `docs/tubitak_sonuc_raporu.md` ve `docs/akademik_makale_taslak.md` içindeki nicel/sonuç iddiaları.

> **ARAŞTIRMA BÜTÜNLÜĞÜ UYARISI**  
> Depoda etik kurul kararı, kurum izni, katılımcı onam kayıtları, anket ham verisi, kullanılabilirlik oturum ham verisi, veri sözlüğü ve istatistik analiz betiği bulunmamıştır. Bu nedenle aşağıdaki ampirik sonuçların tümü **“RAPORDA KULLANILMAMALI — doğrulanmamış taslak değer”** statüsündedir. Sayılar silinmemiş, yeniden üretilmiş veya gerçek sonuç gibi aktarılmamıştır.

> **8 Eylül 2026 güncellemesi — çözüm**
>
> Aşağıda "RAPORDA KULLANILMAMALI" işaretli ampirik iddiaların tamamı
> `tubitak_sonuc_raporu.md` ve `akademik_makale_taslak.md` belgelerinden
> **çıkarılmıştır**. İddialar doğrulanmamış, kaldırılmıştır; yerlerine yalnız
> depoda yeniden üretilebilir kanıtı olan teknik ölçümler yazılmıştır
> (deney `20260908T060321Z-b000d69c58`, mühürlü test). Her iki belge de
> kullanıcı çalışmasının yapılmadığını açıkça bildirmektedir. Bu kayıt defteri
> tarihsel iz olarak korunmaktadır.

## Doğrulama ölçeği

- **Doğrulandı — plan/belge:** Sayı kaynak PDF’de gerçekten yazılıdır; bu, planın gerçekleştirildiği anlamına gelmez.
- **Doğrulanmadı:** Sayı bir taslakta yazılıdır fakat ham veri ve analiz yoktur.
- **Çelişkili:** Aynı metinlerde birbirini tutmayan değerler vardır.
- **RAPORDA KULLANILMAMALI:** TÜBİTAK sonuç raporu, makale, sunum, basın metni veya mağaza açıklamasında gerçek bulgu olarak kullanılamaz.

## 1. PDF’deki plan, eşik, zaman ve bütçe sayıları

Bu bölümdeki değerler **ampirik sonuç değil**, kaynak başvurudaki plan/taahhüttür.

| ID | Nicel taahhüt | Kaynak | Ham/gerçekleşme kanıtı | Yeniden üretim | Durum |
|---|---|---|---|---|---|
| PLAN-01 | Literatürde en az **20** çalışma/rapor incelenecek. | PDF İş-Zaman Çizelgesi, s.5 | Literatür matrisi yok; PDF kaynakçası yaklaşık 12 kayıt. | Yok; önce doğrulanmış kaynak matrisi gerekir. | Plan doğrulandı; gerçekleşme **kanıtsız**. |
| PLAN-02 | Literatür iş paketi başarı eşiği **≥%90**. | PDF İş-Zaman Çizelgesi, s.5 | Görev paydası/izleme kaydı yok. | Yok. | Plan doğrulandı; gerçekleşme **kanıtsız**. |
| PLAN-03 | İş paketleri **0–2, 2–6, 6–8, 8–9, 9–10 ay** aralıklarında. | PDF İş-Zaman Çizelgesi, s.5 | Tarihli proje günlüğü, milestone veya sürüm etiketi yok. | Yok. | Plan doğrulandı; gerçekleşme **kanıtsız**. |
| PLAN-04 | RAM+SSD için **4.500 TL** sarf kalemi. | PDF Bütçe, s.8 | Fatura/ödeme/teslim kaydı yok. | Mali mutabakat dosyası yok. | Plan doğrulandı; harcama **kanıtsız**. |
| PLAN-05 | Android+iOS geliştirme için **4.500 TL** hizmet alımı. | PDF Bütçe, s.8 | Sözleşme/fatura/teslim yok; iOS artefaktı yok. | Mali mutabakat dosyası yok. | Plan doğrulandı; harcama **kanıtsız**. |
| PLAN-06 | Toplam bütçe **9.000 TL**. | PDF Bütçe, s.8 | Gerçekleşen harcama dökümü yok. | Mali mutabakat dosyası yok. | Plan doğrulandı; gerçekleşme **kanıtsız**. |

## 2. Örneklem ve yöntem iddiaları

| ID | İddia | Kaynak | Gerekli ham veri/artefakt | Mevcut yeniden üretim komutu | Doğrulama ve kullanım durumu |
|---|---|---|---|---|---|
| CLM-001 | Çalışma **20 görme engelli yetişkinle** yapıldı. | `tubitak_sonuc_raporu.md:24,76,144,173`; `akademik_makale_taslak.md:30,44` | Etik karar, katılımcı akış listesi, anonim ID’ler, onam envanteri, oturum satırları | **YOK — ham veri yok** | **RAPORDA KULLANILMAMALI — doğrulanmamış taslak değer.** |
| CLM-002 | Katılımcı yaş aralığı **18–55**, ortalama **32,4**. | `tubitak_sonuc_raporu.md:76` | Anonim yaş değişkeni ve dahil edilme kayıtları | **YOK** | **RAPORDA KULLANILMAMALI.** |
| CLM-003 | Katılımcıların **12’si** total görme engelli, **8’i** az gören. | `tubitak_sonuc_raporu.md:76` | Anonim görme düzeyi değişkeni ve sınıflama tanımı | **YOK** | **RAPORDA KULLANILMAMALI.** Toplam 20 ile aritmetik uyum, gerçeklik kanıtı değildir. |
| CLM-004 | Kullanılabilirlik testi **6 görevden** oluştu. | `tubitak_sonuc_raporu.md:80` | Protokol sürümü, görev formu, her katılımcı×görev satırı | **YOK** | **RAPORDA KULLANILMAMALI**; form niyeti var, uygulama kanıtı yok. |
| CLM-005 | Anket **8 soru**: **4 Likert + 1 çoktan seçmeli + 1 evet/hayır + 2 açık uçlu**. | `tubitak_sonuc_raporu.md:81` | Kullanılan kesin form sürümü ve cevap export’u | **YOK** | Taslak yöntem olarak kullanılabilir; “uygulandı” sonucu **RAPORDA KULLANILMAMALI**. |
| CLM-006 | Uzun vadeli gelecek çalışma **3–6 ay** olmalı. | `tubitak_sonuc_raporu.md:166` | Gelecek protokol | Uygulanamaz | Bu bir öneridir, gerçekleşmiş sonuç değildir. |

## 3. Kullanılabilirlik görev sonuçları

Her satır için gerekli ham veri: `participant_id`, `task_id`, `start_time`, `end_time`, `duration_seconds`, `success`, `failure_reason`, `device`, `app_version`, `observer_id`; ayrıca protokol ve veri sözlüğü. Bunların hiçbiri depoda bulunmadı.

| ID | Görev sonucu iddiası | Kaynak | Mevcut yeniden üretim komutu | Doğrulama ve kullanım durumu |
|---|---|---|---|---|
| CLM-010 | Uygulama girişi: ort. **8,3 sn**, başarı **%100**, SS **2,1**. | `tubitak_sonuc_raporu.md:92` | **YOK — oturum verisi yok** | **RAPORDA KULLANILMAMALI.** Ayrıca aktif uygulama login ekranını atlıyor ve login ekranı simülasyon yapıyor. |
| CLM-011 | Besin tarama: ort. **12,7 sn**, başarı **%90**, SS **4,5**. | `tubitak_sonuc_raporu.md:93` | **YOK** | **RAPORDA KULLANILMAMALI.** Aktif kamera-backend sözleşmesi uyumsuz. |
| CLM-012 | Geçmiş görüntüleme: ort. **15,2 sn**, başarı **%85**, SS **5,8**. | `tubitak_sonuc_raporu.md:94` | **YOK** | **RAPORDA KULLANILMAMALI.** Aktif geçmiş ekranı mock veri gösteriyor. |
| CLM-013 | Diyetisyene gönderme: ort. **22,4 sn**, başarı **%80**, SS **7,2**. | `tubitak_sonuc_raporu.md:95` | **YOK** | **RAPORDA KULLANILMAMALI.** Diyetisyen atama simüle; teslimat kanıtı yok. |
| CLM-014 | Ayar değiştirme: ort. **11,6 sn**, başarı **%90**, SS **3,9**. | `tubitak_sonuc_raporu.md:96` | **YOK** | **RAPORDA KULLANILMAMALI.** İlgili ekranda analyzer hatası da var. |
| CLM-015 | Sesli komut: ort. **6,8 sn**, başarı **%95**, SS **2,3**. | `tubitak_sonuc_raporu.md:97` | **YOK** | **RAPORDA KULLANILMAMALI.** Gerçek cihaz/mikrofon testi yok. |
| CLM-016 | Genel ortalama: **12,8 sn**, başarı **%90**, SS **4,3**. | `tubitak_sonuc_raporu.md:98`; makale satır 30/44 | **YOK** | **RAPORDA KULLANILMAMALI.** “Genel SS” hesap yöntemi tanımlı değil. |
| CLM-017 | Özet görev tamamlama oranı **%85**. | `tubitak_sonuc_raporu.md:24` | **YOK** | **RAPORDA KULLANILMAMALI — ÇELİŞKİLİ:** görev tablosu/genel ve makale **%90** diyor. |
| CLM-018 | Özet ortalama besin tarama süresi **4,2 sn**. | `tubitak_sonuc_raporu.md:24` | **YOK** | **RAPORDA KULLANILMAMALI — ÇELİŞKİLİ:** görev tablosu **12,7 sn**; **4,2** başka yerde memnuniyet puanı. Olası kopyalama hatasıdır. |
| CLM-019 | Katılımcıların **%90’ı** uygulamayı kullanışlı/çok kullanışlı buldu. | `tubitak_sonuc_raporu.md:24` | **YOK — ilgili soru ham dağılımı yok** | **RAPORDA KULLANILMAMALI.** Hangi soru/ölçek ve payda belirsiz. |

## 4. Karşılaştırma ve istatistik iddiaları

Gerekli ham veri: katılımcı bazında NutriSense ve geleneksel yöntem süreleri, eşleştirme durumu, eksik veri, aykırı değer kuralları, analiz planı ve kullanılan yazılım/sürüm. Bunlar yoktur.

| ID | İddia | Kaynak | Mevcut yeniden üretim komutu | Doğrulama ve kullanım durumu |
|---|---|---|---|---|
| CLM-020 | Geleneksel yöntem ortalaması **45,3 sn**. | `tubitak_sonuc_raporu.md:105`; makale satır 30/44 | **YOK** | **RAPORDA KULLANILMAMALI.** |
| CLM-021 | NutriSense karşılaştırma ortalaması **12,7 sn**. | `tubitak_sonuc_raporu.md:105`; makale satır 30/44 | **YOK** | **RAPORDA KULLANILMAMALI.** |
| CLM-022 | Mann–Whitney **U=12,5**. | `tubitak_sonuc_raporu.md:108` | **YOK** | **RAPORDA KULLANILMAMALI.** Eşleştirilmiş aynı katılımcılar söz konusuysa Mann–Whitney seçimi ayrıca gerekçelendirilmelidir. |
| CLM-023 | **p<0,001**. | `tubitak_sonuc_raporu.md:109,112`; makale satır 30/44 | **YOK** | **RAPORDA KULLANILMAMALI.** Kesin p veya yazılım çıktısı yok. |
| CLM-024 | Cohen’s **d=2,84** ve “büyük etki”. | `tubitak_sonuc_raporu.md:110`; makale satır 30/44 | **YOK** | **RAPORDA KULLANILMAMALI.** U testiyle birlikte hangi d formülünün kullanıldığı tanımsız. |
| CLM-025 | H0 reddedildi; sistem süreyi istatistiksel anlamlı azalttı. | `tubitak_sonuc_raporu.md:112` | **YOK** | **RAPORDA KULLANILMAMALI.** CLM-020–024 doğrulanmadan sonuç çıkarılamaz. |
| CLM-026 | Süre azalması **%72** (`45,3→12,7`). | `tubitak_sonuc_raporu.md:138` | **YOK** | Aritmetik yaklaşık uyumludur, fakat girdiler kanıtsız olduğundan **RAPORDA KULLANILMAMALI**. |
| CLM-027 | **%90** başarı, literatürdeki **%78** eşiğinin üzerindedir. | `tubitak_sonuc_raporu.md:138` | **YOK** | **RAPORDA KULLANILMAMALI.** %90 ham verisiz; “Jacobsen (2002) %78 eşiği” bibliyografik olarak doğrulanmadı. |

## 5. Anket puanları ve oranları

Gerekli ham veri: katılımcı×soru cevap matrisi, kodlama (`1–5`), eksik cevaplar, soru sırası/sürümü ve analiz betiği. Bunlar yoktur.

| ID | İddia | Kaynak | Mevcut yeniden üretim komutu | Doğrulama ve kullanım durumu |
|---|---|---|---|---|
| CLM-030 | S2 sesli geri bildirim: ort. **4,3/5**, SS **0,73**. | `tubitak_sonuc_raporu.md:118,140` | **YOK** | **RAPORDA KULLANILMAMALI.** |
| CLM-031 | S3 tarama kolaylığı: ort. **4,1/5**, SS **0,85**. | `tubitak_sonuc_raporu.md:119` | **YOK** | **RAPORDA KULLANILMAMALI.** |
| CLM-032 | S4 sonuçlara güven: ort. **3,8/5**, SS **0,92**. | `tubitak_sonuc_raporu.md:120,141` | **YOK** | **RAPORDA KULLANILMAMALI.** |
| CLM-033 | S8 genel değerlendirme: ort. **4,2/5**, SS **0,68**. | `tubitak_sonuc_raporu.md:121`; makale satır 30/44 | **YOK** | **RAPORDA KULLANILMAMALI.** |
| CLM-034 | Diyetisyen bildirimi: **Evet %65, Belki %25, Hayır %10**. | `tubitak_sonuc_raporu.md:123` | **YOK** | Yüzdeler 100’e toplansa da **RAPORDA KULLANILMAMALI**; n=20 ise varsayımsal 13/5/2 sayımları ham veri yerine konamaz. |

## 6. Nitel ve ürün tamamlanma iddiaları

| ID | İddia | Kaynak | Gerekli kanıt | Durum |
|---|---|---|---|---|
| CLM-040 | Belirli iki katılımcı alıntısı gerçekten söylendi. | `tubitak_sonuc_raporu.md:129-130` | Anonim kaynak not/transkript, onam, kodlama izi | **RAPORDA KULLANILMAMALI**; alıntılar doğrulanamıyor. |
| CLM-041 | Bağımsızlık, sesli komut memnuniyeti ve iyileştirme önerileri veri temalarıdır. | `tubitak_sonuc_raporu.md:128-131` | Kod kitabı, kodlanmış veri, tema oluşturma süreci | **RAPORDA KULLANILMAMALI.** |
| CLM-042 | Android+iOS mobil uygulama tamamlandı. | Eski sonuç taslağı | Android+iOS release build, kabul testi | **ÇELİŞKİLİ; RAPORDA KULLANILMAMALI.** iOS kaynak iskeleti hazırlanmıştır fakat Xcode build/archive, IPA/TestFlight ve gerçek iPhone/VoiceOver kanıtı yoktur; Android fiziksel release kabulü de eksiktir. |
| CLM-043 | FastAPI backend tamamlandı. | `tubitak_sonuc_raporu.md:171` | Deploy, migrasyon, test, sağlık ve sözleşme raporu | **RAPORDA KULLANILMAMALI.** Refresh/logout ve diyetisyen atama eksik; test yok. |
| CLM-044 | MobileNetV3 besin tanıma modeli tamamlandı. | `tubitak_sonuc_raporu.md:172` | Model/checkpoint/veri/metrik/model card | **ÇELİŞKİLİ; RAPORDA KULLANILMAMALI.** Gerçek model dosyası yok. |
| CLM-045 | Kullanılabilirlik testi (`n=20`) tamamlandı. | `tubitak_sonuc_raporu.md:173` | Etik/onam/ham veri/analiz | **RAPORDA KULLANILMAMALI.** |
| CLM-046 | Araştırma anketi tamamlandı. | `tubitak_sonuc_raporu.md:174` | Etik/onam/ham cevap export’u | **RAPORDA KULLANILMAMALI.** |
| CLM-047 | Sistem bağımsızlığı artırır ve beslenme takibini önemli ölçüde kolaylaştırır. | `tubitak_sonuc_raporu.md:138,155` | Geçerli ölçek, karşılaştırma, güven aralığı, sınırlama analizi | **RAPORDA KULLANILMAMALI.** Nedensel/etki iddiası kanıtsızdır. |

## 7. İç tutarsızlıklar ve kırmızı bayraklar

1. **Görev tamamlama:** özet `%85`, tablo ve makale `%90` söylüyor.
2. **Besin tarama süresi:** özet `4,2 sn`, görev tablosu/karşılaştırma `12,7 sn` söylüyor; `4,2` ayrıca genel değerlendirme puanı olarak geçiyor.
3. **Yöntem:** PDF t-testi ve ki-kare planlıyor; sonuç taslağı yalnız Mann–Whitney U ve Cohen’s d veriyor. Veri/varsayım gerekçesi yok.
4. **Platform:** sonuç taslağı Android+iOS tamamlandı diyor; iOS kaynakları hazırlanmış olsa da Xcode build/archive, IPA/TestFlight ve gerçek iPhone/VoiceOver kanıtı yok.
5. **Model:** sonuç taslağı MobileNetV3 tamamlandı diyor; model/checkpoint/TFLite yok.
6. **Saha çalışması:** `n=20` ve katılımcı alıntıları var; etik karar, kurum izni, onam ve ham veri yok.
7. **Ürün durumu:** “tamamlandı” denilen üründe auth bypass, mock geçmiş, API contract uyuşmazlığı, analyzer hataları ve çözülemeyen bağımlılık var.

## 8. Gelecekte kullanılacak yeniden üretim sözleşmesi

Şu anda çalıştırılabilir bir araştırma yeniden üretim komutu **yoktur**. Ham veri üretilmeden örnek CSV veya sahte analiz çıktısı oluşturulmamalıdır. Etik onaylı gerçek veri toplandıktan sonra önerilen sözleşme:

```text
research/
  protocol/protocol_v1.pdf
  ethics/approval_redacted.pdf
  data/raw/                       # erişimi kısıtlı, kimliksiz
  data/processed/
  data_dictionary.md
  analysis/requirements.lock
  analysis/run_analysis.py
  outputs/tables/
  outputs/figures/
  outputs/statistics.json
  MANIFEST.sha256
```

Önerilen tek giriş noktası, gerçek dosyalar oluştuktan sonra:

```powershell
python research/analysis/run_analysis.py `
  --raw research/data/raw `
  --out research/outputs `
  --seed 2209
```

Kabul koşulları:

- Komut temiz ortamda aynı tabloları, grafikleri ve `statistics.json` dosyasını üretir.
- Her rapor iddiası bu dosyadaki benzersiz bir anahtara bağlanır.
- Örneklem dışlama ve eksik veri kararları loglanır.
- Test seçimi ve etki büyüklüğü formülü önceden tanımlanır.
- Çıktılar güven aralıklarını, kesin p değerini ve sınırlamaları içerir.
- Katılımcı kimliği veya doğrudan kişisel veri repoya girmez.

## 9. Yayın kapısı

Aşağıdaki koşullar birlikte sağlanmadan `tubitak_sonuc_raporu.md` ve `akademik_makale_taslak.md` içindeki ampirik sayılar dış paylaşımda kullanılmamalıdır:

1. Etik kurul kararı ve gerekiyorsa kurum izni doğrulanmış olmalı.
2. Onamlar onaylı protokol sürümüne bağlı olmalı.
3. Anonim ham veri ve veri sözlüğü mevcut olmalı.
4. Analiz tek komutla yeniden üretilmeli.
5. CLM-017/018 çelişkileri gerçek veriye göre çözülmeli.
6. Bağımsız bir denetçi örnek satırlardan yayın tablosuna iz sürebilmeli.
7. Kaynakça ve `%78` eşik iddiası bibliyografik olarak doğrulanmalı.

Bu denetim audit-only talimatına uygun olarak mevcut sonuç raporu ve makale taslağını değiştirmedi. Koruyucu işaretleme bu kayıt defterinde yapıldı; bir sonraki belge-düzeltme aşamasında kaynak taslakların üstüne de görünür “doğrulanmamış taslak” bandı eklenmelidir.
