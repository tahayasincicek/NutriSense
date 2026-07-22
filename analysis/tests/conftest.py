from pathlib import Path
import sys


ANALYSIS_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = ANALYSIS_ROOT.parent
sys.path.insert(0, str(ANALYSIS_ROOT / "src"))
sys.path.insert(0, str(REPOSITORY_ROOT))
