# ADR-001: Kanonik API sözleşmesi ve tek mobil istemci

- **Durum:** Kabul edildi
- **Tarih:** 2026-07-17
- **Karar sahipleri:** Mobil/backend entegrasyon ekibi

## Bağlam

Mobil uygulamada iki bağımsız API servisi ve survey içinde üçüncü Dio bulunuyordu. Kamera `/food/recognize` JSON gövdesi ve `calories` alanı beklerken FastAPI `/api/v1/analyze-food`, Base64 gövde ve `total_calories` döndürüyordu. İki servis tokenları ayrı bellekte tutuyor, ikisi de eşzamanlı 401 durumunda birden fazla refresh başlatabiliyor ve `FoodAnalysisService` ağ katmanından TTS çağırıyordu. Backend'de mobilin çağırdığı refresh endpointi yoktu.

## Karar

1. FastAPI Pydantic modellerinden üretilen OpenAPI yürütülebilir kaynak gerçek olacaktır.
2. Checked-in `contracts/openapi.json` CI drift kontrolü için tutulacaktır.
3. Mobilde yalnızca `ApiService` Dio oluşturacaktır. Kamera, geçmiş, diyetisyen, auth, survey ve usability bu instance'ı paylaşacaktır.
4. Mevcut backend yolu `/api/v1/analyze-food` korunacaktır. Eski `/food/recognize` kaldırılacak ve sessiz fallback yapılmayacaktır.
5. Görüntü requesti `multipart/form-data` olacaktır. Backend MIME/byte/decode doğrulaması ve EXIF temizliği uygulayacaktır.
6. Hatalar request-id içeren tek şemaya dönüştürülecek; TTS yalnız UI katmanında çalışacaktır.
7. Refresh tokenlar rotation/revocation kayıtlarıyla tek kullanımlık olacaktır. Mobil eşzamanlı 401'leri tek refresh uçuşunda birleştirecek, ikinci 401 döngüsünü engelleyecek ve başarısız refresh'te oturumu temizleyecektir.
8. Otomatik ağ retry yalnız idempotent metotlarda uygulanacaktır.
9. Backend producer ve Flutter consumer aynı fixture'ları doğrulayacaktır.

## Neden mevcut endpoint adları korundu?

REST isimlerini topluca değiştirmek teknik olarak mümkün olsa da çalışan backend router zaten `/analyze-food`, `/food-history/{user_id}` ve `/send-to-dietitian` yollarını sunuyordu. Yalnız isim estetiği için yeni endpoint ailesi oluşturmak migration riskini büyütecekti. Bu ADR, v1 içinde mevcut backend yollarını kanonikleştirir; ileride resource-oriented v2 tasarımı ayrı ADR gerektirir.

## Değerlendirilen alternatifler

### İki istemciyi korumak

Reddedildi. Token durumu, retry, hata modeli ve base URL zamanla tekrar ayrışır.

### OpenAPI yerine yalnız elle yazılmış Markdown

Reddedildi. Doküman derlenebilir endpoint şemasından sapabilir ve drift makinece yakalanamaz.

### Base64 JSON görüntü

Reddedildi. Base64 yaklaşık ek taşıma maliyeti oluşturur, büyük gövde limitlerini zorlaştırır ve dosya MIME doğrulamasını zayıflatır. Multipart dosya ana yöntem seçildi.

### Refresh için ayrı Dio instance'ı

Reddedildi. Ayrı servis olmasa bile ikinci transport instance'ı konfigürasyon driftine yol açabilir. Aynı Dio, `skip_auth` ve `auth_retried` request metadata'sıyla güvenli biçimde kullanılır.

### Tüm POST çağrılarını otomatik retry etmek

Reddedildi. Besin kaydı, rapor, survey ve auth çağrılarında çift kayıt/yan etki riski vardır.

## Sonuçlar

Olumlu:

- URL, auth, request-id, timeout ve hata davranışı tek yerde yönetilir.
- Kamera request/response alanları backend ile birebir fixture üzerinden test edilir.
- Eşzamanlı 401 tek refresh çağrısı üretir.
- OpenAPI drift CI'da build hatasıdır.
- Ağ katmanı erişilebilirlik sunumundan bağımsızdır.

Maliyet/risk:

- Eski mobil sürüm `/food/recognize` ile çalışmaz; rollout planı gerekir.
- `refresh_tokens` tablosu için production migration gerekir.
- Gerçek sağlayıcı E2E testi dış credential ve sandbox ortamına bağlıdır.
- Flutter model kodu halen elle yazılıdır; OpenAPI code generation seçilirse ayrı migration yapılmalıdır.

## Uyum ve kabul kapıları

- Production kodunda `Dio(` yalnız `ApiService` içinde bulunmalıdır.
- `/food/recognize` OpenAPI'de bulunmamalıdır.
- `python scripts/export_openapi.py --check` başarılı olmalıdır.
- Backend contract testleri ve `flutter test test/contract` geçmelidir.
- Refresh replay 401 üretmeli; iki eşzamanlı 401 yalnız bir refresh çağırmalıdır.
- Eski endpoint için fallback eklenmesi bu ADR'yi değiştiren yeni karar gerektirir.
