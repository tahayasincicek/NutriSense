# NutriSense kanonik API sözleşmesi

**Sürüm:** v1  
**Durum:** Uygulandı  
**Kaynak gerçek:** FastAPI tarafından üretilen OpenAPI; checked-in snapshot `contracts/openapi.json`

## 1. Sözleşme yönetimi

Backend route ve Pydantic modelleri yürütülebilir kaynak gerçektir. `contracts/openapi.json` bu kaynaktan deterministik üretilir. Mobil consumer testleri ve backend schema testleri aynı `contracts/fixtures` JSON örneklerini okur.

Drift kontrolü:

```powershell
cd backend
$env:DATABASE_URL='sqlite+pysqlite:///:memory:'
venv\Scripts\python.exe scripts\export_openapi.py --check
```

Şema bilinçli değiştirildiğinde:

```powershell
cd backend
venv\Scripts\python.exe scripts\export_openapi.py
```

OpenAPI snapshot değişikliği; backend testi, mobil fixture testi ve migration notuyla aynı değişiklikte yapılmalıdır.

## 2. Base URL ve genel kurallar

- Geliştirme Android emülatörü: `http://10.0.2.2:8000/api/v1`
- Test: `http://127.0.0.1:8000/api/v1`
- Production: CI tarafından verilen doğrulanmış HTTPS `API_BASE_URL`
- JSON alanları: `snake_case`
- Kaynak kimlikleri: UUID metni
- Tarih: `YYYY-MM-DD`; timestamp: ISO-8601
- Confidence: kapalı aralık `0..1`
- Varsayılan JSON response content type: `application/json`
- Her istek `X-Request-ID` taşır. Backend mevcut değeri korur veya UUID üretir ve response header/hata gövdesinde döndürür.
- Secret ve harici servis anahtarları mobil binary içine konmaz.

## 3. Gerçek kullanım grafiği

### Önceki durum

| Ekran/özellik | Önceki istemci | Önceki sözleşme | Sorun |
|---|---|---|---|
| Kamera | `ApiService` | JSON `/food/recognize`, `image`, `timestamp`, `calories` | Backend'de endpoint ve alanlar yoktu. |
| Geçmiş | `FoodAnalysisService` | `/food-history/{user_id}` | Ayrı token belleği ve ayrı Dio vardı. |
| Diyetisyen | `FoodAnalysisService` | `/send-to-dietitian` | Ağ katmanı doğrudan TTS başlatıyordu. |
| Survey | `SurveyService` içindeki üçüncü Dio | `/survey` | Auth, request-id ve hata modeli yoktu. |
| Usability | Sadece yerel kayıt | API çağrısı yoktu | Backend `/usability` kullanılmıyordu. |
| Login | UI gecikme simülasyonu | Gerçek çağrı yoktu | Tokenlar UI akışına bağlanmıyordu. |

### Kanonik durum

| Ekran/özellik | Provider | Tek istemci metodu | Backend |
|---|---|---|---|
| `CameraScreen` | `apiServiceProvider` | `analyzeFood()` → `decideFoodAnalysis()` | `POST /api/v1/analyze-food` → `POST /api/v1/food-analysis/{analysis_id}/decision` |
| `FoodHistoryScreen` | `historyControllerProvider` → `HistoryRepository` → `apiServiceProvider` | `getFoodHistory()`, `updateFoodLog()`, `deleteFoodLog()`, `restoreFoodLog()` | Geçmiş ve kullanıcıya ait kayıt yaşam döngüsü |
| `SendReportWizard` | `apiServiceProvider` | `sendToDietitian()` | `POST /api/v1/send-to-dietitian` |
| `LoginScreen` | `apiServiceProvider` | `login()` | `POST /api/v1/auth/login` |
| Survey | `SurveyService` → `ApiService` | `submitSurvey()` | `POST /api/v1/survey` |
| Usability | `SurveyService` → `ApiService` | `submitUsability()` | `POST /api/v1/usability` |

`FoodAnalysisService` kaldırılmıştır. Production kodunda Dio oluşturan tek sınıf `ApiService`tir; refresh dahil aynı Dio instance'ı kullanılır.

## 4. Endpoint özeti

| Method | Path | Auth | Request | Response |
|---|---|---|---|---|
| POST | `/auth/register` | Hayır | JSON `UserCreate` | `TokenResponse` |
| POST | `/auth/login` | Hayır | JSON `UserLogin` | `TokenResponse` |
| POST | `/auth/refresh` | Hayır; refresh token gövdede | JSON `RefreshTokenRequest` | Rotated `TokenResponse` |
| POST | `/auth/logout` | Hayır; refresh token gövdede | JSON `LogoutRequest` | 204 |
| GET | `/users/me` | Bearer access | Yok | `UserResponse` |
| DELETE | `/users/me` | Bearer access | Parola + `HESABIMI SIL` | 204 |
| GET/POST | `/dietitians/assignment` | Bearer access | Doğrulanmış diyetisyen e-postası | `DietitianAssignmentResponse` |
| POST | `/dietitians/assignment/{id}/approve` | Bearer access | Yok | `DietitianAssignmentResponse` |
| DELETE | `/dietitians/assignment/{id}` | Bearer access | Yok | 204 |
| POST | `/analyze-food` | Bearer access | Multipart `image`, `meal_type`, `capture_id` | Onay bekleyen `FoodAnalysisResponse`; `log_id=null` |
| POST | `/food-analysis/{analysis_id}/decision` | Bearer access | JSON `decision`, opsiyonel `corrected_food_name` | `FoodAnalysisDecisionResponse` |
| POST | `/food-log/manual` | Bearer access | JSON `food_name`, `meal_type`, `capture_id` | Onaylı `FoodAnalysisDecisionResponse` |
| GET | `/food-history/{user_id}` | Bearer access | `from_date`, `to_date`, `page`, `page_size` | `FoodHistoryResponse` |
| PATCH | `/food-logs/{log_id}` | Bearer access | Besin etiketi, gram ve/veya öğün türü | Güncellenmiş `FoodLogEntry` |
| DELETE | `/food-logs/{log_id}` | Bearer access | Yok | Soft-delete sonucu |
| POST | `/food-logs/{log_id}/restore` | Bearer access | Yok | Geri alma sonucu |
| POST | `/send-to-dietitian` | Bearer access | JSON `SendToDietitianRequest`; `consent=true`; önerilen `Idempotency-Key` başlığı | `SendToDietitianResponse` |
| POST | `/survey` | Araştırma katılımcı kimliği gövdede | JSON `SurveySubmissionSchema` | `SurveyResponseSchema` |
| POST | `/usability` | Araştırma katılımcı kimliği gövdede | JSON `UsabilitySessionSchema` | `UsabilityResponseSchema` |

Survey/usability gönderimlerinde hesap `user_id` değeri kullanılmaz; yalnız ayrı UUID/pseudonym `participant_id` kabul edilir. Kayıtlar JSON dosyasına değil sürümlü veritabanı tablolarına transaction ile yazılır. İstatistik ve ham veri export yolları `X-Research-Export-Token` ile korunur ve başarılı export audit olayı üretir. Production saha dağıtımından önce etik onam, rate limit ve araştırmacı rol/yetki politikası ayrıca tamamlanmalıdır.

## 5. Besin analizi

### Request

`multipart/form-data` ana ve tek yöntemdir. Base64 JSON endpointi yoktur.

- `image`: zorunlu dosya
  - MIME: `image/jpeg`, `image/png`, `image/webp`
  - Maksimum: 5 MB
  - Backend gerçek görüntü decode kontrolü yapar.
  - Görüntü RGB JPEG olarak yeniden kodlanır; EXIF/metadatası aktarılmaz.
  - En büyük kenar 2048 piksele indirilir.
- `meal_type`: `kahvalti | ogle | aksam | atistirmalik`
- `capture_id`: zorunlu UUID; aynı fiziksel çekimin tekrar gönderilmesini idempotent yapar.
- `user_id` gövdede gönderilmez; access token'dan alınır.

Mobil ön işleme 224×224 JPEG byte üretir ve bu byte'ları multipart dosya olarak yollar. Cancellation, Dio `CancelToken` ile çağrıdan taşıma katmanına kadar iletilir.

### Başarılı response

```json
{
  "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
  "log_id": null,
  "food_name": "elma",
  "food_name_tr": "Elma",
  "confidence": 0.93,
  "portion_grams": 150.0,
  "calories_per_100g": 52.0,
  "total_calories": 78.0,
  "nutrients": {
    "protein": 0.4,
    "carbs": 20.7,
    "fat": 0.3,
    "fiber": 3.6
  },
  "meal_type": "atistirmalik",
  "recognition_source": "google_vision",
  "nutrition_source": "nutritionix",
  "nutrition_status": "available",
  "candidates": [
    {"food_name": "elma", "food_name_tr": "Elma", "confidence": 0.93}
  ],
  "can_confirm": true,
  "needs_confirmation": true,
  "tts_text": "Elma tanındı. 150 gram, 78 kalori. Kaydetmek için onaylayın."
}
```

Analiz başarılı olsa bile bu aşamada `food_logs` kaydı oluşmaz. `log_id` zorunlu olarak `null`, `needs_confirmation=true` olur. Kullanıcı onayı `decision=confirm`, düzeltme `decision=correct` ve `corrected_food_name`, ret `decision=reject` ile ayrı karar endpointine gönderilir. Yalnız confirm/correct başarılı olursa response gerçek `log_id` içerir. Aynı `analysis_id` için yinelenen onay aynı kaydı döndürür; ikinci kayıt oluşturmaz.

Mobil parser bilinmeyen alanları görmezden gelir. `analysis_id`, besin adları gibi zorunlu alanların null/boş olması veya confidence'ın `0..1` dışında olması `CONTRACT_MISMATCH` üretir; sahte varsayılanla başarı göstermez. `nutrition_status=not_found`, sıfır kalori veya `can_confirm=false` kayıt oluşturamaz. `nutrition_status=unverified`, yerel ve doğrulanmamış besin tabanı kullanıldığını UI'da ayrı açıklar. Model confidence ile beslenme verisi güvenilirliği aynı ölçü değildir.

`tts_text` bir response verisidir; ağ katmanı bunu seslendirmez. Seslendirme ve haptic kararı kamera/UI katmanındadır.

## 6. Standart hata şeması

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Görüntü dosyası bozuk veya desteklenmeyen biçimde.",
    "request_id": "8aef4e30-d772-487e-bc2b-c93662f08624",
    "details": null
  }
}
```

Temel kodlar:

- `UNAUTHORIZED`, `FORBIDDEN`
- `VALIDATION_ERROR`, `IMAGE_TOO_LARGE`, `UNSUPPORTED_IMAGE_TYPE`
- `NOT_FOUND`
- `PROVIDER_UNAVAILABLE`
- `CONFLICT`
- `INTERNAL_ERROR`
- İstemci kaynaklı: `TIMEOUT`, `CONNECTION_ERROR`, `REQUEST_CANCELLED`, `CONTRACT_MISMATCH`

Backend mesajı ağ modelidir; TTS değildir. UI aynı mesajı gösterebilir veya bağlama uygun erişilebilir metne çevirebilir.

## 7. Auth ve refresh politikası

- Access token türü: JWT `type=access`, varsayılan ömür 60 dakika.
- Refresh token türü: JWT `type=refresh`, varsayılan ömür 30 gün.
- Her refresh token benzersiz `jti` içerir.
- Veritabanında ham refresh token değil SHA-256 hash, `jti`, kullanıcı, expiry, revoke ve replacement ilişkisi saklanır.
- `/auth/refresh` başarılı olduğunda eski token aynı transaction akışında revoke edilir ve yeni access + refresh token döner.
- Eski refresh token'ın yeniden kullanımı 401 üretir.
- `/auth/logout` verilen refresh token'ı revoke eder.
- Çoklu 401 geldiğinde mobilde tek `Completer` tabanlı refresh uçuşu vardır; bekleyen çağrılar aynı sonucu paylaşır.
- Retry edilen request `auth_retried=true` işareti taşır. İkinci 401 tekrar refresh başlatmaz.
- Refresh başarısızsa bellek oturumu ve tek JSON oturum kaydı temizlenir.

Production için `backend/migrations/001_refresh_tokens.sql` kontrollü migration olarak uygulanmalıdır. `create_all` yalnızca geliştirme başlangıcı içindir. Çok cihazlı “tüm oturumları kapat”, token ailesi ihlali ve yönetici revocation ihtiyacı ayrı güvenlik işidir.

## 8. Retry, timeout ve cancellation

- Connect timeout: 15 saniye
- Send/receive timeout: 30 saniye
- Otomatik retry: yalnızca `GET`, `HEAD`, `OPTIONS`
- Retry sayısı: en fazla bir ek deneme
- Retry koşulu: bağlantı/timeout veya 5xx
- POST upload, auth, survey ve rapor gönderimi otomatik retry edilmez; çift kayıt riski yaratılmaz.
- Caller `CancelToken` sağlayabilir.
- Her deneme request-id taşır.

## 9. Migration planı

1. FastAPI `/api/v1` endpointleri ve OpenAPI kaynak gerçek seçildi.
2. `/food/recognize` mobil kullanımı kaldırıldı; `/analyze-food` kanonik kaldı.
3. Base64 JSON kaldırıldı; multipart request ve yeni response fixture aynı değişiklikte eklendi.
4. Kamera, geçmiş, diyetisyen, auth ve survey tek `ApiService`e geçirildi.
5. `FoodAnalysisService` silindi; adapter veya sessiz fallback bırakılmadı.
6. Backend refresh/logout ve rotation tablosu eklendi.
7. CI OpenAPI drift + backend producer + Flutter consumer contract testlerini çalıştırır.

Bu v1 değişikliği dağıtılmadan önce eski mobil sürüm kullanıcıları varsa backend/mobile rollout sırası ayrıca planlanmalıdır. Eski `/food/recognize` endpointi eklenmeyecek; destek gerekiyorsa zaman sınırlı, ölçümlü ve açıkça belgelenmiş ayrı bir compatibility router kararı gerekir.

## 10. Uçtan uca çağrı örneği

Önce login sonucu alınır; gerçek token terminal geçmişine yazılmamalıdır. Aşağıdaki değer yalnızca placeholder'dır:

```powershell
$accessToken = '<ACCESS_TOKEN_FROM_SECURE_SESSION>'
curl.exe -X POST 'http://127.0.0.1:8000/api/v1/analyze-food' `
  -H "Authorization: Bearer $accessToken" `
  -H 'X-Request-ID: 410d2c2f-926d-4fc8-9a3d-6af18ce8d893' `
  -F 'capture_id=6d2ab370-66e2-449d-b915-240ad8b7860a' `
  -F 'meal_type=ogle' `
  -F 'image=@C:\path\to\food.jpg;type=image/jpeg'
```

Flutter gerçek akışı:

```text
CameraScreen
  → ImagePreprocessor.processImage()
  → ApiService.analyzeFood(processedBytes, captureId)
  → multipart POST /api/v1/analyze-food
  → FoodAnalysisResult.fromJson()
  → recognition policy + UI/TtsService erişilebilir geri bildirimi
  → kullanıcı onayı/düzeltmesi
  → ApiService.decideFoodAnalysis(analysisId, decision)
  → yalnız gerçek log_id geldiyse CameraStatus.saved
```

## 11. Test komutları

```powershell
$flutter = 'C:\Users\TAHA\Desktop\2209\flutter_sdk\flutter\bin\flutter.bat'
& $flutter test test\contract --reporter expanded
& $flutter analyze --no-fatal-infos

cd backend
$env:DATABASE_URL='sqlite+pysqlite:///:memory:'
$env:JWT_SECRET_KEY='local-contract-test-only'
venv\Scripts\python.exe scripts\export_openapi.py --check
venv\Scripts\python.exe -m pytest tests -q
```

## 12. Dış servis gereksinimleri

Gerçek uçtan uca sağlayıcı testi için hâlâ şunlar gerekir:

- Google Cloud Vision gerçek proje/credential ve sandbox çağrı kanıtı
- Nutritionix app ID/API key veya doğrulanmış yerel besin veritabanı
- Diyetisyen atanmış test kullanıcısı
- SMTP sandbox ve/veya Twilio test credential'ları
- MySQL migration uygulanmış test/production veritabanı
- Kuruma ait HTTPS API hostu ve TLS doğrulaması

Bu değerlerin hiçbiri fixture, mobil binary, OpenAPI veya dokümana eklenmemiştir.

## 13. Son doğrulama sonucu

17 Temmuz 2026 yerel doğrulaması:

- Backend producer/endpoint/auth contract: **13 geçti, 0 başarısız**.
- Flutter consumer/auth queue contract: **9 geçti, 0 başarısız**.
- Contract + unit + gerçek uygulama smoke kapısı: **71 geçti, 0 başarısız**.
- Analyzer: **0 error, 0 warning, 56 mevcut info**.
- Android debug build: **başarılı**.
- Tüm Flutter paketi: **86 geçti, 2 önceden bilinen test-yerel sahte geçmiş widget testi başarısız**. Bu iki test API değişikliğinden kaynaklanmaz ve `skip` ile gizlenmemiştir.
