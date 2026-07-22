# Analysis data boundary

`real/` gerçek, yetkili backend tidy export'ları içindir ve Git'e eklenmez. `synthetic/` yalnız pipeline testi için deterministik fixture üretebilir. Hiçbir sentetik dosya bilimsel sonuç veya TÜBİTAK raporu girdisi değildir.

Sentetik fixture üretimi:

```powershell
python analysis/tools/generate_synthetic_fixture.py --output analysis/data/synthetic
```

Gerçek dosya adları:

- `analysis/data/real/usability_tidy.json`
- `analysis/data/real/survey_tidy.json`

Export secret'ı, katılımcı iletişim bilgisi, onam sesi veya ürün hesabı verisi bu dizine konmaz.
