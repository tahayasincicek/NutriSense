"""Repository-local entry point; keeps the analysis package import explicit."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "src"))

from nutrisense_analysis.pipeline import main  # noqa: E402


if __name__ == "__main__":
    raise SystemExit(main())
