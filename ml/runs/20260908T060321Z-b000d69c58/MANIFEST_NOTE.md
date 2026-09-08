# Bu deneyde `manifest.csv` neden depoda yok

Eğitim manifesti 96.047 satır ve ~23 MB'dır; Git deposunda tutmak için fazla
büyüktür. Yerine bütünlük kanıtı olarak şunlar durur:

- `manifest.report.json` — sınıf/grup yeterlilik kapıları ve
  `scope_ready_for_training` sonucu
- `metrics_test.json` ve `metrics_validation.json` içindeki `dataset_version`
  alanı — manifest içeriğinin özet karması

Manifest, aynı `dataset_version` değerini üretecek şekilde yeniden
oluşturulabilir:

```bash
python -m nutrisense_ml.manifest \
  --intake data/intake_tr130.csv \
  --data-root data/raw \
  --config configs/tr130_v1.json \
  --licenses sources/licenses.json \
  --output data/manifest_tr130.csv
```

Önceki deneylerin manifestleri (2 Eylül 2026 koşumları) daha küçük olduğu için
depoda tutulmuştur; bu tutarsızlık boyut kaynaklıdır, kasıtlı bir kanıt
eksiltmesi değildir.
