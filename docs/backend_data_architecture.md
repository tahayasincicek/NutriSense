# Backend veri mimarisi

## Güven sınırı ve kimlikler

NutriSense beslenme geçmişi, tanıma çıktıları ve diyetisyen raporlarını hassas ürün verisi olarak ele alır. Ürün verisinin sahibi `users.id` ile belirlenir ve bütün ürün sorguları access token kullanıcısıyla sınırlandırılır. Araştırma verisi hesap UUID'si taşımaz; istemci tarafından üretilen rastgele `participant_pseudonym` kullanır. Bu pseudonym bir kimlik doğrulama anahtarı değildir ve hesap tablosuna bağlanmaz.

Veritabanında bütün timestamp alanları UTC yazılır. `UTCDateTime` tipi offset'i UTC'ye dönüştürür ve veritabanından timezone-aware değer döndürür. Flutter gösterim katmanı UTC ISO-8601 değerini `Europe/Istanbul` yerel saatine dönüştürür; sunucu yerel saatle kayıt üretmez.

## Tablo sahipliği ve yaşam döngüsü

Aşağıdaki süreler teknik varsayılan politika önerisidir. Kurumun KVKK, etik kurul ve araştırma saklama kararı onaylanmadan production retention job'u etkinleştirilmemelidir.

| Tablo | Sahip / erişim | Önerilen retention | Silme veya anonimleştirme |
|---|---|---|---|
| `users` | Hesap sahibi; sınırlı yönetici | Hesap aktifken | Doğrulanmış hesap silmede fiziksel silme |
| `dietitians` | Kurumsal yönetici; atanmış kullanıcı yalnız gerekli alanları görür | Mesleki doğrulama sürdükçe | Pasifleştirme; yasal gereklilik bitince silme |
| `dietitian_assignments` | İlgili kullanıcı ve yetkili diyetisyen | İlişki + 1 yıl önerisi | Hesap silmede cascade; iptalde durum/zaman korunur |
| `consent_records` | Kullanıcı ve denetim yetkilisi | Rıza ispat süresi; kurumca belirlenir | Hesap silmede cascade; ayrı yasal saklama gerekiyorsa pseudonymize arşiv tasarlanmalı |
| `recognition_attempts` | Hesap sahibi | Besin geçmişiyle aynı | Hesap silmede cascade; ham görüntü saklanmaz |
| `nutrition_sources` | Ürün provenance verisi, doğrudan kişi sahibi yok | Kaynak doğrulanabilirliği için sürüm ömrü | Food log silinse de kişisel alan içermeyen kaynak kaydı tutulabilir |
| `food_logs` | Hesap sahibi | Hesap aktifken veya kullanıcı silene kadar | Hesap silmede cascade |
| `dietitian_reports` | Hesap sahibi; onaylı atanmış diyetisyen | Kurumsal sağlık verisi politikası | Hesap silmede cascade; dış sağlayıcı kopyası ayrıca sağlayıcı politikasıyla silinir |
| `notification_deliveries` | Rapor sahibi ve operasyon yetkilisi | Teslimat/audit ihtiyacı, öneri 1 yıl | Raporla cascade; provider message ID kişisel veri içermemeli |
| `survey_versions` | Araştırma yöneticisi | Araştırma paketiyle kalıcı sürüm kaydı | Kullanılmış sürüm silinmez; pasifleştirilir |
| `survey_submissions` | Pseudonymous katılımcı; araştırma rolü | Etik kurulun belirlediği süre, örneğin proje + 5 yıl | Pseudonym üzerinden geri çekme/silme; hesap silmeyle otomatik ilişkilendirilmez |
| `usability_sessions` / `usability_tasks` | Pseudonymous katılımcı; araştırma rolü | Etik kurul kararı | Pseudonym üzerinden silme veya serbest metinleri anonimleştirme |
| `refresh_tokens` | Hesap sahibi | Expiry + kısa güvenlik penceresi | Logout/rotation revoke; hesap silmede cascade |
| `audit_events` | Güvenlik/denetim rolü | Öneri 1 yıl; mevzuata göre ayarlanır | Hesap silmede `user_id` kaldırılır; e-posta yerine geri döndürülemez hash kalır |

Serbest metin yanıtları ve araştırmacı notları 1000 karakterle sınırlıdır. API şeması doğrudan ad, e-posta ve telefon yazılmaması uyarısını taşır. Bu kontrol otomatik DLP değildir; production export öncesi yetkili inceleme gerekir.

## Transaction sınırları

Besin analizi dış sağlayıcı sonuçları tamamlanmadan veritabanına yazılmaz. Başarılı tanıma için `recognition_attempts`, `nutrition_sources` ve `food_logs` aynı commit içinde oluşturulur. Flush/commit hatasında üç kayıt da rollback olur. Görüntünün kendisi veritabanına veya diske yazılmaz; yalnız temizlenmiş görüntü çağrı sırasında bellekte kullanılır.

Diyetisyen raporunda istemcinin `Idempotency-Key` başlığı, kullanıcıyla birlikte unique anahtardır. Başlık yoksa tarih aralığı ve istek gövdesinden deterministik anahtar türetilir. Sağlayıcı çağrısından önce `pending` rapor ve rıza kaydı commit edilir. Aynı anahtarlı retry mevcut sonucu döndürür ve ikinci e-posta/SMS üretmez. Kanal sonuçları `notification_deliveries` tablosuna yazılır. Sağlayıcı başarılı olup sonuç commit'i başarısız olursa kayıt `pending` kalır ve otomatik tekrar gönderim yapılmaz; operasyonel reconciliation gerekir.

## Araştırma export güvenliği

Survey/usability endpointleri dosya yazmaz. Export ve istatistik endpointleri `X-Research-Export-Token` ister; başarısız istekler 403 döner. Başarılı export `audit_events` kaydı üretir. Token yalnız sunucu secret manager'ında tutulmalı, mobil uygulamaya verilmemelidir.

## Veritabanı ve migration

`DATABASE_URL` tek kanonik bağlantı ayarıdır. `DB_*` alanları yalnız eski geliştirme uyumluluğu ve Compose değişken genişletmesi içindir. Production şu durumlarda başlamaz:

- `DEBUG=true`;
- SQLite;
- açıkça verilmemiş `DATABASE_URL`;
- boş/placeholder DB parolası;
- kısa, boş veya placeholder uygulama/JWT/araştırma secret'ı.

Test ortamı yalnız SQLite'a veya adı `_test` ile biten bir veritabanına bağlanabilir. Pytest bu korumayı her testten önce doğrular. Production `create_all` kullanmaz; container entrypoint önce `alembic upgrade head` çalıştırır. `/health/live` yalnız process liveness, `/health/ready` ise DB bağlantısı ve Alembic head eşleşmesini bildirir.

## Backup ve restore prosedürü

1. Backup öncesi migration revision, UTC zamanı ve uygulama sürümünü kaydedin.
2. MySQL backup'ını şifreli, erişimi sınırlı ve production'dan ayrı bir depoya alın. Backup çıktısını Git'e koymayın.
3. Periyodik restore tatbikatını izole, adı `_test` ile biten veritabanında yapın.
4. Restore sonrasında `alembic current`, FK bütünlük sorguları, satır sayısı/checksum ve uygulama readiness kontrolünü çalıştırın.
5. Hesap silme taleplerinin backup'lara yansıması için kurumca onaylanmış backup expiry ve yeniden-silme prosedürü uygulayın.
6. Restore ortamında e-posta/SMS ve dış AI sağlayıcılarını kapalı tutun.

## Yeniden üretilebilir yerel ortam

```powershell
cd C:\Users\TAHA\Desktop\2209\nutrisense\backend
Copy-Item .env.example .env
# .env içindeki REPLACE alanlarını yerel secret store değerleriyle doldurun.
docker compose up --build
```

Mailpit arayüzü `http://127.0.0.1:8025`, API readiness adresi `http://127.0.0.1:8000/health/ready` olur. Sentetik diyetisyen kaydı yalnız dev/test ortamında oluşturulabilir:

```powershell
.\venv\Scripts\python.exe scripts\seed_synthetic.py
```

Testcontainer benzeri izole MySQL çalışması:

```powershell
docker compose --profile test run --rm test
```

Gerçek kullanıcı, sağlık veya saha araştırma verisi seed edilmez.
