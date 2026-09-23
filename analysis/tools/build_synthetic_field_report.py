"""Build a transparent Turkish report from the latest synthetic analysis run."""
from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
ANALYSIS = ROOT / "analysis"


def main() -> int:
    latest = json.loads((ANALYSIS / "outputs/synthetic/LATEST_STATUS.json").read_text(encoding="utf-8"))
    manifest_path = Path(latest["results_manifest"])
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    run_dir = manifest_path.parent
    profiles_payload = json.loads((ANALYSIS / "data/synthetic/participant_profiles.synthetic.json").read_text(encoding="utf-8"))
    profiles = profiles_payload["rows"]
    usability = json.loads((ANALYSIS / "data/synthetic/usability_tidy.synthetic.json").read_text(encoding="utf-8"))["rows"]
    survey = json.loads((ANALYSIS / "data/synthetic/survey_tidy.synthetic.json").read_text(encoding="utf-8"))["rows"]
    condition = pd.read_csv(run_dir / "tables/condition_descriptives.csv")
    primary = pd.read_csv(run_dir / "tables/primary_inference.csv")
    task = pd.read_csv(run_dir / "tables/task_descriptives.csv")
    likert = pd.read_csv(run_dir / "tables/survey_likert.csv")

    counts = {
        key: Counter(row[key] for row in profiles)
        for key in ("age_group", "vision_profile", "screen_reader", "assistive_technology_experience", "counterbalance_sequence")
    }
    q5 = Counter(row["answer"] for row in survey if row["question_id"] == "q5")
    q1 = Counter(row["answer"] for row in survey if row["question_id"] == "q1")
    open_q6 = Counter(row["answer"] for row in survey if row["question_id"] == "q6")
    open_q7 = Counter(row["answer"] for row in survey if row["question_id"] == "q7")

    ns = condition.loc[condition.condition == "nutrisense"].iloc[0]
    ctrl = condition.loc[condition.condition == "standardized_assistance"].iloc[0]
    success = primary.loc[primary.outcome == "participant independent success rate"].iloc[0]
    duration = primary.loc[primary.outcome.str.contains("median duration")].iloc[0]

    def distribution(counter: Counter) -> str:
        return "\n".join(f"- {name}: {count} (%{count / len(profiles) * 100:.1f})" for name, count in sorted(counter.items()))

    task_lines = []
    for task_id in sorted(task.task_id.unique()):
        a = task[(task.task_id == task_id) & (task.condition == "nutrisense")].iloc[0]
        b = task[(task.task_id == task_id) & (task.condition == "standardized_assistance")].iloc[0]
        task_lines.append(
            f"| {task_id} | %{a.independent_success_rate * 100:.1f} | %{b.independent_success_rate * 100:.1f} | "
            f"{a.duration_median_seconds:.1f} | {b.duration_median_seconds:.1f} |"
        )
    likert_lines = [
        f"| {row.question_id} | {int(row.n)} | {row['median']:.1f} | {row['q1']:.1f}–{row['q3']:.1f} | "
        f"{int(row.count_1)} / {int(row.count_2)} / {int(row.count_3)} / {int(row.count_4)} / {int(row.count_5)} |"
        for _, row in likert.iterrows()
    ]
    q5_lines = "\n".join(f"- {answer}: {count} (%{count / len(profiles) * 100:.1f})" for answer, count in q5.most_common())
    q1_lines = "\n".join(f"- {answer}: {count} (%{count / len(profiles) * 100:.1f})" for answer, count in q1.most_common())
    themes = "\n".join(f"- {text} — {count} sentetik yanıt" for text, count in open_q6.most_common())
    suggestions = "\n".join(f"- {text} — {count} sentetik yanıt" for text, count in open_q7.most_common())

    report = f"""# NutriSense kapsamlı sentetik saha çalışması

> **YAPAY/SENTETİK VERİ UYARISI:** Bu raporda gerçek görme engelli katılımcı, gerçek saha gözlemi veya insanlardan alınmış anket yanıtı yoktur. Tüm kayıtlar Python ile, sabit `{profiles_payload['generator_seed']}` tohumu kullanılarak üretilmiştir. Bulgular ürün akışını, analiz kodunu ve sunum biçimini sınamak içindir; gerçek saha sonucu veya TÜBİTAK kanıtı olarak sunulamaz.

## Yönetici özeti

Sentetik senaryoda {len(profiles)} sanal profil, kişi başına altı görev ve iki koşulla toplam {len(usability):,} görev gözlemi üretildi. Ayrıca sekiz maddelik {len(survey):,} anket yanıtı oluşturuldu. AB/BA sırası dengelendi ve katılımcı düzeyinde eşleştirilmiş analiz uygulandı.

Üretilen senaryoda NutriSense koşulunun bağımsız görev başarı oranı %{ns.independent_success_rate * 100:.1f} (Wilson %95 GA %{ns.success_ci95_low * 100:.1f}–%{ns.success_ci95_high * 100:.1f}), standartlaştırılmış yardım koşulunun oranı %{ctrl.independent_success_rate * 100:.1f} (GA %{ctrl.success_ci95_low * 100:.1f}–%{ctrl.success_ci95_high * 100:.1f}) oldu. Katılımcı düzeyindeki sentetik fark {success.effect * 100:.1f} yüzde puandır (bootstrap %95 GA {success.effect_ci95_low * 100:.1f}–{success.effect_ci95_high * 100:.1f}). Bağımsız başarılı görevlerde medyan süre {ns.successful_duration_median_seconds:.1f} ve {ctrl.successful_duration_median_seconds:.1f} saniyedir; eşleştirilmiş sentetik süre farkı {duration.effect:.1f} saniyedir (GA {duration.effect_ci95_low:.1f}–{duration.effect_ci95_high:.1f}). Bu değerler generator varsayımlarının sonucudur.

## Amaç ve araştırma soruları

1. Uygulama, sentetik kullanım senaryosunda görevlerin bağımsız tamamlanmasını artırıyor mu?
2. Başarılı görevlerin tamamlanma süresi azalıyor mu?
3. Görev türüne göre başarı, süre, hata ve yardım gereksinimi nasıl değişiyor?
4. Erişilebilirlik, güven, kullanım kolaylığı ve yeniden kullanım niyeti maddeleri nasıl dağılıyor?
5. Analiz hattı gerçek veri geldiğinde aynı şema ve kalite kapılarıyla çalışıyor mu?

## Tasarım

- Tasarım: aynı sanal profil içinde iki koşullu, eşleştirilmiş çapraz tasarım.
- Koşullar: `nutrisense` ve `standardized_assistance`.
- Görevler: t1–t6, her koşulda birer kez.
- Sıra: AB/BA, eşit dağılım.
- Örneklem: {len(profiles)} sentetik profil.
- Veri üretimi: sabit tohumlu olasılıksal model; kişi yeteneği, görev güçlüğü, öğrenme/sıra etkisi, yardım düzeyi ve koşul etkisi birlikte kullanıldı.
- Birincil sonuçlar: bağımsız görev başarı oranı ile bağımsız başarılı görevlerin katılımcı medyan süresi.
- Analiz planı: `{manifest['analysis_plan_version']}`.
- Çalıştırma kimliği: `{manifest['analysis_run_id']}`.
- Birleşik SHA-256: `{manifest['inputs']['combined_checksum_sha256']}`.

## Sentetik profil dağılımları

### Yaş grubu
{distribution(counts['age_group'])}

### Görme profili
{distribution(counts['vision_profile'])}

### Ekran okuyucu
{distribution(counts['screen_reader'])}

### Yardımcı teknoloji deneyimi
{distribution(counts['assistive_technology_experience'])}

### Sıra dengelemesi
{distribution(counts['counterbalance_sequence'])}

Bu değişkenler çeşitlilik sınaması için üretilmiştir; demografik gerçekliğe dair çıkarım yapılamaz.

## Görev sonuçları

| Görev | NutriSense bağımsız başarı | Kontrol bağımsız başarı | NutriSense medyan süre (sn) | Kontrol medyan süre (sn) |
|---|---:|---:|---:|---:|
{chr(10).join(task_lines)}

İki eş-birincil sonuçta katılımcı düzeyinde sign-flip permutation testi ve 10.000 tekrar bootstrap güven aralığı kullanıldı. İki p-değeri Holm yöntemiyle düzeltildi. Sentetik veri üreticisine koşul farkı gömüldüğü için anlamlılık, gerçek dünyadaki etkiyi kanıtlamaz.

## Anket sonuçları

| Madde | n | Medyan | IQR aralığı | 1 / 2 / 3 / 4 / 5 sayıları |
|---|---:|---:|---:|---:|
{chr(10).join(likert_lines)}

### q1 — mevcut yöntem
{q1_lines}

### q5 — yeniden kullanma niyeti
{q5_lines}

Sekiz madde doğrulanmış tek boyutlu bir ölçek olmadığı için toplam puan veya Cronbach alfa hesaplanmadı.

## Sentetik açık uçlu temalar

### Beğenilen yönler
{themes}

### Geliştirme önerileri
{suggestions}

Bu metinler katılımcı alıntısı değildir; yapay şablon cümleleridir. Gerçek çalışmada iki bağımsız kodlayıcı, sürümlü kod kitabı ve disclosure kontrolü uygulanmalıdır.

## Veri kalitesi ve yeniden üretilebilirlik

- {len(usability):,} usability satırının tamamı şema, negatif süre, koşul, görev çifti ve durum/başarı tutarlılığı kapılarından geçti.
- {len(survey):,} anket satırının Likert ve soru kimliği kontrolleri geçti.
- Kalite uyarısı sayısı: {len(manifest['quality_warnings'])}.
- Ham kimlikler analiz çıktısında deterministik körlenmiş kimliğe çevrildi.
- Açık metin çıktısı e-posta/telefon regex redaksiyonundan geçti.
- Üretici aynı tohum ve katılımcı sayısıyla aynı ham veriyi yeniden oluşturur.

## Sınırlılıklar ve doğru kullanım

Bu çalışma örneklem, etki, memnuniyet ve tema dağılımlarını varsayımlarla üretir. Gerçek kullanıcı davranışını, erişilebilirliği, model doğruluğunu, klinik yararı veya genellenebilirliği göstermez. Rapordaki p-değerleri üretim modelinin tutarlılığını yansıtır. Başvuru ve sunumlarda başlık ve uyarı korunmalı; “katılımcılar”, “saha çalışmasında bulundu” veya “kanıtlandı” gibi ifadeler kullanılmamalıdır. Gerçek saha çalışması tamamlandığında yalnız `data_origin=participant`, geçerli onam ve etik/onay referanslı veriler gerçek analiz moduna alınmalıdır.

## Dosyalar

- Ham sentetik usability: `analysis/data/synthetic/usability_tidy.synthetic.json`
- Ham sentetik anket: `analysis/data/synthetic/survey_tidy.synthetic.json`
- Sentetik profil: `analysis/data/synthetic/participant_profiles.synthetic.json`
- Analiz manifesti: `{manifest_path.relative_to(ROOT).as_posix()}`
- Koşul tablosu: `{(run_dir / 'tables/condition_descriptives.csv').relative_to(ROOT).as_posix()}`
- Birincil çıkarım: `{(run_dir / 'tables/primary_inference.csv').relative_to(ROOT).as_posix()}`
- Görev tablosu: `{(run_dir / 'tables/task_descriptives.csv').relative_to(ROOT).as_posix()}`
- Anket tablosu: `{(run_dir / 'tables/survey_likert.csv').relative_to(ROOT).as_posix()}`
"""
    output = ROOT / "docs/sentetik_saha_calismasi_raporu.md"
    output.write_text(report, encoding="utf-8")
    summary = {
        "warning": profiles_payload["warning"], "manifest": str(manifest_path),
        "participant_count": len(profiles), "usability_rows": len(usability), "survey_rows": len(survey),
        "profile_counts": {key: dict(value) for key, value in counts.items()},
        "q1_counts": dict(q1), "q5_counts": dict(q5),
    }
    (ANALYSIS / "data/synthetic/field_study_summary.synthetic.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
