# NutriSense test stratejisi

Durum: uygulanıyor. Bu belge, otomatik test kanıtını gerçek cihaz ve insan
katılımcı kanıtından ayırır. Sentetik fixture başarısı saha çalışması, model
başarısı veya sağlayıcı teslimatı olarak raporlanamaz.

## Risk yaklaşımı

P0; kimlik doğrulama, sahiplik, tarama karar kapısı, sıfır kalorili bilinmeyen
sonucun kaydı, geçmiş, açık rapor onayı, çift gönderim, araştırma onamı ve hesap
silmedir. P1; çevrimdışı cache, erişilebilir alternatifler, timezone,
configuration ve migration güvenliğidir. P2; görsel regresyon ve performans
iyileştirmeleridir. P0/P1 değişiklikleri ilgili otomatik test geçmeden
birleştirilemez.

## Katmanlar

- Flutter unit: kalori/porsiyon, JSON, güven politikası, sesli intent ve state
  reducer. Saat kullanan kod `AppClock` ile sabitlenir.
- Flutter service/contract: tek `ApiService`, Dio adapter ve
  `contracts/fixtures` ile request/response drift kontrolü.
- Flutter widget: test içinde benzer kart üretmek yerine doğrudan production
  ekranı import edilir; Riverpod override ile yalnız bağımlılıklar sahtelenir.
- Erişilebilirlik: semantics, odak, %200 metin, hata live-region ve kritik
  eylemlerde ikinci onay. Golden çıktı işlevsel assertion yerine geçmez.
- Android integration: `integration_test/p0_fixture_journey_test.dart`, gerçek
  kamera/sağlayıcı yerine sentetik transport kullanarak oturum -> karar ->
  geçmiş -> rapor önizleme zincirini production widget ve servisleriyle sınar.
- Backend: izole SQLite test DB, migration, auth/IDOR, görüntü sınırları,
  transaction, CRUD, outbox, araştırma onam/çekilme/export ve startup safety.
- ML: manifest/checksum/split ve güven eşiği testleri her CI'da; gerçek
  Keras-TFLite parity ve latency yalnız doğrulanmış model artefaktı mevcutsa
  release kanıt kapısında çalışır. Model yokluğu başarıya çevrilmez.

## Test verisi ve izolasyon

`test/support/synthetic_factories.dart` ve `backend/tests/factories.py`
yalnız `.invalid` adresler, sabit UUID ve sabit saat üretir. Gerçek kişi,
araştırma ham verisi, token, görsel veya telefon fixture olarak kullanılmaz.
Dış servisler CI'da mock/sandbox'tır. Her test kendi DB transaction'ını ve
in-memory depolarını kullanır; sıra bağımlılığı yasaktır.

## Flaky politika

Bir test hata verdiğinde otomatik tekrar ile yeşile çevrilmez. Önce seed, clock,
network, animation ve paylaşılan state kaynağı teşhis edilir. Geçici karantina
yalnız issue sahibi, son tarih ve risk kaydıyla mümkündür; P0 test karantinaya
alınamaz. `skip`, `continue-on-error`, `|| echo` ve koşulsuz başarılı mesaj
kabul edilmez.

## CI kapıları

1. Dart format ve `flutter analyze` (error sıfır; mevcut info borcu raporlu).
2. Flutter unit, contract, widget, accessibility ve tüm suite.
3. Android API 35 emulator sentetik P0 integration testi.
4. Backend flake8, OpenAPI drift, migration upgrade/current, security smoke ve
   pytest.
5. ML safety gate testleri ve açık bilim analiz hattı.
6. secret, Python dependency ve container taraması.
7. dev debug APK; shell `pipefail` etkin ve artefakt yoksa upload başarısız.

## Tekrar üretim

PowerShell:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-fatal-infos
flutter test --coverage
flutter test integration_test/p0_fixture_journey_test.dart -d <android-device-id>

Push-Location backend
$env:DATABASE_URL='sqlite+pysqlite:///:memory:'
$env:JWT_SECRET_KEY='synthetic-local-key-at-least-32-characters'
$env:APP_ENVIRONMENT='test'
$env:DEBUG='false'
$env:MIGRATION_CHECK_ENABLED='false'
python scripts/export_openapi.py --check
python -m pytest -q
Pop-Location

$env:PYTHONPATH='ml/src'
python -m pytest ml/tests -q
```

Gerçek cihaz komutu cihazın bağlı olmasını gerektirir. Kamera, TalkBack,
Türkçe TTS/STT, latency, bellek ve background/kill kontrolleri otomasyonla
kanıtlanmış sayılmaz; cihaz raporuna sonuç girilmelidir.

## Coverage yorumu

LCOV artefaktı yayınlanır; tek bir toplam yüzde kalite garantisi değildir.
Öncelik `ApiService` auth refresh, kamera karar state'i, history ownership,
outbox idempotency ve araştırma onam branch'leridir. Bu modüllerde branch
coverage ve seçilmiş mutation testleri sonraki kalite eşiğidir.
