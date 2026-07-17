"""Deprecated compatibility entry point for evidence-gated TFLite conversion.

This command intentionally fails when the real model, validation decision, labels,
manifest, or calibration images are missing. It never creates a demo model or
uses random representative data.
"""
from pathlib import Path
import sys

ML_SRC = Path(__file__).resolve().parents[1] / "ml" / "src"
sys.path.insert(0, str(ML_SRC))

from nutrisense_ml.convert import main  # noqa: E402


if __name__ == "__main__":
    main()
