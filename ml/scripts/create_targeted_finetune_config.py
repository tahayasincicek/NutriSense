#!/usr/bin/env python3
"""Create a conservative warm-start config for validation regressions."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


TARGET_MULTIPLIERS = {
    "adana_kebap": 1.15,
    "kebap": 1.15,
    "kayisi": 1.12,
    "seftali": 1.08,
    "patlamis_misir": 1.15,
    "misir": 1.05,
    "cipura": 1.08,
    "levrek": 1.12,
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    config = json.loads(args.source.read_text(encoding="utf-8"))
    model = config["model"]
    config["scope_id"] = "nutrisense-tr137-v6-targeted-finetune"
    model.update(
        {
            "pipeline_revision": 10,
            "head_epochs": 0,
            "fine_tune_epochs": 7,
            "fine_tune_last_layers": 60,
            "learning_rate_fine_tune": 2e-6,
            "early_stopping_patience": 3,
            "label_sample_weight_multipliers": TARGET_MULTIPLIERS,
            "speed_note": (
                "Conservative warm-start fine-tune from v11; small weights for "
                "validation confusion clusters without changing held-out splits"
            ),
        }
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(config, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
