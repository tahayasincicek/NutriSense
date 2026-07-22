# Alembic migration kılavuzu

`migrations/versions/18797ee84f1b_initial_product_and_research_schema.py` kanonik başlangıç şemasıdır. Kök dizindeki eski `001_refresh_tokens.sql` ve `002_auth_dietitian_lifecycle.sql` dosyaları tarihsel referanstır; yeni bir temiz veritabanına ayrıca uygulanmaz.

## Günlük kullanım

```powershell
cd C:\Users\TAHA\Desktop\2209\nutrisense\backend
.\venv\Scripts\alembic.exe current
.\venv\Scripts\alembic.exe upgrade head
.\venv\Scripts\alembic.exe check
```

Model değişikliğinden sonra:

```powershell
.\venv\Scripts\alembic.exe revision --autogenerate -m "kisa_aciklama"
```

Üretilen revision elle incelenmeden uygulanmamalıdır. Özellikle kolon silme/yeniden adlandırma, enum değişikliği, veri backfill'i, index süresi ve MySQL online DDL davranışı kontrol edilmelidir.

## Downgrade stratejisi

SQLite/test için başlangıç revision'ı `alembic downgrade base` ve yeniden `upgrade head` ile test edilir. Production'da downgrade varsayılan kurtarma yöntemi değildir:

1. Önce şifreli backup ve restore kanıtı alın.
2. Migration yalnız additive ise düzeltici forward migration tercih edin.
3. Veri kaybettiren downgrade için bakım penceresi ve yazma durdurma uygulayın.
4. Downgrade sonrası revision, FK bütünlüğü ve readiness kontrolünü doğrulayın.

## Legacy JSON araştırma verisi

Uygulama artık `data/survey_responses.json` veya `data/usability_sessions.json` yazmaz. Böyle bir legacy dosya bulunursa otomatik seed/import yapılmaz. Etik/yasal yetki, pseudonym formatı, şema sürümü ve checksum doğrulanarak ayrı ve denetlenmiş tek-seferlik migration hazırlanmalıdır. Dosyayı Git'e eklemeyin veya içeriğini loglamayın.

## Araştırma etik kapısı migration'ı

`f7a8b9c0d1e2_research_ethics_gate.py`; onamı sonuçlardan ayırır, geri çekilme kodu özetini, protokol/onay kaynağını, idempotency alanlarını ve görev audit alanlarını ekler. Upgrade öncesi backup/restore kanıtı alın. Migration sonrası `RESEARCH_MODE=synthetic` yalnız fixture kabul eder; gerçek katılımcı için kuruldan gelen protokol, onam ve approval reference değerleri server ortamında tanımlanmalıdır. Örnek değerle kapı açılmaz.
