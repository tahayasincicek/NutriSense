"""Deterministic synthetic HCI study generator; never scientific evidence."""
from __future__ import annotations

import argparse
import json
import math
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import UUID

TASKS = [f"t{i}" for i in range(1, 7)]
CONDITIONS = ("nutrisense", "standardized_assistance")
DIFFICULTY = dict(zip(TASKS, (-.20, .10, .34, .05, .22, .42)))
BASE_SECONDS = dict(zip(TASKS, (29, 38, 47, 34, 42, 51)))
AGE = (("18-24", .18), ("25-34", .26), ("35-44", .22), ("45-54", .18), ("55+", .16))
VISION = (("tam_gorme_kaybi", .58), ("az_goren", .42))
EXPERIENCE = (("baslangic", .22), ("orta", .43), ("ileri", .35))
READERS = (("TalkBack", .54), ("VoiceOver", .35), ("Diger", .11))
Q1 = (
    "Bir yakınımdan yardım istiyordum",
    "Ambalaj bilgisini ekran okuyucuyla arıyordum",
    "İnternette ürün veya yemek adıyla arama yapıyordum",
    "Besini tahmin ederek kayıt tutmadan devam ediyordum",
)
Q6 = (
    "Sesli yönlendirme adımları takip etmeyi kolaylaştırdı.",
    "Sonucun tekrar okunabilmesi güven verdi.",
    "Kamera konumlandırma ipuçları yararlıydı ancak daha kısa olabilir.",
    "Porsiyonun adet veya gram olarak sorulması anlaşılırdı.",
    "Düşük güvenli tahminde alternatiflerin sunulması karar vermeyi kolaylaştırdı.",
    "Raporu uygulama içinde güvenli biçimde görebilmek faydalıydı.",
)
Q7 = (
    "Gürültülü ortamlar için titreşim geri bildirimi artırılabilir.",
    "Kamera hizalaması için daha sık ve kısa sesli uyarı verilebilir.",
    "Son işlem geri alma komutu her ekranda aynı ifadeyle çalışabilir.",
    "Düşük güvenli sonuçlarda ilk üç alternatif sesli okunabilir.",
    "Az gören kişiler için kontrast seçenekleri çoğaltılabilir.",
    "Çevrimdışı kullanımda açık özellikler daha erken söylenebilir.",
)


def _participant(index: int) -> str:
    return str(UUID(int=index + 1))


def _choice(rng: random.Random, choices: tuple[tuple[str, float], ...]) -> str:
    point, total = rng.random(), 0.0
    for value, weight in choices:
        total += weight
        if point <= total:
            return value
    return choices[-1][0]


def _clip(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _likert(rng: random.Random, centre: float) -> int:
    return int(round(_clip(rng.gauss(centre, .72), 1, 5)))


def build_study(participant_count: int = 120, seed: int = 2209) -> tuple[dict, dict, dict]:
    rng = random.Random(seed)
    usability, survey, profiles = [], [], []
    base = datetime(2026, 8, 3, 9, 0, tzinfo=timezone.utc)
    for p in range(participant_count):
        participant_id, session_id = _participant(p), str(UUID(int=1000 + p))
        sequence = "AB" if p % 2 == 0 else "BA"
        age, vision, experience, reader = (_choice(rng, x) for x in (AGE, VISION, EXPERIENCE, READERS))
        ability = rng.gauss(0, .62) + {"baslangic": -.48, "orta": 0, "ileri": .42}[experience]
        profiles.append({
            "participant_code": f"SYN-{p + 1:03d}", "participant_id": participant_id,
            "data_origin": "synthetic", "age_group": age, "vision_profile": vision,
            "screen_reader": reader, "assistive_technology_experience": experience,
            "smartphone_experience_years": int(round(_clip(rng.gauss(6.2, 2.8), 1, 15))),
            "counterbalance_sequence": sequence, "consent_status": "NOT_APPLICABLE_SYNTHETIC",
            "researcher_note": "SYNTHETIC PROFILE — NO HUMAN DATA",
        })
        order = CONDITIONS if sequence == "AB" else tuple(reversed(CONDITIONS))
        for order_index, condition in enumerate(order):
            for task_index, task_id in enumerate(TASKS):
                treatment = .98 if condition == "nutrisense" else .12
                probability = 1 / (1 + math.exp(-(0.62 + ability + treatment + (.13 if order_index else 0) - DIFFICULTY[task_id])))
                success = rng.random() < probability
                help_probability = _clip(.31 - treatment * .16 - ability * .06 + DIFFICULTY[task_id] * .10, .04, .55)
                assistance = "none"
                if success and rng.random() < help_probability:
                    assistance = "prompt" if rng.random() < .78 else "partial"
                elif not success:
                    assistance = "partial" if rng.random() < .62 else "full"
                duration = BASE_SECONDS[task_id] * (.72 if condition == "nutrisense" else 1)
                duration *= 1 - min(ability, 1.4) * .08
                duration *= .94 if order_index else 1
                duration += rng.gauss(0, 5.8) + ({"none": 0, "prompt": 9, "partial": 17, "full": 24}[assistance])
                duration += 13 if not success else 0
                duration = round(_clip(duration, 8, 150), 1)
                errors = max(0, int(round(rng.gauss(.20 + DIFFICULTY[task_id] * .45 + (.70 if not success else 0) + (.24 if assistance != "none" else 0), .55))))
                if not success:
                    errors = max(1, errors)
                started = base + timedelta(days=p // 4, hours=(p % 4) * 2, minutes=order_index * 55 + task_index * 7)
                usability.append({
                    "session_id": session_id, "participant_id": participant_id, "schema_version": "1.0",
                    "protocol_version": "synthetic-field-study-v1", "approval_reference": "NOT-AN-ETHICS-APPROVAL",
                    "data_origin": "synthetic", "counterbalance_sequence": sequence,
                    "session_date": started.isoformat(), "task_id": task_id, "condition": condition,
                    "status": "completed" if success else "failed", "started_at": started.isoformat(),
                    "ended_at": (started + timedelta(seconds=duration)).isoformat(), "duration_seconds": duration,
                    "success": success, "error_count": errors, "assistance_level": assistance,
                    "abort_reason": None if success else "synthetic_task_failure", "timing_source": "monotonic",
                    "manually_edited": False, "edit_reason": None,
                    "researcher_note": "SYNTHETIC OBSERVATION — NO HUMAN DATA",
                })
        submitted = base + timedelta(days=p // 4, hours=(p % 4) * 2 + 1, minutes=50)
        completion = int(round(_clip(rng.gauss(146, 31), 60, 300)))
        answers = {
            "q1": rng.choice(Q1), "q2": _likert(rng, 4.18 + ability * .10),
            "q3": _likert(rng, 4.08 + ability * .08), "q4": _likert(rng, 3.92 + ability * .12),
            "q5": rng.choices(("Evet", "Belki", "Hayır"), weights=(.73, .22, .05), k=1)[0],
            "q6": rng.choice(Q6), "q7": rng.choice(Q7), "q8": _likert(rng, 4.02 + ability * .10),
        }
        for question_id, answer in answers.items():
            survey.append({
                "submission_id": str(UUID(int=2000 + p)), "participant_id": participant_id,
                "protocol_version": "synthetic-field-study-v1", "approval_reference": "NOT-AN-ETHICS-APPROVAL",
                "survey_version": "1.0", "data_origin": "synthetic", "question_id": question_id,
                "answer": answer, "answered_at": submitted.isoformat(), "completion_seconds": completion,
                "submitted_at": submitted.isoformat(),
            })
    meta = {
        "schema_version": "1.0", "synthetic": True, "data_origin": "synthetic",
        "generator": "analysis/tools/generate_fixture.py", "generator_seed": seed,
        "participant_count": participant_count,
        "warning": "YAPAY VERİDİR; GERÇEK KATILIMCI VEYA SAHA BULGUSU DEĞİLDİR.",
    }
    return ({**meta, "rows": usability}, {**meta, "rows": survey}, {**meta, "rows": profiles})


def build_fixture(participant_count: int = 8, seed: int = 2209) -> tuple[dict, dict]:
    usability, survey, _ = build_study(participant_count, seed)
    return usability, survey


def write_fixture(output_dir: Path, participant_count: int = 8, seed: int = 2209) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    usability, survey, profiles = build_study(participant_count, seed)
    items = (("usability_tidy.synthetic.json", usability), ("survey_tidy.synthetic.json", survey), ("participant_profiles.synthetic.json", profiles))
    for filename, payload in items:
        (output_dir / filename).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return output_dir / items[0][0], output_dir / items[1][0]


def main() -> int:
    parser = argparse.ArgumentParser(description="Açıkça etiketli sentetik HCI verisi üretir.")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--participants", type=int, default=120)
    parser.add_argument("--seed", type=int, default=2209)
    args = parser.parse_args()
    if args.participants < 2:
        parser.error("Sentetik fixture en az iki sahte participant içermelidir.")
    usability, survey = write_fixture(args.output, args.participants, args.seed)
    print("SYNTHETIC DATA ONLY — NO HUMAN PARTICIPANTS")
    print(f"participants={args.participants} seed={args.seed}")
    print(usability); print(survey)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
