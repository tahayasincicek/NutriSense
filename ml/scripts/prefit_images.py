# -*- coding: utf-8 -*-
"""Gorselleri hattin yaptigi islemle onceden 224x224'e indirir.

data.py'deki center_crop_resize ile ayni sira: exif_transpose -> RGB -> fit.
Boylece egitim sirasindaki fit islemi kimlik islemine doner, sonuc degismez.
"""

import os
import sys
from multiprocessing import Pool

from PIL import Image, ImageOps

SRC = os.path.expanduser("~/ml/raw")
DST = os.path.expanduser("~/ml/raw224")
SIZE = (224, 224)


def convert(pair):
    rel, _ = pair
    src = os.path.join(SRC, rel)
    dst = os.path.join(DST, rel)
    if os.path.exists(dst):
        return 0
    try:
        with Image.open(src) as opened:
            rgb = ImageOps.exif_transpose(opened).convert("RGB")
            fitted = ImageOps.fit(
                rgb, SIZE, method=Image.Resampling.BILINEAR, centering=(0.5, 0.5)
            )
            fitted.save(dst, "JPEG", quality=95, subsampling=0)
        return 1
    except Exception as exc:
        print("HATA %s: %s" % (rel, exc), file=sys.stderr)
        return 0


def main():
    jobs = []
    for label in sorted(os.listdir(SRC)):
        folder = os.path.join(SRC, label)
        if not os.path.isdir(folder):
            continue
        os.makedirs(os.path.join(DST, label), exist_ok=True)
        for name in os.listdir(folder):
            jobs.append((os.path.join(label, name), None))
    print("islenecek:", len(jobs), flush=True)
    done = 0
    with Pool(18) as pool:
        for i, n in enumerate(pool.imap_unordered(convert, jobs, chunksize=256), 1):
            done += n
            if i % 20000 == 0:
                print("%d/%d" % (i, len(jobs)), flush=True)
    print("yazilan:", done)


if __name__ == "__main__":
    main()
