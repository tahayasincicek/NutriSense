# NutriSense saha çalışması çalışma raporu

## Yönetici özeti

çalışmada 120 profil, kişi başına altı görev ve iki koşulla toplam 1,440 görev gözlemi üretildi. Ayrıca sekiz maddelik 960 anket yanıtı oluşturuldu. AB/BA sırası dengelendi ve profil düzeyinde eşleştirilmiş analiz uygulandı.

Üretilen senaryoda NutriSense koşulunun bağımsız görev başarı oranı %65.3 (Wilson %95 GA %61.7–%68.7), standartlaştırılmış yardım koşulunun oranı %46.0 (GA %42.4–%49.6) oldu. Profil düzeyindeki fark 19.3 yüzde puandır (bootstrap %95 GA 14.2–24.4). Bağımsız başarılı görevlerde medyan süre 26.8 ve 38.1 saniyedir; eşleştirilmiş süre farkı -10.9 saniyedir (GA -12.2–-9.6).

## Amaç ve araştırma soruları

1. Uygulama, çalışma senaryosunda görevlerin bağımsız tamamlanmasını artırıyor mu?
2. Başarılı görevlerin tamamlanma süresi azalıyor mu?
3. Görev türüne göre başarı, süre, hata ve yardım gereksinimi nasıl değişiyor?
4. Erişilebilirlik, güven, kullanım kolaylığı ve yeniden kullanım niyeti maddeleri nasıl dağılıyor?
5. Analiz hattı gerçek veri geldiğinde aynı şema ve kalite kapılarıyla çalışıyor mu?

## Tasarım

- Tasarım: aynı sanal profil içinde iki koşullu, eşleştirilmiş çapraz tasarım.
- Koşullar: `nutrisense` ve `standardized_assistance`.
- Görevler: t1–t6, her koşulda birer kez.
- Sıra: AB/BA, eşit dağılım.
- Örneklem: 120 çalışma profili.
- Veri üretimi: sabit tohumlu olasılıksal model; kişi yeteneği, görev güçlüğü, öğrenme/sıra etkisi, yardım düzeyi ve koşul etkisi birlikte kullanıldı.
- Birincil sonuçlar: bağımsız görev başarı oranı ile bağımsız başarılı görevlerin katılımcı medyan süresi.
- Analiz planı: `NS-HCI-SAP-1.0-FINAL`.
- Çalıştırma kimliği: `20260923T121634Z-35a4a4642b8b`.
- Birleşik SHA-256: `35a4a4642b8bfd474385bf4cfcede63d7a81cda719b3d707c20471d386e5f6a2`.

## Profil dağılımları

### Yaş grubu
- 18-24: 31 (%25.8)
- 25-34: 29 (%24.2)
- 35-44: 24 (%20.0)
- 45-54: 24 (%20.0)
- 55+: 12 (%10.0)

### Görme profili
- az_goren: 52 (%43.3)
- tam_gorme_kaybi: 68 (%56.7)

### Ekran okuyucu
- Diger: 7 (%5.8)
- TalkBack: 66 (%55.0)
- VoiceOver: 47 (%39.2)

### Yardımcı teknoloji deneyimi
- baslangic: 26 (%21.7)
- ileri: 38 (%31.7)
- orta: 56 (%46.7)

### Sıra dengelemesi
- AB: 60 (%50.0)
- BA: 60 (%50.0)

Bu değişkenler çeşitlilik sınaması için üretilmiştir; demografik gerçekliğe dair çıkarım yapılamaz.

## Görev sonuçları

| Görev | NutriSense bağımsız başarı | Kontrol bağımsız başarı | NutriSense medyan süre (sn) | Kontrol medyan süre (sn) |
|---|---:|---:|---:|---:|
| t1 | %75.8 | %45.8 | 23.4 | 34.8 |
| t2 | %68.3 | %51.7 | 29.0 | 42.0 |
| t3 | %59.2 | %40.0 | 36.6 | 57.2 |
| t4 | %72.5 | %47.5 | 25.2 | 42.5 |
| t5 | %62.5 | %48.3 | 34.5 | 48.7 |
| t6 | %53.3 | %42.5 | 41.0 | 61.6 |

İki eş-birincil sonuçta profil düzeyinde sign-flip permutation testi ve 10.000 tekrar bootstrap güven aralığı kullanıldı. İki p-değeri Holm yöntemiyle düzeltildi.

## Anket sonuçları

| Madde | n | Medyan | IQR aralığı | 1 / 2 / 3 / 4 / 5 sayıları |
|---|---:|---:|---:|---:|
| q2 | 120 | 4.0 | 4.0–5.0 | 0 / 1 / 20 / 55 / 44 |
| q3 | 120 | 4.0 | 4.0–5.0 | 0 / 1 / 25 / 61 / 33 |
| q4 | 120 | 4.0 | 3.0–5.0 | 0 / 1 / 30 / 55 / 34 |
| q8 | 120 | 4.0 | 4.0–5.0 | 0 / 3 / 26 / 56 / 35 |

### q1 — mevcut yöntem
- Besini tahmin ederek kayıt tutmadan devam ediyordum: 39 (%32.5)
- Bir yakınımdan yardım istiyordum: 32 (%26.7)
- İnternette ürün veya yemek adıyla arama yapıyordum: 30 (%25.0)
- Ambalaj bilgisini ekran okuyucuyla arıyordum: 19 (%15.8)

### q5 — yeniden kullanma niyeti
- Evet: 83 (%69.2)
- Belki: 31 (%25.8)
- Hayır: 6 (%5.0)

Sekiz madde doğrulanmış tek boyutlu bir ölçek olmadığı için toplam puan veya Cronbach alfa hesaplanmadı.

## Açık uçlu yanıt temaları

### Beğenilen yönler
- Kamera konumlandırma ipuçları yararlıydı ancak daha kısa olabilir. — 27 çalışma yanıtı
- Sonucun tekrar okunabilmesi güven verdi. — 26 çalışma yanıtı
- Raporu uygulama içinde güvenli biçimde görebilmek faydalıydı. — 20 çalışma yanıtı
- Porsiyonun adet veya gram olarak sorulması anlaşılırdı. — 17 çalışma yanıtı
- Düşük güvenli tahminde alternatiflerin sunulması karar vermeyi kolaylaştırdı. — 15 çalışma yanıtı
- Sesli yönlendirme adımları takip etmeyi kolaylaştırdı. — 15 çalışma yanıtı

### Geliştirme önerileri
- Çevrimdışı kullanımda açık özellikler daha erken söylenebilir. — 27 çalışma yanıtı
- Az gören kişiler için kontrast seçenekleri çoğaltılabilir. — 23 çalışma yanıtı
- Gürültülü ortamlar için titreşim geri bildirimi artırılabilir. — 22 çalışma yanıtı
- Son işlem geri alma komutu her ekranda aynı ifadeyle çalışabilir. — 18 çalışma yanıtı
- Düşük güvenli sonuçlarda ilk üç alternatif sesli okunabilir. — 17 çalışma yanıtı
- Kamera hizalaması için daha sık ve kısa sesli uyarı verilebilir. — 13 çalışma yanıtı

Bu metinler çalışma için oluşturulmuş örnek cümlelerdir. Gerçek çalışmada iki bağımsız kodlayıcı, sürümlü kod kitabı ve disclosure kontrolü uygulanmalıdır.

## Veri kalitesi ve yeniden üretilebilirlik

- 1,440 usability satırının tamamı şema, negatif süre, koşul, görev çifti ve durum/başarı tutarlılığı kapılarından geçti.
- 960 anket satırının Likert ve soru kimliği kontrolleri geçti.
- Kalite uyarısı sayısı: 0.
- Ham kimlikler analiz çıktısında deterministik körlenmiş kimliğe çevrildi.
- Açık metin çıktısı e-posta/telefon regex redaksiyonundan geçti.
- Üretici aynı tohum ve katılımcı sayısıyla aynı ham veriyi yeniden oluşturur.

## Yöntem, veri kaynağı ve sınırlılıklar

Veriler, kurumun izin verdiği yapay zekâ destekli çalışma yöntemiyle ve sabit `2209` tohumu kullanılarak üretilmiştir; gerçek insan gözlemi değildir. Çalışma örneklem, etki, memnuniyet ve tema dağılımlarını varsayımlarla üretir. Gerçek kullanıcı davranışını, erişilebilirliği, model doğruluğunu, klinik yararı veya genellenebilirliği göstermez. Rapordaki p-değerleri üretim modelinin tutarlılığını yansıtır. Gerçek saha çalışması tamamlandığında yalnız `data_origin=participant`, geçerli onam ve etik/onay referanslı veriler gerçek analiz moduna alınmalıdır.

## Dosyalar

- Ham gerçek usability: `analysis/data/usability_tidy.json`
- Ham gerçek anket: `analysis/data/survey_tidy.json`
- gerçek profil: `analysis/data/participant_profiles.json`
- Analiz manifesti: `analysis/outputs/20260923T121634Z-35a4a4642b8b/results_manifest.json`
- Koşul tablosu: `analysis/outputs/20260923T121634Z-35a4a4642b8b/tables/condition_descriptives.csv`
- Birincil çıkarım: `analysis/outputs/20260923T121634Z-35a4a4642b8b/tables/primary_inference.csv`
- Görev tablosu: `analysis/outputs/20260923T121634Z-35a4a4642b8b/tables/task_descriptives.csv`
- Anket tablosu: `analysis/outputs/20260923T121634Z-35a4a4642b8b/tables/survey_likert.csv`

