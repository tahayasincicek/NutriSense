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

def _choice(rng: random.Random, choices: tuple) -> str:
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

def build_study(participant_count: int = 30, seed: int = 42):
    rng = random.Random(seed)
    usability, survey, profiles = [], [], []
    base = datetime(2026, 9, 1, 9, 0, tzinfo=timezone.utc)
    for p in range(participant_count):
        participant_id = _participant(p)
        session_id = str(UUID(int=1000 + p))
        sequence = "AB" if p % 2 == 0 else "BA"
        age, vision, experience, reader = (_choice(rng, x) for x in (AGE, VISION, EXPERIENCE, READERS))
        ability = rng.gauss(0, .62) + {"baslangic": -.48, "orta": 0, "ileri": .42}[experience]

        profiles.append({
            "participant_code": f"P-{p + 1:03d}", "participant_id": participant_id,
            "data_origin": "synthetic", "age_group": age, "vision_profile": vision,
            "screen_reader": reader, "assistive_technology_experience": experience,
            "smartphone_experience_years": int(round(_clip(rng.gauss(6.2, 2.8), 1, 15))),
            "counterbalance_sequence": sequence, "consent_status": "APPROVED",
            "researcher_note": "Yalnız analiz hattı testi için sentetik veri",
        })

        order = CONDITIONS if sequence == "AB" else tuple(reversed(CONDITIONS))
        for order_index, condition in enumerate(order):
            for task_index, task_id in enumerate(TASKS):
                treatment = .98 if condition == "nutrisense" else .12
                # Başarı oranını %96 - %99 aralığında tut
                success = rng.random() < 0.97
                help_probability = _clip(.10 - ability * .02, .01, .15)
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
                    "protocol_version": "v1.0.0-final", "approval_reference": "2026-TUBITAK-001",
                    "data_origin": "synthetic", "counterbalance_sequence": sequence,
                    "session_date": started.isoformat(), "task_id": task_id, "condition": condition,
                    "status": "completed" if success else "failed", "started_at": started.isoformat(),
                    "ended_at": (started + timedelta(seconds=duration)).isoformat(), "duration_seconds": duration,
                    "success": success, "error_count": errors, "assistance_level": assistance,
                    "abort_reason": None if success else "task_failure", "timing_source": "monotonic",
                    "manually_edited": False, "edit_reason": None,
                    "researcher_note": "",
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
                "protocol_version": "v1.0.0-final", "approval_reference": "2026-TUBITAK-001",
                "survey_version": "1.0", "data_origin": "synthetic", "question_id": question_id,
                "answer": answer, "answered_at": submitted.isoformat(), "completion_seconds": completion,
                "submitted_at": submitted.isoformat(),
            })

    meta = {
        "schema_version": "1.0", "synthetic": True, "data_origin": "synthetic",
        "participant_count": participant_count,
    }
    return ({**meta, "rows": usability}, {**meta, "rows": survey}, {**meta, "rows": profiles})

if __name__ == "__main__":
    out_dir = Path(__file__).resolve().parent / "analysis" / "data" / "study_fixtures"
    out_dir.mkdir(parents=True, exist_ok=True)

    usability, survey, profiles = build_study(30)

    (out_dir / "usability_tidy.json").write_text(json.dumps(usability, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out_dir / "survey_tidy.json").write_text(json.dumps(survey, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out_dir / "participant_profiles.json").write_text(json.dumps(profiles, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Analiz fixture verileri oluşturuldu: {out_dir}")
