# Kamera ile güvenli besin tarama hattı

**Durum:** Kod ve otomatik testler tamamlandı; gerçek fiziksel cihaz E2E ve latency kanıtı henüz çalıştırılmadı.

## Ürün stratejisi

Birincil yol, kimliği doğrulanmış kullanıcının görüntüyü kanonik FastAPI endpointine multipart olarak göndermesidir. Backend yalnız yapılandırılmış Google Vision sağlayıcısını veya ileride açıkça seçilecek sunucu modelini kullanır. Credential yoksa servis 503 döner; sahte başarı veya demo besin üretilmez.

Çevrimdışı/mahremiyet yolu yalnız checksum'ı, etiketleri, preprocessing sözleşmesi ve cihaz eşdeğerlik testi doğrulanmış TFLite modeli bulunduğunda açılacaktır. Depoda böyle bir model olmadığı için mevcut `UnavailableOfflineFoodRecognizer` güvenli biçimde başarısız olur ve manuel giriş sunar. Cloud confidence ile ilerideki TFLite confidence ortak kalibre edilmeden karşılaştırılmaz; `recognition_source` her zaman gösterilir.

## Kamera state machine

```text
permissionRequesting → initializing → ready → capturing → preprocessing
    → uploading → resultReady/confirmationRequired
    → confirmed/corrected/rejected → saved

Her aktif aşama → qualityWarning | offlineInference | error
```

- Tek uçuş kilidi ve tek periyodik zamanlayıcı aynı anda birden fazla çekim/request oluşmasını engeller.
- Ekrandan çıkışta timer, kamera, TTS/STT, aktif Dio `CancelToken` ve geçici çekim dosyası kapatılır/silinir.
- EXIF yönü piksele uygulanır; görüntü merkezden kare kırpılır, 224×224 RGB JPEG olarak yeniden kodlanır.
- Kalite kontrolü yalnız çekim için ön koşuldur; kalite geçince “yiyecek tespit edildi” denmez.
- Kalite/TTS uyarıları cooldown ile sınırlandırılır; karanlık, uzak ve bulanık durumlar ayrı kısa mesaj üretir.

## Güven ve kullanıcı kararı

| Durum | UI/TTS davranışı | Kayıt |
|---|---|---|
| Yüksek güven | Adı ve kaloriyi okur; düzeltme ve onay sunar | Yalnız onaydan sonra |
| Orta güven | En fazla üç adayı sunar; evet/hayır/bir-iki-üç komutlarını kabul eder | Seçim/onaydan sonra |
| Düşük güven/OOD | Kesin ad veya kalori söylemez; yeniden çekim/manuel giriş sunar | Engellenir |
| Nutrition bulunamadı veya 0 kalori | Model tanımış olsa bile beslenme sonucunu başarılı saymaz | Engellenir |

`confidence` tanıma modeline aittir. `nutrition_status` ve `nutrition_source` beslenme verisinin ayrı köken/güven göstergesidir. Yerel veritabanı sonucu `unverified` olarak duyurulur.

## Kalite yapılandırması

Aşağıdaki `--dart-define` değerleri cihaz örnekleriyle kalibre edilebilen başlangıç değerleridir; bilimsel eşik olarak raporlanamaz:

```text
QUALITY_MIN_BRIGHTNESS
QUALITY_MAX_BRIGHTNESS
QUALITY_MIN_BLUR_SCORE
QUALITY_MIN_SHORT_EDGE
```

Kalibrasyon kanıtı en az üç orta sınıf Android cihaz, farklı ışık/mesafe ve desteklenen sınıflardan örnekler içermelidir. False reject/accept dağılımları sürümlü bir rapora yazılmadan varsayılanlar “doğrulanmış” sayılmaz.

## Backend korumaları

- Zorunlu bearer auth ve kullanıcı başına/IP başına dakika limiti.
- Maksimum encoded byte ve decoded pixel sınırı.
- İzin verilen MIME ile magic/decode formatı birebir eşleştirme.
- Pillow decompression-bomb ve decode hata reddi; EXIF transpose ve temiz JPEG yeniden kodlama.
- Sağlayıcı timeout'u; Base64/görüntü içeriğini loglamama.
- İşlenen görüntüyü varsayılan olarak saklamama.
- Kısa ömürlü analiz kimliği, sahiplik kontrolü ve idempotent `capture_id`/karar.

Mevcut rate limiter tek process belleğindedir. Çok instance production için Redis/gateway tabanlı paylaşılan limit zorunlu release kapısıdır.

## TFLite açma kapısı

Offline recognizer ancak şu artefaktların tümü varsa uygulanıp etkinleştirilebilir:

- gerçek `.tflite`, SHA-256 checksum ve sürümlü `labels.txt`;
- input shape, RGB sırası, resize/crop, normalization, dtype;
- quantized model ise input/output scale ve zero-point;
- Keras–TFLite tolerans eşdeğerlik testi ve fixture tahminleri;
- isolate/interpreter dispose testi;
- hedef Android cihazda cold/warm P50/P95 latency, bellek ve model boyutu;
- düşük güven/OOD eşiği için kalibrasyon verisi.

Bu artefaktlar yokken offline kodunun yiyecek sonucu döndürmesi yasaktır.

## Otomatik doğrulama

```powershell
cd C:\Users\TAHA\Desktop\2209\nutrisense\backend
.\venv\Scripts\python.exe -m pytest -q
.\venv\Scripts\python.exe scripts\export_openapi.py --check

cd C:\Users\TAHA\Desktop\2209\nutrisense
flutter test
flutter analyze
flutter build apk --debug
```

Backend testleri yetkisiz/bozuk/büyük/MIME uyumsuz görüntü, timeout, düşük güven, onay öncesi kayıt yokluğu ve idempotent onayı kapsar. Flutter testleri state/policy, karanlık-kaliteli fixture ve offline fail-closed davranışını kapsar.

## Fiziksel cihaz kanıt şablonu

Bu bölüm gerçek cihaz çalıştırılmadan doldurulamaz ve kabul ölçütü tamamlandı denemez:

| Kanıt | Sonuç |
|---|---|
| Cihaz marka/model, Android sürümü | **NOT RUN** |
| Uygulamayı aç → giriş → tara → dinle → onayla/düzelt → geçmiş | **NOT RUN** |
| Online cold/warm P50/P95 latency, en az 30 koşu | **NOT RUN** |
| Offline TFLite cold/warm latency | **NOT RUN — doğrulanmış model yok** |
| İzin ret/kalıcı ret manuel kontrolü | **NOT RUN** |
| Ağ kesintisi ve manuel giriş | **NOT RUN** |
| Kişisel veri içermeyen ekran kaydı/log yolu | **NOT RUN** |

Kanıt paketinde gerçek sağlık verisi, yüz, konum, token, görüntü byte'ı veya sağlayıcı secret'ı bulunmamalıdır.
