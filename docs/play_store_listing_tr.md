# NutriSense — Google Play mağaza metni taslağı

Durum: **YAYINA HAZIR DEĞİL / KURUM ONAYI BEKLİYOR**

Bu metin yalnız çalışan ürün kapsamını tarif eder. Gerçek gizlilik politikası
URL'si, veri sorumlusu, application ID, imzalı AAB ve fiziksel cihaz kabul
kanıtı tamamlanmadan Play Console'a kopyalanmamalıdır.

## Uygulama adı

NutriSense

## Kısa açıklama

Besin sonucunu dinleyin, porsiyonu doğrulayın ve günlüğünüzü takip edin.

## Tam açıklama

NutriSense, görme engelli ve az gören kullanıcıların bir yiyecek görüntüsünden
alınan tahmini besin bilgisini dinlemesine, sonucu doğrulamasına veya
düzeltmesine ve onaylanan kaydı beslenme günlüğünde izlemesine yardımcı olan
bir araştırma prototipidir.

Uygulama:

- Yapılandırılmış çevrimiçi analiz hizmetinden gelen aday sonucu ve güven
  durumunu gösterir; hizmet yoksa sahte sonuç üretmez.
- Porsiyonu kesin ölçüm olarak sunmaz; kullanıcıya tahmini değeri değiştirme
  olanağı verir.
- Yalnız kullanıcı tarafından onaylanan kaydı geçmişe ekler.
- Türkçe sesli geri bildirim, sesli komut ve Android TalkBack ile kullanılmayı
  hedefler. Fiziksel cihaz erişilebilirlik doğrulaması tamamlanmadığı için tam
  uyumluluk iddiasında bulunulmaz.
- Atanmış ve doğrulanmış diyetisyene rapor göndermeden önce alıcıyı, dönemi ve
  kanalları kullanıcıya gösterip açık onay ister.

NutriSense tıbbi teşhis, tedavi veya kişiselleştirilmiş diyet önerisi sunmaz.
Besin ve porsiyon değerleri tahminidir; kullanıcı doğrulaması gerekir.

## Gizlilik özeti

- Kamera görüntüsü analiz sırasında işlenir ve varsayılan olarak kalıcı
  saklanmaz.
- Erişim belirteçleri Android platformunun güvenli deposunda tutulur.
- Diyetisyen paylaşımı her gönderimde ayrı kullanıcı onayı gerektirir.
- Araştırma veri toplama modu, etik protokol bilgileri yapılandırılmadan gerçek
  katılımcı verisi kabul etmez.
- Konum izni istenmez.

## Kanıtlanmadan kullanılmayacak ifadeler

Şu ifadeler yayın metninde yasaktır: “TÜBİTAK destekli”, “WCAG uyumlu”,
“tamamen erişilebilir”, “tam AI”, “klinik doğruluk”, belirli bir besin/sınıf
sayısı, doğrulanmamış model veya sağlayıcı adı ve “KVKK uyum garantisi”.

## Play Console için açık kullanıcı kararları

| Alan | Durum |
|---|---|
| Uygulama/application ID | Kurum/ürün sahibi belirleyecek |
| İletişim e-postası | Yetkili kurum sağlayacak |
| Gizlilik politikası URL'si | Hukuk/KVKK onaylı gerçek URL gerekli |
| İçerik derecelendirmesi | Play Console anketiyle belirlenecek |
| Hedef kitle | Araştırmacı ve kurum kararı gerekli |
| Data Safety | `docs/play_store_data_safety_draft.md` üzerinden sonlandırılacak |
| Sağlık uygulaması beyanları | Play politikası ve hukuk incelemesi gerekli |

## Ekran görüntüsü kapısı

Ekran görüntüleri yalnız production-benzeri, sentetik test verisiyle
oluşturulmalıdır. Gerçek ad, e-posta, telefon, token, beslenme geçmişi veya
katılımcı verisi görünmemelidir. Görseller henüz tamamlanmamış erişilebilirlik,
offline model veya dış sağlayıcı desteği varmış gibi göstermemelidir.
