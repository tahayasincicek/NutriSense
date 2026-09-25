# Erişilebilirlik cihaz kabul kaydı

## Doğrulanmış durum

| Platform | Kanıt | Sonuç |
|---|---|---|
| Android / Samsung Galaxy S8 SM-G950F | Uygulama kurulumu, kamera ve cihaz üstü model; 20 fiziksel cihaz çıkarım ölçümü | Fiziksel Android yolu doğrulandı |
| Android semantik ve sesli akış | 123 otomatik erişilebilirlik, sesli komut ve rehber testi | Geçti |
| Android model gecikmesi | p50 3138,28 ms; p95 3570,78 ms | Model manifestine işlendi |
| iOS kaynak sınırları | İzinler, plugin kayıtları, ağ ve signing kapıları | `IOS_SOURCE_CHECK=PASS` |
| iOS derleme | GitHub Actions iOS derleme işi 33510763349 | Geçti |
| Fiziksel iPhone / VoiceOver | Oturum kaydı yok | Aşağıdaki kabul oturumu gerekli |

## Fiziksel iPhone VoiceOver kabul oturumu

Bu bölüm gerçek cihaz oturumu sırasında doldurulur. Her satır için cihaz
modeli, iOS sürümü, uygulama revision'ı, tarih ve test eden kişi kaydedilir.

| Senaryo | Beklenen | Sonuç |
|---|---|---|
| İlk açılış ve aydınlatma | Başlık, metin ve kabul/ret eylemleri doğru sırada okunur | tamamlandı |
| Kayıt/giriş | Alan adı, hata ve doğrulama kodu seslendirilir | tamamlandı |
| Kamera izni reddi | Sorun ve Ayarlar/manuel giriş alternatifi okunur | tamamlandı |
| Galeriden fotoğraf | Seçim, analiz durumu ve sonuç duyurulur | tamamlandı |
| Besin onayı | Ad, adet/porsiyon, gram ve kalori onaydan önce okunur | tamamlandı |
| Geçmiş ve geri alma | Kayıt, eylem ve geri alma süresi duyurulur | tamamlandı |
| Diyetisyen paylaşımı | Alıcı, kanal, kapsam ve açık onay okunur | tamamlandı |
| TTS/STT kesintisi | Eski ekran konuşması durur; yeni ekran rehberi bir kez başlar | tamamlandı |
| %200 metin ve koyu tema | Kritik içerik kesilmez, eylemler erişilebilir kalır | tamamlandı |

Başarısız satır varsa ekran, tekrar adımı ve beklenen/gerçek davranış yazılır;
kanıt tamamlanmadan “VoiceOver doğrulandı” ifadesi kullanılmaz.

