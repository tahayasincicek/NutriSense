# NutriSense yaygınlaştırma paketi

Bu metin poster, proje sergisi, kısa bildiri özeti ve sözlü sunum için ortak,
kanıta bağlı içeriktir. Gerçek kullanıcı çalışması tamamlanmadan kullanıcı
başarısı veya memnuniyet yüzdesi eklenmez.

## Başlık

**Görme Engelli Bireyler İçin Sesli Yönlendirmeli Besin Tanıma ve Kalori
Takip Uygulaması: NutriSense**

## Kısa özet

NutriSense, görme engelli bireylerin besin kaydı oluşturmasını kolaylaştırmak
için cihaz üstü görüntü tanıma, kaynaklı besin değeri kataloğu ve Türkçe sesli
rehberi birleştiren Flutter tabanlı bir mobil uygulamadır. Dağıtılan model 137
besin sınıfını kapsar; düşük güvenli tahminler kesin sonuç olarak kaydedilmez
ve kullanıcı onayına yönlendirilir. Kalori değeri görüntü modelinden tahmin
edilmez, 556 kayıtlık izlenebilir katalogdan alınır. Android fiziksel cihaz
ölçümü Samsung Galaxy S8 üzerinde yapılmış; MySQL 8.4 backend koşusunda 286
test, erişilebilirlik/sesli akış paketinde 123 test geçmiştir. Gerçek görme
engelli katılımcılarla kullanılabilirlik çalışması için etik kapılı, anonim
veri toplama ve yeniden üretilebilir analiz altyapısı hazırlanmıştır; saha
bulguları katılımcı verisi toplanmadan raporlanmamaktadır.

## Poster bölümleri

1. **Problem:** Görsel ağırlıklı beslenme uygulamalarında bağımsız kayıt ve
   doğrulama güçlüğü.
2. **Çözüm:** Kamera/galeri, cihaz üstü model, sesli rehber, manuel düzeltme,
   erişilebilir porsiyon seçimi ve diyetisyen paneli.
3. **Güvenlik yaklaşımı:** Düşük güvenli tahmini reddetme, kullanıcı onayı,
   minimum veri, pseudonym araştırma kaydı ve secret'ların backend'de kalması.
4. **Teknik sonuçlar:** 137 sınıf; tek görünüm test doğruluğu %76,83;
   macro-F1 0,7627; S8 p50 3138,28 ms; 556 besin kaydı.
5. **Doğrulama:** MySQL 286/286 geçen test (1 koşullu atlama), erişilebilirlik
   123/123, statik analiz temiz, iOS kaynak kapısı geçti.
6. **Sınırlılık:** Gerçek görme engelli katılımcı çalışması ve fiziksel
   iPhone/VoiceOver kabulü henüz yoktur.

## Sekiz slaytlık sunum akışı

1. Problem ve hedef kullanıcı.
2. Kullanıcı yolculuğu: tara, dinle, düzelt, onayla, kaydet.
3. Mobil ve backend mimarisi.
4. Besin tanıma modeli ve güven eşiği.
5. Besin değeri kaynakları ve porsiyon hesabı.
6. Erişilebilirlik ve sesli komut sistemi.
7. Test sonuçları, gizlilik ve sınırlılıklar.
8. Saha çalışması planı ve gelecek çalışma.

## Üç dakikalık demo senaryosu

1. Uygulamayı açıp ana ekran sesli rehberini dinletin.
2. Galeriden veya kameradan tek bir besin seçin.
3. Sonucun, güven düzeyinin ve alternatiflerin seslendirilmesini gösterin.
4. Adet/porsiyon bilgisini sesli ya da dokunarak girin.
5. Besin adı, miktar, zaman ve kaloriyi onaylayıp kaydedin.
6. Günlükte son kaydı ve geri alma işlevini gösterin.
7. Diyetisyen panelinde yalnız onaylı raporun göründüğünü gösterin.

## Kullanılabilecek doğrulanmış ifadeler

- “Model 137 besin sınıfını kapsıyor.”
- “Besin değerleri 556 kayıtlık kaynaklı katalogdan okunuyor.”
- “Düşük güvenli tahmin kullanıcı onayı olmadan kaydedilmiyor.”
- “Backend temiz MySQL 8.4 üzerinde tam test koşusundan geçti.”
- “Android fiziksel cihaz gecikmesi Samsung Galaxy S8 üzerinde ölçüldü.”

## Kullanılmaması gereken ifadeler

- “Görme engelli kullanıcıların yüzde X'i başarılı oldu.”
- “Kullanılabilirlik çalışması tamamlandı.”
- “VoiceOver tamamen doğrulandı.”
- “Uygulama tıbbi olarak hatasızdır.”
- “KVKK uyumu veya mağaza kabulü garanti edildi.”

Bu iddialar ancak ilgili saha, fiziksel cihaz, hukuk veya mağaza kanıtı
tamamlandıktan sonra eklenebilir.

