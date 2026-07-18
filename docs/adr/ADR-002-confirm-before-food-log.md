# ADR-002: Besin analizini kullanıcı onayından önce kaydetmeme

- **Durum:** Kabul edildi
- **Tarih:** 2026-07-18
- **Karar sahipleri:** Mobil, backend ve araştırma bütünlüğü ekibi

## Bağlam

Önceki `/analyze-food` akışı tanıma ve beslenme sonucu döner dönmez `food_logs` kaydı oluşturuyordu. Görme engelli kullanıcı sonucu dinlemeden, düşük güveni değerlendirmeden veya yanlış besini düzeltmeden sağlık/beslenme geçmişi değişiyordu. İstemci zaman aşımında aynı çekimi yeniden yolladığında çift kayıt riski de bulunuyordu.

## Karar

1. Analiz çağrısı yalnız görüntüsüz ve kısa ömürlü bir `recognition_attempts` kaydı üretir.
2. Her fiziksel çekim istemci üretimli `capture_id` UUID ile idempotenttir.
3. Analiz yanıtında `log_id=null` ve `needs_confirmation=true` olur.
4. Yüksek güven dâhil hiçbir otomatik tanıma kullanıcı kararı olmadan geçmişe yazılmaz.
5. `confirm`, `correct` ve `reject` kararları ayrı, sahiplik kontrollü endpointte işlenir.
6. Düzeltmede beslenme bilgisi yeniden sorgulanır. Besin bulunamazsa veya toplam kalori sıfırsa kayıt engellenir.
7. Onay endpointi aynı analiz için tekrar çağrılırsa mevcut log kimliğini döndürür.
8. Görüntü, Base64 gövde ve EXIF verisi veritabanına veya loglara yazılmaz.

## Sonuçlar

Kullanıcı geçmişi yalnız açık kararla değişir; düşük güven/OOD cevapları kesin besin veya kalori olarak kaydedilemez. Buna karşılık mobil akış iki ağ adımı gerektirir ve bekleyen analizler için süre sonu yönetimi gerekir. Mevcut uygulama 30 dakikalık karar süresi kullanır.

## Kabul kapıları

- Analizden sonra `FoodLog` sayısı değişmemelidir.
- Onaydan sonra tam bir kayıt oluşmalı ve response gerçek `log_id` içermelidir.
- Ret, düşük güven, nutrition not-found ve sıfır kalori hiçbir kayıt oluşturmamalıdır.
- Başka kullanıcı aynı `analysis_id` ile karar verememelidir.
- Aynı `capture_id` ve aynı karar çift kayıt üretmemelidir.
