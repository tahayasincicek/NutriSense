#!/usr/bin/env python3
"""Create the V13 low-rate config after adding reviewed target images."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    config = json.loads(args.source.read_text(encoding="utf-8"))
    config["scope_id"] = "nutrisense-tr137-v7-targeted-open-data"
    model = config["model"]
    model.update(
        {
            "pipeline_revision": 11,
            "head_epochs": 0,
            "fine_tune_epochs": 5,
            "fine_tune_last_layers": 40,
            "learning_rate_fine_tune": 1e-6,
            "early_stopping_patience": 2,
            "label_sample_weight_multipliers": {
                "adana_kebap": 1.20,
                "kebap": 1.20,
                "kayisi": 1.15,
                "seftali": 1.05,
                "patlamis_misir": 1.20,
                "misir": 1.02
            },
            "speed_note": (
                "V13 warm-start from V12 with 41 reviewed, deduplicated, "
                "open-license train-only images; validation/test unchanged"
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
