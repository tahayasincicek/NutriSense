from pathlib import Path

import pytest

from nutrisense_ml.convert import convert
from nutrisense_ml.evaluate import select_threshold


def test_converter_never_builds_demo_model(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="demo fallback is forbidden"):
        convert(tmp_path / "missing-run", tmp_path / "data", tmp_path / "output", ["float32"])


def test_rejection_threshold_can_block_unsafe_model() -> None:
    np = pytest.importorskip("numpy")
    true = np.array([0, 1])
    supported = np.array([[0.51, 0.49], [0.52, 0.48]])
    ood = np.array([[0.99, 0.01], [0.98, 0.02]])
    assert select_threshold(true, supported, ood, min_coverage=0.5, max_error=0.1) is None
