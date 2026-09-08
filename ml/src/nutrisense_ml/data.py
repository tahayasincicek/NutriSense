from __future__ import annotations

import csv
from pathlib import Path
from typing import Any


def read_manifest(path: Path, data_root: Path, split: str | None = None, include_ood: bool = False) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    rows = [row for row in rows if row["status"] == "ok"]
    if split is not None:
        rows = [row for row in rows if row["split"] == split]
    if not include_ood:
        rows = [row for row in rows if row["is_ood"] != "true"]
    root = data_root.resolve()
    for row in rows:
        resolved = (root / row["path"]).resolve()
        try:
            resolved.relative_to(root)
        except ValueError as exc:
            raise ValueError(f"Manifest path escapes data root: {row['path']}") from exc
        row["path"] = resolved.as_posix()
    return rows


def native_center_crop_resize(path, height: int, width: int):
    """TensorFlow'un kendi çözücüsüyle okur; ImageOps.fit ile aynı kırpma.

    `center_crop_resize` PIL'i `tf.numpy_function` içinden çağırdığı için her
    görsel Python kilidini (GIL) tutar ve `num_parallel_calls` işe yaramaz.
    Bu yol saf TF operasyonlarıdır, gerçekten paralel çalışır.

    EXIF döndürmesi burada uygulanmaz; girdilerin `scripts/prefit_images.py`
    ile önceden düzeltilmiş olması gerekir. Kaynak hâlâ ham ise
    `center_crop_resize` kullanılmalıdır.
    """
    import tensorflow as tf

    image = tf.io.decode_jpeg(
        tf.io.read_file(path), channels=3, dct_method="INTEGER_ACCURATE"
    )
    shape = tf.shape(image)
    source_h = tf.cast(shape[0], tf.float32)
    source_w = tf.cast(shape[1], tf.float32)
    target_ratio = tf.cast(width, tf.float32) / tf.cast(height, tf.float32)

    # ImageOps.fit: hedef en-boy oranındaki en büyük ortalanmış bölgeyi kırpar.
    crop_w = tf.minimum(source_w, source_h * target_ratio)
    crop_h = tf.minimum(source_h, source_w / target_ratio)
    offset_w = tf.cast(tf.round((source_w - crop_w) / 2.0), tf.int32)
    offset_h = tf.cast(tf.round((source_h - crop_h) / 2.0), tf.int32)
    image = tf.image.crop_to_bounding_box(
        image, offset_h, offset_w, tf.cast(tf.round(crop_h), tf.int32), tf.cast(tf.round(crop_w), tf.int32)
    )
    image = tf.image.resize(image, [height, width], method="bilinear", antialias=True)
    image.set_shape([height, width, 3])
    return image


def center_crop_resize(path: str, height: int, width: int):
    import numpy as np
    import tensorflow as tf
    from PIL import Image, ImageOps

    def decode(value):
        # tf.numpy_function geri çağrıya EagerTensor değil NumPy değeri verir;
        # bu 0 boyutlu dizi ya da bytes olabilir. .numpy() yalnız
        # tf.py_function kullanılsaydı doğru olurdu.
        raw = value.numpy() if hasattr(value, "numpy") else value
        if isinstance(raw, np.ndarray):
            raw = raw.item()
        resolved = Path(raw.decode("utf-8") if isinstance(raw, bytes) else str(raw))
        with Image.open(resolved) as opened:
            rgb = ImageOps.exif_transpose(opened).convert("RGB")
            fitted = ImageOps.fit(rgb, (width, height), method=Image.Resampling.BILINEAR, centering=(0.5, 0.5))
            return np.asarray(fitted, dtype=np.float32)

    image = tf.numpy_function(decode, [path], Tout=tf.float32)
    image.set_shape([height, width, 3])
    return image


def build_dataset(
    rows,
    labels: list[str],
    height: int,
    width: int,
    batch_size: int,
    training: bool,
    seed: int,
    allow_unknown_labels: bool = False,
    decoder: str = "pil",
):
    """Görselleri okuyan tf.data hattını kurar.

    `allow_unknown_labels` yalnız etiketin kullanılmadığı çağrılar içindir;
    OOD satırları sınıf listesinde bulunmaz. Varsayılan kapalıdır, böylece
    eğitimde yanlış yazılmış bir etiket sessizce geçmez.
    """
    import tensorflow as tf

    label_to_index = {label: index for index, label in enumerate(labels)}
    paths = [row["path"] for row in rows]
    if allow_unknown_labels:
        indices = [label_to_index.get(row["label"], -1) for row in rows]
    else:
        indices = [label_to_index[row["label"]] for row in rows]
    ds = tf.data.Dataset.from_tensor_slices((paths, indices))
    if training:
        ds = ds.shuffle(len(rows), seed=seed, reshuffle_each_iteration=True)


    if decoder not in {"pil", "native_prefitted"}:
        raise ValueError(f"Bilinmeyen decoder: {decoder}")
    read_image = native_center_crop_resize if decoder == "native_prefitted" else center_crop_resize

    def load(path, label):
        return read_image(path, height, width), label

    options = tf.data.Options()
    options.experimental_deterministic = True
    pipeline = (
        ds.map(load, num_parallel_calls=tf.data.AUTOTUNE, deterministic=True)
        .batch(batch_size)
        .with_options(options)
    )
    return pipeline.prefetch(tf.data.AUTOTUNE)
