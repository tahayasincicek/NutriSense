"""Deprecated compatibility entry point for leakage-resistant training."""
from pathlib import Path
import sys

ML_SRC = Path(__file__).resolve().parents[1] / "ml" / "src"
sys.path.insert(0, str(ML_SRC))

from nutrisense_ml.train import main  # noqa: E402


if __name__ == "__main__":
    main()
