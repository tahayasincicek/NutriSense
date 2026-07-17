# ==============================================================================
# 02_model_training.py
# NutriSense AI — MobileNetV3 Transfer Learning Eğitim Pipeline'ı
#
# Google Colab'da çalıştırılmak üzere tasarlanmıştır.
#
# İçerik:
#   1. Model mimarisi — MobileNetV3-Large + Custom Head
#   2. Aşama 1: Sadece üst katmanları eğit (frozen base, 10 epoch)
#   3. Aşama 2: Fine-tuning (son 50 katman açık, 20 epoch)
#   4. Callbacks: EarlyStopping, ReduceLROnPlateau, ModelCheckpoint
#   5. Eğitim ve değerlendirme sonuçları
# ==============================================================================

import json
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

import tensorflow as tf
from tensorflow.keras import layers, models, optimizers, callbacks

# ── Ayarlar ──
BASE_DIR = Path("/content/nutrisense_ai")
TRAIN_DIR = BASE_DIR / "split" / "train"
VAL_DIR = BASE_DIR / "split" / "val"
TEST_DIR = BASE_DIR / "split" / "test"
MODEL_DIR = BASE_DIR / "models"
MODEL_DIR.mkdir(parents=True, exist_ok=True)

IMG_SIZE = 224
BATCH_SIZE = 32
AUTOTUNE = tf.data.AUTOTUNE

# Konfigürasyonu yükle
config_path = BASE_DIR / "dataset_config.json"
if config_path.exists():
    with open(config_path, "r") as f:
        config = json.load(f)
    N_CLASSES = config["n_classes"]
    CLASS_NAMES = config["class_names"]
    CLASS_WEIGHTS = {int(k): v for k, v in config.get("class_weights", {}).items()}
    print(f"✅ Konfigürasyon yüklendi: {N_CLASSES} sınıf")
else:
    N_CLASSES = 200  # Varsayılan
    CLASS_NAMES = []
    CLASS_WEIGHTS = {}
    print(f"⚠️ Konfigürasyon bulunamadı, varsayılan N_CLASSES={N_CLASSES}")


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 1: Veri Setlerini Yükle
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 📦 Eğitim ve Doğrulama Veri Setleri
01_data_preparation.py ile oluşturulan split klasörlerinden yüklenir.
"""

def load_datasets():
    """Train, val, test veri setlerini yükler."""
    print("📦 Veri setleri yükleniyor...")

    train_ds = tf.keras.utils.image_dataset_from_directory(
        str(TRAIN_DIR),
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode="categorical",
        shuffle=True,
        seed=42,
    )

    val_ds = tf.keras.utils.image_dataset_from_directory(
        str(VAL_DIR),
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode="categorical",
        shuffle=False,
        seed=42,
    )

    test_ds = tf.keras.utils.image_dataset_from_directory(
        str(TEST_DIR),
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode="categorical",
        shuffle=False,
        seed=42,
    )

    # Normalize [0, 1]
    normalization = layers.Rescaling(1.0 / 255.0)
    train_ds = train_ds.map(lambda x, y: (normalization(x), y), num_parallel_calls=AUTOTUNE)
    val_ds = val_ds.map(lambda x, y: (normalization(x), y), num_parallel_calls=AUTOTUNE)
    test_ds = test_ds.map(lambda x, y: (normalization(x), y), num_parallel_calls=AUTOTUNE)

    # Prefetch
    train_ds = train_ds.prefetch(AUTOTUNE)
    val_ds = val_ds.prefetch(AUTOTUNE)
    test_ds = test_ds.prefetch(AUTOTUNE)

    print("✅ Veri setleri yüklendi.")
    return train_ds, val_ds, test_ds


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 2: Model Mimarisi — MobileNetV3-Large + Custom Head
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🧠 Model Mimarisi

```
Input (224×224×3)
    │
    ▼
┌──────────────────────────┐
│  MobileNetV3-Large       │  ← ImageNet ağırlıkları (frozen)
│  (include_top=False)     │
│  Output: 7×7×960         │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  GlobalAveragePooling2D  │  → (960,)
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  BatchNormalization      │  Eğitim stabilitesi
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Dense(512, ReLU)        │  Özellik çıkarma
│  Dropout(0.3)            │  Overfitting önleme
│  Dense(256, ReLU)        │  Özellik sıkıştırma
│  Dropout(0.2)            │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Dense(N_CLASSES, Softmax)│  Sınıflandırma
└──────────────────────────┘
```
"""

def build_model(n_classes, fine_tune_at=None):
    """
    MobileNetV3-Large tabanlı transfer learning modeli oluşturur.

    Args:
        n_classes: Çıkış sınıf sayısı
        fine_tune_at: Fine-tuning başlangıç katmanı (None = tümü frozen)

    Returns:
        Derlenmiş Keras modeli
    """

    # ── Base Model: MobileNetV3-Large ──
    base_model = tf.keras.applications.MobileNetV3Large(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,       # Orijinal sınıflandırma kafasını alma
        weights="imagenet",      # ImageNet ön-eğitimli ağırlıklar
        include_preprocessing=False,  # Kendi normalizasyonumuzu kullanıyoruz
    )

    # Tüm katmanları dondur (Aşama 1)
    base_model.trainable = False

    # Fine-tuning: belirtilen katmandan itibaren aç (Aşama 2)
    if fine_tune_at is not None:
        base_model.trainable = True
        for layer in base_model.layers[:fine_tune_at]:
            layer.trainable = False
        trainable = sum(1 for l in base_model.layers if l.trainable)
        total = len(base_model.layers)
        print(f"🔓 Fine-tuning: {trainable}/{total} katman eğitilebilir")

    # ── Custom Classification Head ──
    inputs = tf.keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3), name="input_image")

    # Data augmentation (eğitimde aktif)
    x = tf.keras.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.083),
        layers.RandomZoom(0.15),
        layers.RandomBrightness(0.2),
        layers.RandomContrast(0.2),
    ], name="augmentation")(inputs)

    # Base model
    x = base_model(x, training=False)

    # Pooling + Head
    x = layers.GlobalAveragePooling2D(name="global_avg_pool")(x)
    x = layers.BatchNormalization(name="batch_norm")(x)

    x = layers.Dense(512, activation="relu", name="fc1")(x)
    x = layers.Dropout(0.3, name="dropout1")(x)

    x = layers.Dense(256, activation="relu", name="fc2")(x)
    x = layers.Dropout(0.2, name="dropout2")(x)

    outputs = layers.Dense(n_classes, activation="softmax", name="predictions")(x)

    model = models.Model(inputs, outputs, name="NutriSense_MobileNetV3")

    return model, base_model


def compile_model(model, learning_rate=1e-4):
    """Modeli derler — optimizer, loss, metrics."""
    model.compile(
        optimizer=optimizers.Adam(learning_rate=learning_rate),
        loss="categorical_crossentropy",
        metrics=[
            "accuracy",
            tf.keras.metrics.TopKCategoricalAccuracy(k=5, name="top5_accuracy"),
            tf.keras.metrics.Precision(name="precision"),
            tf.keras.metrics.Recall(name="recall"),
        ],
    )
    return model


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 3: Callbacks Tanımlama
# ═══════════════════════════════════════════════════════════════════════════════

"""
## ⚙️ Eğitim Callback'leri
- **EarlyStopping**: val_loss 5 epoch boyunca iyileşmezse durdur
- **ReduceLROnPlateau**: val_loss 3 epoch boyunca iyileşmezse LR'yi %50 düşür
- **ModelCheckpoint**: En iyi modeli kaydet
"""

def get_callbacks(stage_name="stage1"):
    """Eğitim callback'lerini döner."""
    return [
        # Erken durdurma — overfitting önleme
        callbacks.EarlyStopping(
            monitor="val_loss",
            patience=5,
            restore_best_weights=True,
            verbose=1,
        ),

        # Öğrenme oranı düşürme
        callbacks.ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.5,          # LR'yi yarıya düşür
            patience=3,
            min_lr=1e-7,
            verbose=1,
        ),

        # En iyi modeli kaydet
        callbacks.ModelCheckpoint(
            filepath=str(MODEL_DIR / f"best_model_{stage_name}.keras"),
            monitor="val_accuracy",
            save_best_only=True,
            save_weights_only=False,
            verbose=1,
        ),

        # TensorBoard logları
        callbacks.TensorBoard(
            log_dir=str(BASE_DIR / "logs" / stage_name),
            histogram_freq=1,
        ),
    ]


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 4: Aşama 1 — Üst Katmanları Eğit (Frozen Base)
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 📚 Aşama 1: Transfer Learning (10 Epoch)
MobileNetV3 katmanları dondurulmuş. Sadece custom head eğitilir.
Yüksek learning rate (1e-4) kullanılır çünkü sadece üst katmanlar öğreniyor.
"""

def train_stage1(train_ds, val_ds, class_weights):
    """Aşama 1: Frozen base, sadece üst katmanları eğit."""
    print("=" * 70)
    print("  AŞAMA 1: Transfer Learning — Üst Katmanlar (10 Epoch)")
    print("=" * 70)

    # Model oluştur (base frozen)
    model, base_model = build_model(N_CLASSES, fine_tune_at=None)
    model = compile_model(model, learning_rate=1e-4)

    # Model özeti
    model.summary()
    print(f"\n🔒 Base model ({len(base_model.layers)} katman) tamamen dondurulmuş.")
    print(f"📊 Eğitilebilir parametre: {sum(np.prod(v.shape) for v in model.trainable_weights):,}")

    # Eğitim
    history1 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=10,
        class_weight=class_weights if class_weights else None,
        callbacks=get_callbacks("stage1"),
        verbose=1,
    )

    print("\n✅ Aşama 1 tamamlandı!")
    return model, base_model, history1


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 5: Aşama 2 — Fine-Tuning (Son 50 Katman Açık, 20 Epoch)
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🔧 Aşama 2: Fine-Tuning (20 Epoch)
Son 50 katmanı açarak düşük learning rate (1e-5) ile eğit.
Bu, modelin besin tanımaya özel daha ince ayrıntıları öğrenmesini sağlar.
"""

def train_stage2(model, base_model, train_ds, val_ds, class_weights):
    """Aşama 2: Son 50 katmanı aç, düşük LR ile fine-tune."""
    print("\n" + "=" * 70)
    print("  AŞAMA 2: Fine-Tuning — Son 50 Katman (20 Epoch)")
    print("=" * 70)

    # Son 50 katmanı aç
    total_layers = len(base_model.layers)
    fine_tune_from = max(0, total_layers - 50)

    base_model.trainable = True
    for layer in base_model.layers[:fine_tune_from]:
        layer.trainable = False

    trainable_count = sum(1 for l in base_model.layers if l.trainable)
    print(f"🔓 {trainable_count}/{total_layers} katman eğitilebilir")

    # Düşük learning rate ile yeniden derle
    model = compile_model(model, learning_rate=1e-5)

    total_trainable = sum(np.prod(v.shape) for v in model.trainable_weights)
    print(f"📊 Toplam eğitilebilir parametre: {total_trainable:,}")

    # Eğitim
    history2 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=20,
        class_weight=class_weights if class_weights else None,
        callbacks=get_callbacks("stage2"),
        verbose=1,
    )

    # Final model kaydet
    model.save(str(MODEL_DIR / "nutrisense_final.keras"))
    print(f"\n💾 Final model kaydedildi: {MODEL_DIR / 'nutrisense_final.keras'}")

    print("\n✅ Aşama 2 tamamlandı!")
    return model, history2


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 6: Eğitim Sonuçlarını Görselleştirme
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 📈 Eğitim Grafikleri
Loss ve accuracy eğrilerini çizerek overfitting durumunu analiz eder.
"""

def plot_training_history(history1, history2=None):
    """Eğitim geçmişini grafikleştirir."""

    # İki aşamayı birleştir
    if history2:
        metrics = {}
        for key in history1.history:
            metrics[key] = history1.history[key] + history2.history[key]
    else:
        metrics = history1.history

    fig, axes = plt.subplots(2, 2, figsize=(16, 12))

    # ── Loss ──
    axes[0, 0].plot(metrics["loss"], label="Train Loss", linewidth=2)
    axes[0, 0].plot(metrics["val_loss"], label="Val Loss", linewidth=2)
    if history2:
        axes[0, 0].axvline(x=len(history1.history["loss"]),
                           color="gray", linestyle="--",
                           label="Fine-tuning başlangıcı")
    axes[0, 0].set_title("Loss (Kayıp)", fontsize=14, fontweight="bold")
    axes[0, 0].set_xlabel("Epoch")
    axes[0, 0].set_ylabel("Categorical Crossentropy")
    axes[0, 0].legend()
    axes[0, 0].grid(True, alpha=0.3)

    # ── Accuracy ──
    axes[0, 1].plot(metrics["accuracy"], label="Train Acc", linewidth=2)
    axes[0, 1].plot(metrics["val_accuracy"], label="Val Acc", linewidth=2)
    if history2:
        axes[0, 1].axvline(x=len(history1.history["accuracy"]),
                           color="gray", linestyle="--",
                           label="Fine-tuning başlangıcı")
    axes[0, 1].set_title("Accuracy (Doğruluk)", fontsize=14, fontweight="bold")
    axes[0, 1].set_xlabel("Epoch")
    axes[0, 1].set_ylabel("Accuracy")
    axes[0, 1].legend()
    axes[0, 1].grid(True, alpha=0.3)

    # ── Top-5 Accuracy ──
    if "top5_accuracy" in metrics:
        axes[1, 0].plot(metrics["top5_accuracy"], label="Train Top-5", linewidth=2)
        axes[1, 0].plot(metrics["val_top5_accuracy"], label="Val Top-5", linewidth=2)
        axes[1, 0].set_title("Top-5 Accuracy", fontsize=14, fontweight="bold")
        axes[1, 0].set_xlabel("Epoch")
        axes[1, 0].legend()
        axes[1, 0].grid(True, alpha=0.3)

    # ── Precision & Recall ──
    if "precision" in metrics and "recall" in metrics:
        axes[1, 1].plot(metrics["precision"], label="Train Precision", linewidth=2)
        axes[1, 1].plot(metrics["val_precision"], label="Val Precision", linewidth=2)
        axes[1, 1].plot(metrics["recall"], label="Train Recall", linewidth=2, linestyle="--")
        axes[1, 1].plot(metrics["val_recall"], label="Val Recall", linewidth=2, linestyle="--")
        axes[1, 1].set_title("Precision & Recall", fontsize=14, fontweight="bold")
        axes[1, 1].set_xlabel("Epoch")
        axes[1, 1].legend()
        axes[1, 1].grid(True, alpha=0.3)

    plt.suptitle("NutriSense — Eğitim Sonuçları", fontsize=16, fontweight="bold")
    plt.tight_layout()
    plt.savefig(str(BASE_DIR / "training_results.png"), dpi=150, bbox_inches="tight")
    plt.show()
    print("📊 Grafik kaydedildi: training_results.png")


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 7: Test Seti Değerlendirme
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🧪 Test Seti Değerlendirmesi
Eğitilen modeli hiç görmediği test verisi üzerinde değerlendirir.
Confusion matrix ve per-class accuracy raporlar.
"""

from sklearn.metrics import classification_report, confusion_matrix
import seaborn as sns

def evaluate_model(model, test_ds, class_names=None):
    """Model performansını test seti üzerinde değerlendirir."""
    print("\n🧪 Test seti değerlendirmesi...")

    # Test loss ve accuracy
    results = model.evaluate(test_ds, verbose=1)
    metrics_names = model.metrics_names

    print("\n📊 Test Sonuçları:")
    for name, value in zip(metrics_names, results):
        print(f"   {name}: {value:.4f}")

    # Tahminler
    y_pred_probs = model.predict(test_ds, verbose=1)
    y_pred = np.argmax(y_pred_probs, axis=1)

    # Gerçek etiketler
    y_true = np.concatenate([np.argmax(y, axis=1) for _, y in test_ds])

    # Classification report
    if class_names and len(class_names) > 0:
        target_names = class_names[:len(set(y_true))]
    else:
        target_names = [str(i) for i in range(len(set(y_true)))]

    print("\n📋 Sınıflandırma Raporu (ilk 20 sınıf):")
    report = classification_report(
        y_true, y_pred,
        target_names=target_names,
        output_dict=True,
    )

    # En iyi ve en kötü sınıflar
    per_class = {
        k: v for k, v in report.items()
        if k not in ("accuracy", "macro avg", "weighted avg")
    }
    sorted_classes = sorted(per_class.items(), key=lambda x: x[1]["f1-score"])

    print("\n   🔴 En düşük F1 skoru (5 sınıf):")
    for name, scores in sorted_classes[:5]:
        print(f"     {name}: F1={scores['f1-score']:.3f}, "
              f"Precision={scores['precision']:.3f}, "
              f"Recall={scores['recall']:.3f}")

    print("\n   🟢 En yüksek F1 skoru (5 sınıf):")
    for name, scores in sorted_classes[-5:]:
        print(f"     {name}: F1={scores['f1-score']:.3f}, "
              f"Precision={scores['precision']:.3f}, "
              f"Recall={scores['recall']:.3f}")

    # Confusion matrix (ilk 20 sınıf)
    n_show = min(20, len(set(y_true)))
    cm = confusion_matrix(y_true, y_pred)
    cm_subset = cm[:n_show, :n_show]

    fig, ax = plt.subplots(1, 1, figsize=(14, 12))
    sns.heatmap(
        cm_subset, annot=True, fmt="d", cmap="Blues",
        xticklabels=target_names[:n_show],
        yticklabels=target_names[:n_show],
        ax=ax,
    )
    ax.set_title("Confusion Matrix (İlk 20 Sınıf)", fontsize=14)
    ax.set_xlabel("Tahmin")
    ax.set_ylabel("Gerçek")
    plt.tight_layout()
    plt.savefig(str(BASE_DIR / "confusion_matrix.png"), dpi=150)
    plt.show()

    return results, report


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 8: Tüm Eğitim Pipeline'ını Çalıştır
# ═══════════════════════════════════════════════════════════════════════════════

"""
## ▶️ Eğitimi Başlat
İki aşamalı eğitimi sırayla çalıştırır.
"""

def run_training_pipeline():
    """Tüm eğitim pipeline'ını çalıştırır."""
    print("=" * 70)
    print("  NutriSense — Model Eğitim Pipeline'ı")
    print("=" * 70)

    # 1. Veri yükle
    train_ds, val_ds, test_ds = load_datasets()

    # 2. Aşama 1: Transfer Learning
    model, base_model, history1 = train_stage1(train_ds, val_ds, CLASS_WEIGHTS)

    # 3. Aşama 2: Fine-Tuning
    model, history2 = train_stage2(model, base_model, train_ds, val_ds, CLASS_WEIGHTS)

    # 4. Görselleştirme
    plot_training_history(history1, history2)

    # 5. Test değerlendirmesi
    results, report = evaluate_model(model, test_ds, CLASS_NAMES)

    print("\n" + "=" * 70)
    print("  ✅ Eğitim Pipeline'ı Tamamlandı!")
    print("=" * 70)

    return model

# Pipeline'ı çalıştır
# model = run_training_pipeline()
print("\n💡 Eğitimi başlatmak için: model = run_training_pipeline()")
