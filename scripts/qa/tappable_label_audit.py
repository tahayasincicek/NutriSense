"""Etiketsiz dokunulabilir öğeleri bulur.

Görme engelli kullanıcı ekranda parmağını gezdirirken ekran okuyucu, dokunulan
öğenin etiketini okur. Etiketi olmayan bir düğme yalnız "düğme" diye okunur ve
kullanıcı neye dokunduğunu anlayamaz.

Bu denetim, dokunma geri çağrısı olan her widget'ın yakınında bir etiket
kaynağı (Semantics label, tooltip, Text çocuğu veya AccessibleButton label)
bulunup bulunmadığına bakar. Statik bir tarama olduğu için kesin değildir;
amacı gözden kaçanları listelemektir.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TAP_PATTERN = re.compile(r"\b(onTap|onPressed|onLongPress)\s*:")
# Etiket sayılan işaretler: açık semantik etiket, tooltip, görünen metin ya da
# etiketi zorunlu kılan kendi bileşenlerimiz.
LABEL_MARKERS = (
    "label:",
    "tooltip:",
    "semanticLabel",
    "Text(",
    "AppStrings.",
    # Yardımcı kurucular etiketi parametre olarak alır; çağrı yerinde
    # görünen metin budur.
    "title:",
    "subtitle:",
    "Semantics(",
)
# Etiketi çağıran tarafın verdiği yeniden kullanılabilir bileşenler; gövdede
# etiket aramak yanlış pozitif üretir.
GENERIC_WIDGET_FILES = ("shared/widgets/",)

WINDOW = 25


def audit(root: Path) -> list[tuple[Path, int, str]]:
    findings: list[tuple[Path, int, str]] = []
    for path in sorted(root.rglob("*.dart")):
        relative = path.relative_to(root).as_posix()
        if any(marker in relative for marker in GENERIC_WIDGET_FILES):
            continue
        lines = path.read_text(encoding="utf-8").splitlines()
        for index, line in enumerate(lines):
            if not TAP_PATTERN.search(line):
                continue
            if line.lstrip().startswith("//"):
                continue
            # Devre dışı bırakılmış geri çağrılar dokunulamaz.
            if re.search(r":\s*null\s*[,)]", line):
                continue
            start = max(0, index - WINDOW)
            end = min(len(lines), index + WINDOW + 1)
            context = "\n".join(lines[start:end])
            if any(marker in context for marker in LABEL_MARKERS):
                continue
            findings.append((path, index + 1, line.strip()[:70]))
    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("lib"))
    parser.add_argument(
        "--max-allowed",
        type=int,
        default=0,
        help="Bu sayıdan fazla etiketsiz öğe bulunursa hata döner.",
    )
    args = parser.parse_args()

    findings = audit(args.root)
    for path, line_number, snippet in findings:
        print(f"{path.as_posix()}:{line_number}: {snippet}")
    print(f"etiketsiz dokunulabilir oge: {len(findings)}")

    if len(findings) > args.max_allowed:
        print(
            f"FAIL: izin verilen en fazla {args.max_allowed}, bulunan {len(findings)}",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
