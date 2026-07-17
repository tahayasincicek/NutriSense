# ==============================================================================
# 04_model_converter.py
# NutriSense AI — Model Dönüştürme ve Mobil Optimizasyon
#
# İçerik:
#   1. Keras → TensorFlow Lite (.tflite) dönüştürme
#   2. INT8 Quantization (model boyutunu ~4x küçültür)
#   3. Float16 Quantization (alternatif — daha az kalite kaybı)
#   4. Dönüştürülen modellerin karşılaştırması
#   5. Flutter'da tflite_flutter ile kullanım örneği
#
# Google Colab'da çalıştırılmak üzere tasarlanmıştır.
# ==============================================================================

import os
import json
import time
import numpy as np
from pathlib import Path

import tensorflow as tf
print(f"TensorFlow: {tf.__version__}")

# ── Sabitler ──
BASE_DIR = Path("/content/nutrisense_ai")
MODEL_DIR = BASE_DIR / "models"
TFLITE_DIR = BASE_DIR / "tflite_models"
TFLITE_DIR.mkdir(parents=True, exist_ok=True)

IMG_SIZE = 224

# Konfigürasyon
config_path = BASE_DIR / "dataset_config.json"
if config_path.exists():
    with open(config_path, "r") as f:
        config = json.load(f)
    N_CLASSES = config["n_classes"]
    CLASS_NAMES = config["class_names"]
else:
    N_CLASSES = 200
    CLASS_NAMES = []


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 1: Eğitilmiş Modeli Yükle
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 📂 Model Yükleme
02_model_training.py ile eğitilen final modeli yüklenir.
"""

def load_trained_model():
    """Eğitilmiş Keras modelini yükler."""
    model_path = MODEL_DIR / "nutrisense_final.keras"

    if model_path.exists():
        model = tf.keras.models.load_model(str(model_path))
        print(f"✅ Model yüklendi: {model_path}")
        print(f"   Input shape: {model.input_shape}")
        print(f"   Output shape: {model.output_shape}")
        print(f"   Parametre sayısı: {model.count_params():,}")
        return model
    else:
        print(f"⚠️ Model bulunamadı: {model_path}")
        print("   02_model_training.py'yi önce çalıştırın.")
        return None


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 2: Standart TFLite Dönüştürme (Float32)
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🔄 Dönüşüm 1: Float32 TFLite
Orijinal hassasiyet — en yüksek doğruluk, en büyük dosya boyutu.
"""

def convert_to_tflite_float32(model):
    """Keras modelini Float32 TFLite'a dönüştürür."""
    print("\n🔄 Float32 TFLite dönüştürme...")

    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    # Optimizasyon: varsayılan (minimal)
    converter.optimizations = []

    tflite_model = converter.convert()

    # Kaydet
    output_path = TFLITE_DIR / "nutrisense_float32.tflite"
    with open(output_path, "wb") as f:
        f.write(tflite_model)

    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"✅ Float32 model kaydedildi: {output_path}")
    print(f"   Boyut: {size_mb:.2f} MB")

    return tflite_model, output_path


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 3: Float16 Quantization
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🔄 Dönüşüm 2: Float16 Quantization
Model boyutunu ~2x küçültür. Doğruluk kaybı minimal.
GPU desteği olan cihazlarda hızlı çalışır.
"""

def convert_to_tflite_float16(model):
    """Float16 quantized TFLite modeli oluşturur."""
    print("\n🔄 Float16 Quantization dönüştürme...")

    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    # Float16 quantization
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]

    tflite_model = converter.convert()

    output_path = TFLITE_DIR / "nutrisense_float16.tflite"
    with open(output_path, "wb") as f:
        f.write(tflite_model)

    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"✅ Float16 model kaydedildi: {output_path}")
    print(f"   Boyut: {size_mb:.2f} MB")

    return tflite_model, output_path


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 4: INT8 Full Quantization (En Küçük Model)
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🔄 Dönüşüm 3: INT8 Full Quantization
Model boyutunu ~4x küçültür. CPU'da en hızlı inference.
Representative dataset ile kalibrasyon yapılır.

**Bu proje için önerilen format** — mobil cihazlarda optimal performans.
"""

def representative_dataset_gen(num_samples=100):
    """
    INT8 quantization için kalibrasyon veri seti üreteci.
    Eğitim verisinden rastgele örnekler kullanır.
    """
    train_dir = BASE_DIR / "split" / "train"

    if train_dir.exists():
        # Gerçek veriden örnekle
        ds = tf.keras.utils.image_dataset_from_directory(
            str(train_dir),
            image_size=(IMG_SIZE, IMG_SIZE),
            batch_size=1,
            label_mode=None,
            shuffle=True,
            seed=42,
        )
        ds = ds.map(lambda x: x / 255.0)  # Normalize

        for i, image in enumerate(ds.take(num_samples)):
            yield [image.numpy().astype(np.float32)]
    else:
        # Eğitim verisi yoksa rastgele veri üret (sadece test amaçlı)
        print("⚠️ Eğitim verisi bulunamadı, rastgele kalibrasyon verisi üretiliyor.")
        for _ in range(num_samples):
            random_input = np.random.rand(1, IMG_SIZE, IMG_SIZE, 3).astype(np.float32)
            yield [random_input]


def convert_to_tflite_int8(model):
    """INT8 full quantized TFLite modeli oluşturur."""
    print("\n🔄 INT8 Full Quantization dönüştürme...")
    print("   (Kalibrasyon için veri seti okunuyor, bu biraz sürebilir)")

    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    # INT8 quantization
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    # Representative dataset — kalibrasyon için gerekli
    converter.representative_dataset = representative_dataset_gen

    # Tam INT8 (input/output dahil)
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS_INT8,
    ]

    # Input/output tip ayarı
    converter.inference_input_type = tf.uint8   # Input: 0-255 (direkt kamera verisi)
    converter.inference_output_type = tf.uint8  # Output: quantized olasılıklar

    try:
        tflite_model = converter.convert()

        output_path = TFLITE_DIR / "nutrisense_int8.tflite"
        with open(output_path, "wb") as f:
            f.write(tflite_model)

        size_mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"✅ INT8 model kaydedildi: {output_path}")
        print(f"   Boyut: {size_mb:.2f} MB")

        return tflite_model, output_path

    except Exception as e:
        print(f"⚠️ INT8 tam quantization başarısız: {e}")
        print("   Hibrit quantization deneniyor...")

        # Hibrit: ağırlıklar INT8, hesaplamalar float
        converter2 = tf.lite.TFLiteConverter.from_keras_model(model)
        converter2.optimizations = [tf.lite.Optimize.DEFAULT]
        converter2.representative_dataset = representative_dataset_gen

        tflite_model = converter2.convert()

        output_path = TFLITE_DIR / "nutrisense_int8_hybrid.tflite"
        with open(output_path, "wb") as f:
            f.write(tflite_model)

        size_mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"✅ INT8 Hibrit model kaydedildi: {output_path}")
        print(f"   Boyut: {size_mb:.2f} MB")

        return tflite_model, output_path


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 5: Model Karşılaştırması ve Benchmark
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 📊 Model Karşılaştırması
Float32, Float16 ve INT8 modellerini boyut, hız ve doğruluk açısından
karşılaştırır.
"""

def benchmark_tflite_model(model_path, num_runs=50):
    """
    TFLite modelinin inference süresini ölçer.

    Args:
        model_path: .tflite dosya yolu
        num_runs: Ölçüm tekrar sayısı

    Returns:
        Ortalama inference süresi (ms)
    """
    interpreter = tf.lite.Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    # Input hazırla
    input_shape = input_details[0]["shape"]
    input_dtype = input_details[0]["dtype"]

    if input_dtype == np.uint8:
        test_input = np.random.randint(0, 255, size=input_shape).astype(np.uint8)
    else:
        test_input = np.random.rand(*input_shape).astype(np.float32)

    # Isınma
    for _ in range(5):
        interpreter.set_tensor(input_details[0]["index"], test_input)
        interpreter.invoke()

    # Ölçüm
    times = []
    for _ in range(num_runs):
        start = time.perf_counter()
        interpreter.set_tensor(input_details[0]["index"], test_input)
        interpreter.invoke()
        end = time.perf_counter()
        times.append((end - start) * 1000)  # ms

    avg_time = np.mean(times)
    std_time = np.std(times)

    return avg_time, std_time


def compare_models():
    """Tüm TFLite modelleri karşılaştırır."""
    print("\n" + "=" * 70)
    print("  📊 Model Karşılaştırması")
    print("=" * 70)

    results = []

    for model_file in sorted(TFLITE_DIR.glob("*.tflite")):
        size_mb = os.path.getsize(model_file) / (1024 * 1024)
        avg_ms, std_ms = benchmark_tflite_model(model_file)

        results.append({
            "name": model_file.stem,
            "size_mb": size_mb,
            "avg_ms": avg_ms,
            "std_ms": std_ms,
        })

        print(f"\n  📦 {model_file.name}")
        print(f"     Boyut:        {size_mb:.2f} MB")
        print(f"     Inference:    {avg_ms:.2f} ± {std_ms:.2f} ms")

    if len(results) >= 2:
        # En büyük ve en küçük karşılaştır
        largest = max(results, key=lambda x: x["size_mb"])
        smallest = min(results, key=lambda x: x["size_mb"])
        compression = largest["size_mb"] / max(smallest["size_mb"], 0.01)

        print(f"\n  🏆 En küçük model: {smallest['name']} ({smallest['size_mb']:.2f} MB)")
        print(f"     Sıkıştırma oranı: {compression:.1f}x")
        print(f"     Hız farkı: "
              f"{largest['avg_ms']:.1f}ms → {smallest['avg_ms']:.1f}ms")

    return results


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 6: Model Meta Verisi — Sınıf İsimleri ve Label Dosyası
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🏷️ Label Dosyası ve Meta Veri
Flutter uygulamasında sınıf isimlerini okumak için labels.txt oluşturur.
"""

def create_labels_file():
    """Sınıf isimlerini labels.txt dosyasına yazar."""
    labels_path = TFLITE_DIR / "labels.txt"

    with open(labels_path, "w", encoding="utf-8") as f:
        for class_name in CLASS_NAMES:
            f.write(f"{class_name}\n")

    print(f"✅ Labels dosyası kaydedildi: {labels_path}")
    print(f"   {len(CLASS_NAMES)} sınıf")


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 7: Flutter Entegrasyon Kodu
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 📱 Flutter'da TFLite Kullanımı

Aşağıdaki Dart kodu, dönüştürülen .tflite modelini
Flutter uygulamasında nasıl kullanacağınızı gösterir.

### 1️⃣ pubspec.yaml'a ekleyin:
```yaml
dependencies:
  tflite_flutter: ^0.10.0
  tflite_flutter_helper: ^0.4.0

flutter:
  assets:
    - assets/models/nutrisense_int8.tflite
    - assets/models/labels.txt
```

### 2️⃣ Dart Kodu:
"""

FLUTTER_INTEGRATION_CODE = '''
// =============================================================================
// lib/shared/services/food_classifier_service.dart
// NutriSense — TFLite Besin Sınıflandırma Servisi
// =============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// TFLite yiyecek sınıflandırma servisi
class FoodClassifierService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  int get classCount => _labels.length;

  // Model dosya yolları
  static const _modelPath = 'assets/models/nutrisense_int8.tflite';
  static const _labelsPath = 'assets/models/labels.txt';

  /// Modeli ve label dosyasını yükler.
  /// Uygulama başlangıcında bir kez çağrılmalı.
  Future<void> initialize() async {
    try {
      // ── TFLite Interpreter ──
      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: InterpreterOptions()
          ..threads = 4        // Multi-thread (hızlı inference)
          ..useNnApiForAndroid = true  // Android NNAPI hızlandırma
      );

      // ── Label dosyası ──
      final labelsData = await rootBundle.loadString(_labelsPath);
      _labels = labelsData.trim().split('\\n');

      _isInitialized = true;
      print('✅ FoodClassifier başlatıldı: ${_labels.length} sınıf');
    } catch (e) {
      print('❌ FoodClassifier başlatma hatası: $e');
      _isInitialized = false;
    }
  }

  /// Görüntüyü sınıflandırır.
  ///
  /// [imageBytes] — Kameradan gelen JPEG/PNG byte verisi
  ///
  /// Returns: (sınıf_adı, güven_skoru) listesi (en yüksekten düşüğe)
  Future<List<ClassificationResult>> classify(Uint8List imageBytes) async {
    if (!_isInitialized || _interpreter == null) {
      throw StateError('FoodClassifier henüz başlatılmadı!');
    }

    // ── Görüntü ön işleme ──
    final image = img.decodeImage(imageBytes);
    if (image == null) throw ArgumentError('Görüntü çözümlenemedi');

    // 224x224'e resize
    final resized = img.copyResize(image, width: 224, height: 224);

    // INT8 model için: uint8 input (0-255)
    final inputBuffer = Uint8List(1 * 224 * 224 * 3);
    int index = 0;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resized.getPixel(x, y);
        inputBuffer[index++] = pixel.r.toInt();
        inputBuffer[index++] = pixel.g.toInt();
        inputBuffer[index++] = pixel.b.toInt();
      }
    }

    // Input tensor'ü şekillendir: [1, 224, 224, 3]
    final input = inputBuffer.reshape([1, 224, 224, 3]);

    // ── Inference (çıkarım) ──
    // Output: [1, N_CLASSES] uint8 (quantized olasılıklar)
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final output = List.filled(outputShape[1], 0).reshape([1, outputShape[1]]);

    _interpreter!.run(input, output);

    // ── Sonuçları parse et ──
    final probabilities = output[0] as List;
    final results = <ClassificationResult>[];

    for (int i = 0; i < probabilities.length && i < _labels.length; i++) {
      // uint8 output → float olasılık dönüşümü
      final prob = probabilities[i] is int
          ? (probabilities[i] as int) / 255.0
          : (probabilities[i] as double);

      if (prob > 0.01) {  // %1'den düşük olasılıkları filtrele
        results.add(ClassificationResult(
          className: _labels[i],
          confidence: prob,
          index: i,
        ));
      }
    }

    // Güven skoruna göre sırala (en yüksek önce)
    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    return results.take(5).toList();  // İlk 5 sonuç
  }

  /// Kaynakları serbest bırakır.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

/// Sınıflandırma sonucu
class ClassificationResult {
  final String className;     // Sınıf adı (ör: "elma")
  final double confidence;    // Güven skoru (0.0 - 1.0)
  final int index;            // Sınıf indeksi

  const ClassificationResult({
    required this.className,
    required this.confidence,
    required this.index,
  });

  /// Türkçe gösterim adı (snake_case → Türkçe)
  String get displayName {
    return className
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : '')
        .join(' ');
  }

  @override
  String toString() =>
      '$displayName: %${(confidence * 100).toStringAsFixed(1)}';
}
'''.strip()


def save_flutter_integration():
    """Flutter entegrasyon kodunu dosyaya kaydeder."""
    dart_path = BASE_DIR / "flutter_integration" / "food_classifier_service.dart"
    dart_path.parent.mkdir(parents=True, exist_ok=True)

    with open(dart_path, "w", encoding="utf-8") as f:
        f.write(FLUTTER_INTEGRATION_CODE)

    print(f"✅ Flutter kodu kaydedildi: {dart_path}")
    print("   Bu dosyayı lib/shared/services/ altına kopyalayın.")


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 8: Tüm Dönüştürme Pipeline'ını Çalıştır
# ═══════════════════════════════════════════════════════════════════════════════

"""
## ▶️ Model Dönüştürme Pipeline'ı
Keras modelini 3 farklı TFLite formatına dönüştürür ve karşılaştırır.
"""

def run_conversion_pipeline():
    """Tüm model dönüştürme adımlarını sırayla çalıştırır."""
    print("=" * 70)
    print("  NutriSense — Model Dönüştürme Pipeline'ı")
    print("=" * 70)

    # 1. Modeli yükle
    model = load_trained_model()
    if model is None:
        print("\n⚠️ Model bulunamadı! Önce 02_model_training.py'yi çalıştırın.")
        print("   Alternatif: Demo modu için basit bir model oluşturuluyor...")
        model = _create_demo_model()

    # 2. Float32 dönüştürme
    convert_to_tflite_float32(model)

    # 3. Float16 dönüştürme
    convert_to_tflite_float16(model)

    # 4. INT8 dönüştürme
    convert_to_tflite_int8(model)

    # 5. Labels dosyası
    create_labels_file()

    # 6. Karşılaştırma
    compare_models()

    # 7. Flutter entegrasyon kodu
    save_flutter_integration()

    print("\n" + "=" * 70)
    print("  ✅ Model Dönüştürme Tamamlandı!")
    print("=" * 70)
    print(f"\n📁 TFLite modeller: {TFLITE_DIR}")
    print("📱 Flutter'a kopyalayın:")
    print("   nutrisense_int8.tflite → assets/models/")
    print("   labels.txt → assets/models/")
    print("   food_classifier_service.dart → lib/shared/services/")


def _create_demo_model():
    """Test amaçlı basit bir model oluşturur."""
    print("\n🔧 Demo model oluşturuluyor...")
    base = tf.keras.applications.MobileNetV3Large(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )
    base.trainable = False

    model = tf.keras.Sequential([
        tf.keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3)),
        base,
        tf.keras.layers.GlobalAveragePooling2D(),
        tf.keras.layers.Dense(256, activation="relu"),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(N_CLASSES, activation="softmax"),
    ])

    model.compile(optimizer="adam", loss="categorical_crossentropy")
    print(f"✅ Demo model oluşturuldu: {model.count_params():,} parametre")
    return model


# Pipeline'ı çalıştır
# run_conversion_pipeline()
print("\n💡 Dönüştürmeyi başlatmak için: run_conversion_pipeline()")
