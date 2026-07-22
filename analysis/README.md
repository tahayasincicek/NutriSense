# NutriSense yeniden üretilebilir HCI analizi

## Mevcut durum

**STATUS: NO REAL DATA**

Depoda yetkili gerçek usability/survey tidy export'u yoktur. Analiz hattı hazırdır; bilimsel sonuç yoktur. Eski sonuç raporundaki n=20, %85/%90, 4,2/12,7 saniye, Mann–Whitney U, p<0,001 ve Cohen's d=2,84 değerleri input değildir ve bu hat tarafından yeniden üretilmiş sayılmaz.

## Kurulum

Windows PowerShell:

```powershell
cd C:\Users\TAHA\Desktop\2209\nutrisense
py -3.13 -m venv analysis\.venv
.\analysis\.venv\Scripts\python.exe -m pip install --requirement analysis\requirements.lock
```

Sistemde `py` yoksa kurulmuş Python 3.13 executable yolunu açıkça kullanın. Secret veya gerçek veri requirements dosyasına yazılmaz.

## Tek komut

Gerçek export'lar varsayılan konumdaysa:

```powershell
.\analysis\.venv\Scripts\python.exe analysis\run_analysis.py --mode real
```

Beklenen girdiler:

- `analysis/data/real/usability_tidy.json`
- `analysis/data/real/survey_tidy.json`

Dosyalar yoksa komut başarılı biçimde yalnız `STATUS: NO REAL DATA` manifesti üretir; tablo, grafik veya istatistik üretmez. Dosya varsa kalite kapısı geçmeden analiz başlamaz.

Yetkili export örneği; token değerini komut geçmişine yazmayın, kurumun güvenli indirme prosedürünü kullanın:

```text
GET /api/v1/usability/export/tidy
GET /api/v1/survey/export/tidy
```

## Sentetik pipeline testi

```powershell
.\analysis\.venv\Scripts\python.exe analysis\tools\generate_synthetic_fixture.py --output analysis\data\synthetic
.\analysis\.venv\Scripts\python.exe analysis\run_analysis.py `
  --mode synthetic `
  --usability analysis\data\synthetic\usability_tidy.synthetic.json `
  --survey analysis\data\synthetic\survey_tidy.synthetic.json
```

Sentetik çıktı `analysis/outputs/synthetic/` altındadır, manifestte `synthetic=true` ve `SYNTHETIC_PIPELINE_TEST_ONLY` taşır. `docs/tubitak_sonuc_raporu.md` içine kopyalanamaz.

## Test

```powershell
$env:PYTHONPATH="analysis\src"
.\analysis\.venv\Scripts\python.exe -m pytest analysis\tests -q
```

Testler; no-data kapısını, sentetik/gerçek ayrımını, kalite hatalarını, result ID–manifest izini, grafik metadata'sını ve PII redaksiyonunu doğrular.

## Çıktı yapısı

Her run `analysis/outputs/<real|synthetic>/<run-id>/` altında:

- `results_manifest.json`
- `artifact_metadata.json`
- `tables/condition_descriptives.csv`
- `tables/primary_inference.csv`
- `tables/task_descriptives.csv`
- `tables/sensitivity_analysis.csv`
- `tables/survey_likert.csv`
- `tables/qualitative_redacted.csv`
- `figures/success_rate.png`
- `figures/duration_boxplot.png`

Gerçek run ayrıca `analysis/results_manifest.json` kanonik dosyasını günceller. Her tablo satırının `result_id` alanı manifestte kaynak değişken, yöntem, komut ve artefakta bağlanır. Her CSV/PNG run ID, checksum, UTC tarih, plan sürümü ve synthetic işareti taşır.

## Bilimsel seçimler

Kanonik tasarım aynı kişide iki koşuldur. Ana testler katılımcı düzeyi eşleştirilmiş sign-flip permutation testidir. İki eş-birincil sonuç Holm ile düzeltilir. Süre için paired rank-biserial etki ve bootstrap %95 GA; koşul başarı oranı için Wilson %95 GA üretilir. Likert maddeler ayrı medyan/IQR ve dağılım olarak verilir. Mevcut anket tek ölçek kabul edilmediğinden Cronbach alpha ve toplam skor üretilmez.

Ayrıntılar: [ön analiz planı](PRE_ANALYSIS_PLAN.md), [veri sözlüğü](DATA_DICTIONARY.md), [nitel kod planı](QUALITATIVE_CODEBOOK.md).

## Güvenlik

Ham gerçek veri ve run çıktıları `.gitignore` kapsamındadır. Çıktıdaki participant kimliği körlenmiş analiz ID'sidir. Regex redaksiyonu kişisel veri temizliği garantisi değildir; nitel dosya paylaşılmadan yetkili insan incelemesi zorunludur.
