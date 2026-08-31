# NutriSense backup ve restore planı

## Mevcut kanıt ve sınır

Yerel staging-benzeri MySQL için logical dump'ın ayrı bir test veritabanına
restore edilmesi ve tablo sayısının karşılaştırılması otomatikleştirilmiştir.
Bu yalnız sentetik veriyle yapılan bütünlük smoke testidir.

**Production backup alınmamış, şifreli production restore testi yapılmamış ve
RPO/RTO kurum tarafından onaylanmamıştır.**

## Hedef politika — kurum kararı gerekir

Önerilen başlangıç hedefi:

- RPO: en fazla 24 saat; PITR seçilirse 15 dakika hedeflenebilir;
- RTO: kritik API için 4 saat;
- günlük otomatik backup, 35 gün retention;
- aylık snapshot, kurum kararıyla en fazla 12 ay;
- üç ayda bir izole restore tatbikatı.

Bu değerler veri sorumlusu, proje sahibi ve altyapı sağlayıcısı tarafından
onaylanmadan taahhüt değildir.

## Production gereksinimleri

1. MySQL uygulama container'ından ayrı, kalıcı ve private ağda olmalıdır.
2. Backup aktarımda TLS, saklamada sağlayıcı KMS/kurumsal anahtar ile
   şifrelenmelidir.
3. Backup operatörü, uygulama operatörü ve anahtar yöneticisi rolleri mümkün
   olduğunca ayrılmalıdır.
4. Backup erişimi MFA, least privilege ve değiştirilemez audit ile korunmalıdır.
5. Backup farklı failure domain/hesapta kopyalanmalı; public erişim kapalıdır.
6. Backup kimliği, DB revision, zaman, checksum, şifreleme anahtar sürümü ve
   restore test sonucu tutulmalıdır; secret değeri tutulmaz.
7. MySQL consistency için transaction-aware snapshot veya
   `--single-transaction` logical dump kullanılmalıdır.

## Backup akışı

1. Backup job için kısa ömürlü DB kimliği al.
2. Backup başlangıç zamanı ve Alembic revision kaydet.
3. Consistent backup üret; stdout/loglara satır verisi yazma.
4. Client/platform şifrelemesini uygula.
5. Checksum ve immutable retention kaydını doğrula.
6. Backup kataloğuna PII içermeyen kanıt metadata'sı yaz.
7. Başarı doğrulanmadan eski backup'ı silme.

## Restore tatbikatı

1. Incident'tan bağımsız, izole ve erişim kontrollü hedef oluştur.
2. Hedefin production endpoint/queue/provider erişimini kapat.
3. Backup checksum ve anahtar sürümünü doğrula.
4. Boş DB'ye restore et.
5. Alembic revision, tablo/FK/index sayıları ve sentetik sentinel kayıtları
   doğrula.
6. Backend'i provider'lar disabled iken bağla; readiness ve read-only smoke yap.
7. Ölçülen RPO/RTO'yu kaydet.
8. Hedef kopyayı güvenli biçimde imha et ve imha kanıtını kaydet.

Yerel sentetik test:

```powershell
Set-Location C:\Users\TAHA\Desktop\2209\nutrisense\backend
powershell -ExecutionPolicy Bypass -File .\scripts\staging_up.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\backup_restore_smoke.ps1
```

## Silme, geri çekilme ve backup

Aktif DB'de hesap silme veya araştırmadan çekilme isteği sahiplik ve audit
kontrolleriyle gecikmeden uygulanır. Backup'ın değiştirilemez doğası nedeniyle:

- silinen özne için non-reversible deletion tombstone/identifier hash'i ayrı,
  minimum bir listede tutulabilir; hukuk birimi yöntemi onaylamalıdır;
- backup normal retention sonunda imha edilir;
- disaster restore sonrası deletion ledger yeniden uygulanır;
- restore edilen kopya provider'a mesaj gönderemez ve kullanıcı trafiği almaz;
- yasal saklama yükümlülüğü varsa kapsam/süre veri sahibine açıklanır;
- araştırma pseudonym eşleme anahtarı sonuç verisinden ayrı tutulur ve geri
  çekilmede uygulanır.

Backup içinden tekil satır silme mümkün değilse bu durum gizlilik metninde açık
olmalı; retention gereksiz uzun seçilmemelidir.

## Gerçek production öncesi kabul kanıtları

- şifreli backup job başarı kaydı;
- farklı failure domain'e kopya;
- temiz ortama başarılı restore;
- ölçülmüş RPO/RTO;
- deletion ledger'ın restore sonrası uygulanması;
- erişim/audit incelemesi;
- iki yetkili tarafından imzalanmış tatbikat kaydı;
- başarısız restore için escalation ve son doğrulanmış backup kimliği.

