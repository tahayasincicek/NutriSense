import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EXPERIMENT_ID = "20260908T060321Z-b000d69c58"


def test_deployed_model_documentation_matches_training_config() -> None:
    config = json.loads(
        (ROOT / "ml" / "runs" / EXPERIMENT_ID / "config.json").read_text(
            encoding="utf-8"
        )
    )
    manifest = json.loads(
        (ROOT / "assets" / "models" / "model_manifest.json").read_text(
            encoding="utf-8"
        )
    )
    model_card = (ROOT / "ml" / "MODEL_CARD.md").read_text(encoding="utf-8")

    model = config["model"]
    assert manifest["experiment_id"] == EXPERIMENT_ID
    assert f"`{model['architecture']}`" in model_card
    assert f"`alpha={model['alpha']}`" in model_card


def test_result_report_describes_the_local_nutrition_catalog() -> None:
    report = (ROOT / "docs" / "tubitak_sonuc_raporu.md").read_text(
        encoding="utf-8"
    )

    assert "Kaynak ve sürüm bilgili yerel katalog" in report
    assert "| Kalori Veritabanı | Nutritionix API |" not in report


def test_literature_work_package_has_at_least_twenty_traceable_sources() -> None:
    review = (ROOT / "docs" / "literatur_taramasi.md").read_text(
        encoding="utf-8"
    )
    rows = re.findall(r"^\|\s*\d+\s*\|.*$", review, flags=re.MULTILINE)

    assert len(rows) >= 20
    assert all("https://" in row for row in rows)
