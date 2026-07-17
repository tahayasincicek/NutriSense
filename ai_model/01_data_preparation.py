# ==============================================================================
# 01_data_preparation.py
# NutriSense AI — Veri Seti Hazırlama Pipeline'ı
#
# Google Colab'da çalıştırılmak üzere tasarlanmıştır.
# Her bölüm ayrı bir Colab hücresine karşılık gelir.
#
# İçerik:
#   1. GPU kontrolü ve kütüphane kurulumu
#   2. Food-101 + UEC Food-256 veri seti indirme
#   3. Türk yemekleri veri seti oluşturma (web scraping)
#   4. Veri setlerini birleştirme (merge)
#   5. Veri artırma (augmentation) — tf.data API
#   6. Stratified train/val/test split (%70/%15/%15)
#   7. Sınıf dengesizliği — class_weight hesaplama
# ==============================================================================

# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 1: GPU Kontrolü ve Kütüphane Kurulumu
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 📦 Ortam Hazırlığı
GPU bağlantısını doğrula ve gerekli kütüphaneleri kur.
Colab'da **Runtime → Change runtime type → GPU** seçili olmalı.
"""

import os
import json
import shutil
import zipfile
import random
import numpy as np
from pathlib import Path
from collections import Counter

import tensorflow as tf
print(f"TensorFlow sürümü: {tf.__version__}")

# GPU kontrolü
gpus = tf.config.list_physical_devices('GPU')
if gpus:
    print(f"✅ GPU bulundu: {gpus}")
    for gpu in gpus:
        tf.config.experimental.set_memory_growth(gpu, True)
else:
    print("⚠️ GPU bulunamadı! Eğitim CPU ile yapılacak (çok yavaş olabilir).")

# Sabit rastgelelik (reproducibility)
SEED = 42
tf.random.set_seed(SEED)
np.random.seed(SEED)
random.seed(SEED)

# Çalışma dizinleri
BASE_DIR = Path("/content/nutrisense_ai")
RAW_DATA_DIR = BASE_DIR / "raw_datasets"
MERGED_DIR = BASE_DIR / "merged_dataset"
TRAIN_DIR = BASE_DIR / "split" / "train"
VAL_DIR = BASE_DIR / "split" / "val"
TEST_DIR = BASE_DIR / "split" / "test"

for d in [RAW_DATA_DIR, MERGED_DIR, TRAIN_DIR, VAL_DIR, TEST_DIR]:
    d.mkdir(parents=True, exist_ok=True)

print(f"📁 Çalışma dizini: {BASE_DIR}")


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 2: Food-101 Veri Setini İndirme
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🍕 Food-101 Veri Seti
101 yiyecek sınıfı, sınıf başına 1000 görsel (toplam 101.000 görsel).
Batı mutfağı ağırlıklı: pizza, hamburger, sushi, vb.
Kaynak: https://data.vision.ee.ethz.ch/cvl/food-101.tar.gz
"""

FOOD101_URL = "https://data.vision.ee.ethz.ch/cvl/food-101.tar.gz"
FOOD101_DIR = RAW_DATA_DIR / "food-101"

def download_food101():
    """Food-101 veri setini indir ve çıkart."""
    tar_path = RAW_DATA_DIR / "food-101.tar.gz"

    if FOOD101_DIR.exists() and any(FOOD101_DIR.iterdir()):
        print("✅ Food-101 zaten mevcut, indirme atlanıyor.")
        return

    print("⬇️  Food-101 indiriliyor (~5GB)...")
    tf.keras.utils.get_file(
        fname=str(tar_path),
        origin=FOOD101_URL,
        extract=True,
        cache_dir=str(RAW_DATA_DIR),
        cache_subdir=".",
    )
    print("✅ Food-101 indirildi ve çıkartıldı.")

download_food101()

# Sınıf listesi
food101_classes = sorted([
    d.name for d in (FOOD101_DIR / "images").iterdir() if d.is_dir()
]) if (FOOD101_DIR / "images").exists() else []
print(f"Food-101 sınıf sayısı: {len(food101_classes)}")
if food101_classes:
    print(f"Örnek sınıflar: {food101_classes[:10]}")


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 3: UEC Food-256 Veri Seti
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🍜 UEC Food-256 Veri Seti
256 yiyecek sınıfı, Japon + genel Asya mutfağı ağırlıklı.
Kaynak: http://foodcam.mobi/dataset256.html

Not: Bu veri seti direkt indirilemiyorsa, Kaggle mirror kullanılabilir.
"""

UEC256_DIR = RAW_DATA_DIR / "uec-food-256"

def download_uec256():
    """UEC Food-256 veri setini indir."""
    if UEC256_DIR.exists() and any(UEC256_DIR.iterdir()):
        print("✅ UEC Food-256 zaten mevcut, indirme atlanıyor.")
        return

    print("⬇️  UEC Food-256 indiriliyor...")
    # Kaggle API ile indirme (Colab'da kaggle.json gerekir)
    try:
        os.system("pip install -q kaggle")
        os.system(
            f"kaggle datasets download -d "
            f"imbikraam/uec-food-256 "
            f"-p {RAW_DATA_DIR} --unzip"
        )
        print("✅ UEC Food-256 indirildi.")
    except Exception as e:
        print(f"⚠️ UEC Food-256 indirilemedi: {e}")
        print("   Manuel olarak indirip raw_datasets/uec-food-256 klasörüne koyun.")
        UEC256_DIR.mkdir(parents=True, exist_ok=True)

download_uec256()


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 4: Türk Yemekleri Veri Seti Oluşturma (Web Scraping)
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🇹🇷 Türk Yemekleri Veri Seti
Türkiye'de yaygın tüketilen yiyeceklerin görselleri.
Üç yöntemle toplanabilir:
1. Bing/Google Image Search API ile otomatik indirme
2. Kaggle'daki Türk yemekleri veri setleri
3. Manuel toplama + etiketleme

Aşağıda otomatik indirme scripti ve kategori listesi yer almaktadır.
"""

# Türk yemekleri kategori listesi (50 sınıf)
TURKISH_FOODS = [
    # Ana yemekler
    "iskender_kebap", "adana_kebap", "lahmacun", "pide",
    "kofte", "imam_bayildi", "karniyarik", "etli_ekmek",
    "tantuni", "cig_kofte", "manti", "yaprak_sarma",
    "dolma", "hamsili_pilav", "kuzu_tandir",
    # Çorbalar
    "mercimek_corbasi", "ezogelin_corbasi", "iskembe_corbasi",
    "tarhana_corbasi", "yayla_corbasi",
    # Kahvaltı
    "menemen", "simit", "pogaca", "borek", "sucuklu_yumurta",
    "bal_kaymak", "acma",
    # Tatlılar
    "baklava", "kunefe", "sutlac", "kazandibi",
    "lokma", "tulumba", "asure", "revani",
    # Salatalar ve mezeler
    "coban_salata", "cacik", "humus", "kisir",
    "patlican_salata", "atom_salata",
    # İçecekler
    "ayran", "turk_cayi", "turk_kahvesi", "salep", "salgam",
    # Meyve ve sebze
    "elma", "portakal", "muz", "domates", "salatalik",
]

TURKISH_DIR = RAW_DATA_DIR / "turkish_foods"

def create_turkish_dataset_structure():
    """Türk yemekleri klasör yapısını oluştur ve örnek indirme scripti sağla."""

    print(f"🇹🇷 Türk yemekleri klasör yapısı oluşturuluyor ({len(TURKISH_FOODS)} sınıf)...")

    for food in TURKISH_FOODS:
        food_dir = TURKISH_DIR / food
        food_dir.mkdir(parents=True, exist_ok=True)

    print(f"✅ {len(TURKISH_FOODS)} sınıf klasörü oluşturuldu: {TURKISH_DIR}")
    return TURKISH_FOODS

def download_images_bing(query, save_dir, max_images=200):
    """
    Bing Image Search API ile görsel indirme.
    NOT: API anahtarı gereklidir. Alternatif olarak bing_image_downloader paketi kullanılabilir.

    Kullanım:
        pip install bing-image-downloader
        from bing_image_downloader import downloader
        downloader.download(query, limit=200, output_dir=save_dir)
    """
    try:
        from bing_image_downloader import downloader
        human_name = query.replace("_", " ")
        print(f"  ⬇️  '{human_name}' indiriliyor ({max_images} görsel)...")
        downloader.download(
            human_name,
            limit=max_images,
            output_dir=str(save_dir.parent),
            adult_filter_off=True,
            force_replace=False,
            timeout=30,
        )
        # İndirilen klasörü hedef konuma taşı
        downloaded_path = save_dir.parent / human_name
        if downloaded_path.exists():
            for img_file in downloaded_path.glob("*.*"):
                shutil.move(str(img_file), str(save_dir / img_file.name))
            shutil.rmtree(str(downloaded_path), ignore_errors=True)
    except ImportError:
        print("  ⚠️ bing-image-downloader paketi bulunamadı.")
        print("  Kurulum: pip install bing-image-downloader")
    except Exception as e:
        print(f"  ⚠️ İndirme hatası ({query}): {e}")

def download_turkish_foods(max_per_class=200):
    """Tüm Türk yemekleri görsellerini indir."""
    print("🇹🇷 Türk yemekleri görselleri indiriliyor...")
    print("   (Bu işlem uzun sürebilir)")

    for i, food in enumerate(TURKISH_FOODS):
        food_dir = TURKISH_DIR / food
        existing = len(list(food_dir.glob("*.*")))
        if existing >= max_per_class:
            print(f"  [{i+1}/{len(TURKISH_FOODS)}] {food}: zaten {existing} görsel var, atlanıyor.")
            continue
        download_images_bing(food, food_dir, max_images=max_per_class)

    print("✅ Türk yemekleri indirme tamamlandı.")

# Klasör yapısını oluştur
create_turkish_dataset_structure()

# Görselleri indirmek için aşağıdaki satırı aktif edin:
# download_turkish_foods(max_per_class=200)


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 5: Veri Setlerini Birleştirme (Merge)
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🔀 Veri Setlerini Birleştirme
Food-101, UEC Food-256 ve Türk yemekleri veri setlerini tek bir birleşik
klasör yapısına kopyalar. Çakışan sınıf isimleri normalize edilir.
"""

# Sınıf ismi normalizasyonu — farklı veri setlerindeki aynı yiyecekler
CLASS_NAME_MAP = {
    # Food-101 → normalize
    "apple_pie": "elma_turtasi",
    "baklava": "baklava",
    "french_fries": "patates_kizartmasi",
    "grilled_salmon": "somon_izgara",
    "hamburger": "hamburger",
    "hot_dog": "sosisli_sandvic",
    "ice_cream": "dondurma",
    "omelette": "omlet",
    "pizza": "pizza",
    "spaghetti_bolognese": "bolonez_makarna",
    "steak": "biftek",
    "sushi": "sushi",
    "tiramisu": "tiramisu",
    # UEC-256 Japon yemekleri — direkt al
    # Türk yemekleri — direkt al
}

def merge_datasets():
    """Tüm veri setlerini tek klasörde birleştirir."""
    print("🔀 Veri setleri birleştiriliyor...")

    merged_classes = set()
    total_images = 0

    # ── Food-101 ──
    food101_images = FOOD101_DIR / "images"
    if food101_images.exists():
        for class_dir in sorted(food101_images.iterdir()):
            if not class_dir.is_dir():
                continue
            normalized_name = CLASS_NAME_MAP.get(class_dir.name, class_dir.name)
            target_dir = MERGED_DIR / normalized_name
            target_dir.mkdir(parents=True, exist_ok=True)

            count = 0
            for img in class_dir.glob("*.*"):
                if img.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp"):
                    target = target_dir / f"food101_{img.name}"
                    if not target.exists():
                        shutil.copy2(str(img), str(target))
                    count += 1
            merged_classes.add(normalized_name)
            total_images += count
        print(f"  ✅ Food-101: {len(food101_classes)} sınıf eklendi")

    # ── UEC Food-256 ──
    if UEC256_DIR.exists():
        uec_count = 0
        for class_dir in sorted(UEC256_DIR.iterdir()):
            if not class_dir.is_dir():
                continue
            normalized_name = CLASS_NAME_MAP.get(class_dir.name, class_dir.name)
            target_dir = MERGED_DIR / normalized_name
            target_dir.mkdir(parents=True, exist_ok=True)

            for img in class_dir.glob("*.*"):
                if img.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp"):
                    target = target_dir / f"uec256_{img.name}"
                    if not target.exists():
                        shutil.copy2(str(img), str(target))
                    uec_count += 1
            merged_classes.add(normalized_name)
        total_images += uec_count
        print(f"  ✅ UEC Food-256: {uec_count} görsel eklendi")

    # ── Türk Yemekleri ──
    if TURKISH_DIR.exists():
        tr_count = 0
        for class_dir in sorted(TURKISH_DIR.iterdir()):
            if not class_dir.is_dir():
                continue
            target_dir = MERGED_DIR / class_dir.name
            target_dir.mkdir(parents=True, exist_ok=True)

            for img in class_dir.glob("*.*"):
                if img.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp"):
                    target = target_dir / f"turkish_{img.name}"
                    if not target.exists():
                        shutil.copy2(str(img), str(target))
                    tr_count += 1
            merged_classes.add(class_dir.name)
        total_images += tr_count
        print(f"  ✅ Türk Yemekleri: {tr_count} görsel eklendi")

    print(f"\n📊 Birleşik Veri Seti Özeti:")
    print(f"   Toplam sınıf: {len(merged_classes)}")
    print(f"   Toplam görsel: ~{total_images}")
    return sorted(merged_classes)

ALL_CLASSES = merge_datasets()
N_CLASSES = len(ALL_CLASSES)
print(f"\n🏷️  N_CLASSES = {N_CLASSES}")


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 6: Veri Artırma Pipeline'ı (tf.data API)
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🔄 Veri Artırma (Data Augmentation)
Görme engelli kullanıcılar kamerayı düzgün tutamayabilir, bu nedenle
artırma stratejisi gerçek kullanım koşullarını simüle eder:
- Döndürme (±30°) — eğik tutma
- Parlaklık/kontrast değişimi — farklı aydınlatma
- Yatay çevirme — simetri
- Gürültü ekleme — düşük kalite kamera
- Occlusion augmentation — kısmen engellenen yiyecek
"""

# Sabitler
IMG_SIZE = 224
BATCH_SIZE = 32
AUTOTUNE = tf.data.AUTOTUNE


def augmentation_pipeline():
    """Eğitim verisi için veri artırma katmanları oluşturur."""
    return tf.keras.Sequential([
        # Rastgele yatay çevirme
        tf.keras.layers.RandomFlip("horizontal"),

        # Rastgele döndürme (±30° ≈ ±0.083 tur)
        tf.keras.layers.RandomRotation(
            factor=0.083,  # ±30 derece
            fill_mode="reflect",
        ),

        # Rastgele yakınlaştırma (zoom)
        tf.keras.layers.RandomZoom(
            height_factor=(-0.15, 0.15),
            width_factor=(-0.15, 0.15),
            fill_mode="reflect",
        ),

        # Rastgele parlaklık ve kontrast
        tf.keras.layers.RandomBrightness(factor=0.2),
        tf.keras.layers.RandomContrast(factor=0.2),

        # Rastgele öteleme (translation)
        tf.keras.layers.RandomTranslation(
            height_factor=0.1,
            width_factor=0.1,
            fill_mode="reflect",
        ),
    ], name="augmentation_pipeline")


def add_gaussian_noise(image, stddev=0.05):
    """Gaussian gürültü ekler — düşük kalite kamera simülasyonu."""
    noise = tf.random.normal(shape=tf.shape(image), mean=0.0, stddev=stddev)
    noisy_image = image + noise
    return tf.clip_by_value(noisy_image, 0.0, 1.0)


def random_occlusion(image, max_patches=2, max_size=40):
    """
    Rastgele dikdörtgen bölgeleri siyahla kapatır.
    Yiyeceğin kısmen engellenmesini simüle eder
    (parmak, çatal, tabak kenarı vb.)
    """
    img = image
    for _ in range(tf.random.uniform([], 0, max_patches + 1, dtype=tf.int32).numpy()):
        h = tf.random.uniform([], 10, max_size, dtype=tf.int32)
        w = tf.random.uniform([], 10, max_size, dtype=tf.int32)
        top = tf.random.uniform([], 0, IMG_SIZE - h, dtype=tf.int32)
        left = tf.random.uniform([], 0, IMG_SIZE - w, dtype=tf.int32)

        # Maske oluştur
        padding = [[top, IMG_SIZE - top - h], [left, IMG_SIZE - left - w], [0, 0]]
        patch = tf.zeros([h, w, 3])
        mask = tf.pad(patch, padding, constant_values=1.0)

        img = img * mask
    return img


def preprocess_image(image, label, training=False):
    """
    Görüntü ön işleme fonksiyonu.
    - Resize: 224x224
    - Normalize: [0, 1]
    - Eğitim modunda: augmentation + gürültü + occlusion
    """
    # Resize
    image = tf.image.resize(image, [IMG_SIZE, IMG_SIZE])
    # Normalize [0, 1]
    image = tf.cast(image, tf.float32) / 255.0

    if training:
        # %30 ihtimalle gürültü ekle
        if tf.random.uniform([]) < 0.3:
            image = add_gaussian_noise(image, stddev=0.05)
        # %20 ihtimalle occlusion uygula
        if tf.random.uniform([]) < 0.2:
            image = random_occlusion(image)

    return image, label


def create_dataset(directory, training=False, batch_size=BATCH_SIZE):
    """
    tf.data.Dataset oluşturur.

    Args:
        directory: Görsel klasörü (sınıf alt klasörleri)
        training: Eğitim modu (augmentation aktif)
        batch_size: Mini-batch boyutu

    Returns:
        tf.data.Dataset — (image, label) çiftleri
    """
    ds = tf.keras.utils.image_dataset_from_directory(
        directory,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=None,  # Önce batch'lemeden al (augmentation için)
        label_mode="categorical",
        shuffle=training,
        seed=SEED,
    )

    # Ön işleme
    ds = ds.map(
        lambda x, y: preprocess_image(x, y, training=training),
        num_parallel_calls=AUTOTUNE,
    )

    # Eğitim modunda augmentation
    if training:
        aug_pipeline = augmentation_pipeline()
        ds = ds.map(
            lambda x, y: (aug_pipeline(x, training=True), y),
            num_parallel_calls=AUTOTUNE,
        )

    # Batch + Prefetch
    ds = ds.batch(batch_size)
    ds = ds.prefetch(AUTOTUNE)

    return ds


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 7: Stratified Train/Val/Test Split (%70/%15/%15)
# ═══════════════════════════════════════════════════════════════════════════════

"""
## ✂️ Stratified Bölümleme
Her sınıftan orantılı sayıda görsel train/val/test'e ayrılır.
Sınıf dengesizliği class_weight ile telafi edilir.
"""

from sklearn.model_selection import train_test_split

def stratified_split(source_dir, train_dir, val_dir, test_dir,
                     train_ratio=0.70, val_ratio=0.15, test_ratio=0.15):
    """
    Birleşik veri setini stratified olarak train/val/test'e böler.
    Her sınıftan orantılı görsel ayrılır.
    """
    assert abs(train_ratio + val_ratio + test_ratio - 1.0) < 1e-6

    print("✂️ Stratified split yapılıyor...")

    all_images = []
    all_labels = []

    source = Path(source_dir)
    for class_dir in sorted(source.iterdir()):
        if not class_dir.is_dir():
            continue
        class_name = class_dir.name
        images = list(class_dir.glob("*.*"))
        images = [
            img for img in images
            if img.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp")
        ]

        for img_path in images:
            all_images.append(str(img_path))
            all_labels.append(class_name)

    total = len(all_images)
    print(f"   Toplam görsel: {total}")
    print(f"   Toplam sınıf: {len(set(all_labels))}")

    if total == 0:
        print("⚠️ Hiç görsel bulunamadı! Veri seti indirme adımını kontrol edin.")
        return

    # İlk split: train vs (val+test)
    X_train, X_temp, y_train, y_temp = train_test_split(
        all_images, all_labels,
        test_size=(val_ratio + test_ratio),
        stratify=all_labels,
        random_state=SEED,
    )

    # İkinci split: val vs test
    relative_test_ratio = test_ratio / (val_ratio + test_ratio)
    X_val, X_test, y_val, y_test = train_test_split(
        X_temp, y_temp,
        test_size=relative_test_ratio,
        stratify=y_temp,
        random_state=SEED,
    )

    print(f"   Train: {len(X_train)} ({len(X_train)/total*100:.1f}%)")
    print(f"   Val:   {len(X_val)} ({len(X_val)/total*100:.1f}%)")
    print(f"   Test:  {len(X_test)} ({len(X_test)/total*100:.1f}%)")

    # Dosyaları kopyala
    for split_name, images, labels in [
        ("train", X_train, y_train),
        ("val", X_val, y_val),
        ("test", X_test, y_test),
    ]:
        split_dir = {"train": train_dir, "val": val_dir, "test": test_dir}[split_name]
        for img_path, label in zip(images, labels):
            dest_dir = Path(split_dir) / label
            dest_dir.mkdir(parents=True, exist_ok=True)
            dest_path = dest_dir / Path(img_path).name
            if not dest_path.exists():
                shutil.copy2(img_path, str(dest_path))

    print("✅ Stratified split tamamlandı!")


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 8: Sınıf Dengesizliği — class_weight Hesaplama
# ═══════════════════════════════════════════════════════════════════════════════

"""
## ⚖️ Sınıf Dengesizliği Yönetimi
Food-101'den 1000 görsel/sınıf varken, Türk yemeklerinden 200 olabilir.
`class_weight` parametresi ile az örnekli sınıflara daha fazla ağırlık verilir.
"""

from sklearn.utils.class_weight import compute_class_weight

def calculate_class_weights(train_dir):
    """
    Eğitim setindeki sınıf dağılımına göre class_weight hesaplar.
    Az örnekli sınıflar daha yüksek ağırlık alır.

    Returns:
        dict — {class_index: weight} formatında sözlük
    """
    print("⚖️ Sınıf ağırlıkları hesaplanıyor...")

    class_counts = {}
    train_path = Path(train_dir)

    for class_dir in sorted(train_path.iterdir()):
        if not class_dir.is_dir():
            continue
        count = len(list(class_dir.glob("*.*")))
        class_counts[class_dir.name] = count

    if not class_counts:
        print("⚠️ Eğitim klasöründe görsel bulunamadı!")
        return {}

    # Sınıf isimleri ve etiketleri
    class_names = sorted(class_counts.keys())
    labels = []
    for i, name in enumerate(class_names):
        labels.extend([i] * class_counts[name])

    # sklearn ile class_weight hesapla
    weights = compute_class_weight(
        class_weight="balanced",
        classes=np.unique(labels),
        y=labels,
    )

    class_weight_dict = {i: w for i, w in enumerate(weights)}

    # En az ve en çok örnekli sınıflar
    sorted_counts = sorted(class_counts.items(), key=lambda x: x[1])
    print(f"\n   En az örnekli 5 sınıf:")
    for name, count in sorted_counts[:5]:
        print(f"     {name}: {count} görsel")

    print(f"\n   En çok örnekli 5 sınıf:")
    for name, count in sorted_counts[-5:]:
        print(f"     {name}: {count} görsel")

    print(f"\n   Ağırlık aralığı: {min(weights):.3f} — {max(weights):.3f}")
    print("✅ Sınıf ağırlıkları hazır.")

    return class_weight_dict


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 9: Tüm Pipeline'ı Çalıştır
# ═══════════════════════════════════════════════════════════════════════════════

"""
## ▶️ Veri Hazırlama Pipeline'ını Çalıştır
Aşağıdaki hücreyi çalıştırarak tüm veri hazırlama adımlarını sırayla yürütün.
"""

def run_data_pipeline():
    """Tüm veri hazırlama adımlarını sırayla çalıştırır."""
    print("=" * 70)
    print("  NutriSense — Veri Hazırlama Pipeline'ı Başlatıldı")
    print("=" * 70)

    # 1. Veri setlerini indir (Food-101, UEC-256, Türk yemekleri)
    download_food101()
    download_uec256()
    create_turkish_dataset_structure()

    # 2. Birleştir
    classes = merge_datasets()

    # 3. Stratified split
    stratified_split(
        source_dir=MERGED_DIR,
        train_dir=TRAIN_DIR,
        val_dir=VAL_DIR,
        test_dir=TEST_DIR,
    )

    # 4. Sınıf ağırlıkları
    class_weights = calculate_class_weights(TRAIN_DIR)

    # 5. Dataset oluştur
    print("\n📦 tf.data Dataset'leri oluşturuluyor...")

    if any(TRAIN_DIR.iterdir()):
        train_ds = create_dataset(str(TRAIN_DIR), training=True)
        val_ds = create_dataset(str(VAL_DIR), training=False)
        test_ds = create_dataset(str(TEST_DIR), training=False)

        print(f"   Train batches: {tf.data.experimental.cardinality(train_ds)}")
        print(f"   Val batches: {tf.data.experimental.cardinality(val_ds)}")
        print(f"   Test batches: {tf.data.experimental.cardinality(test_ds)}")
    else:
        print("⚠️ Eğitim verisi bulunamadı — veri seti indirme adımlarını kontrol edin.")

    # Sınıf listesini ve ağırlıkları kaydet
    config = {
        "n_classes": len(classes),
        "class_names": classes,
        "class_weights": {str(k): v for k, v in class_weights.items()},
        "img_size": IMG_SIZE,
        "batch_size": BATCH_SIZE,
    }
    config_path = BASE_DIR / "dataset_config.json"
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=2)
    print(f"\n💾 Konfigürasyon kaydedildi: {config_path}")

    print("\n" + "=" * 70)
    print("  ✅ Veri Hazırlama Tamamlandı!")
    print("=" * 70)

    return config

# Pipeline'ı çalıştır
# config = run_data_pipeline()
print("\n💡 Pipeline'ı başlatmak için: config = run_data_pipeline()")
