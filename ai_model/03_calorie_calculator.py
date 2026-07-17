# ==============================================================================
# 03_calorie_calculator.py
# NutriSense AI — Kalori Hesaplama Modülü
#
# İki yaklaşım:
#   A) Basit: Sabit porsiyon varsayımı + kalori lookup tablosu
#   B) Gelişmiş: Referans nesne ile boyut tahmini (el/tabak)
#
# Google Colab'da çalıştırılmak üzere tasarlanmıştır.
# ==============================================================================

import json
import math
import numpy as np
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import Optional, List, Dict, Tuple

# ── Sabitler ──
BASE_DIR = Path("/content/nutrisense_ai")


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 1: Kalori Lookup Tablosu — Basit Yaklaşım
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🍽️ Yaklaşım A: Sabit Porsiyon + Lookup Tablosu

En basit ve güvenilir yöntem. Her yiyecek için 100g başına kalori değeri
ve varsayılan porsiyon gramı tanımlıdır. Model yiyeceği tanıdığında:

  kalori = (100g_kcal / 100) × default_portion_g

Avantaj:   Hızlı, offline çalışır, güvenilir
Dezavantaj: Porsiyon tahmini sabit, kişiye göre değişmez
"""


@dataclass
class NutrientInfo:
    """Besin değerleri veri sınıfı."""
    calories: float          # kcal
    protein: float           # gram
    carbs: float             # gram
    fat: float               # gram
    fiber: float             # gram


@dataclass
class CalorieResult:
    """Kalori hesaplama sonucu."""
    food_name: str           # Yiyecek adı (ingilizce anahtar)
    display_name: str        # Türkçe gösterim adı
    portion_grams: float     # Porsiyon gramı
    nutrients: NutrientInfo  # Besin değerleri
    confidence: float        # Model güven skoru
    method: str              # "lookup" veya "size_estimation"

    @property
    def tts_text(self) -> str:
        """TTS ile okunacak özet metin."""
        return (
            f"{self.display_name} tanındı. "
            f"{self.portion_grams:.0f} gram, "
            f"{self.nutrients.calories:.0f} kalori. "
            f"{self.nutrients.protein:.0f} gram protein, "
            f"{self.nutrients.carbs:.0f} gram karbonhidrat, "
            f"{self.nutrients.fat:.0f} gram yağ."
        )

    def to_dict(self) -> dict:
        """JSON uyumlu sözlük."""
        result = asdict(self)
        result["tts_text"] = self.tts_text
        return result


class CalorieLookup:
    """
    Sabit porsiyon varsayımı ile kalori hesaplayan lookup tablosu.

    Kullanım:
        lookup = CalorieLookup("calorie_database.json")
        result = lookup.calculate("elma")
        print(result.tts_text)
        # → "Elma tanındı. 150 gram, 78 kalori. ..."
    """

    # Türkçe gösterim isimleri
    DISPLAY_NAMES: Dict[str, str] = {
        "iskender_kebap": "İskender Kebap",
        "adana_kebap": "Adana Kebap",
        "lahmacun": "Lahmacun",
        "pide": "Pide",
        "kofte": "Köfte",
        "imam_bayildi": "İmam Bayıldı",
        "karniyarik": "Karnıyarık",
        "manti": "Mantı",
        "yaprak_sarma": "Yaprak Sarma",
        "dolma": "Dolma",
        "tantuni": "Tantuni",
        "cig_kofte": "Çiğ Köfte",
        "etli_ekmek": "Etli Ekmek",
        "mercimek_corbasi": "Mercimek Çorbası",
        "ezogelin_corbasi": "Ezogelin Çorbası",
        "yayla_corbasi": "Yayla Çorbası",
        "tarhana_corbasi": "Tarhana Çorbası",
        "menemen": "Menemen",
        "simit": "Simit",
        "pogaca": "Poğaça",
        "borek": "Börek",
        "sucuklu_yumurta": "Sucuklu Yumurta",
        "baklava": "Baklava",
        "kunefe": "Künefe",
        "sutlac": "Sütlaç",
        "kazandibi": "Kazandibi",
        "lokma": "Lokma",
        "tulumba": "Tulumba",
        "coban_salata": "Çoban Salata",
        "cacik": "Cacık",
        "humus": "Humus",
        "kisir": "Kısır",
        "ayran": "Ayran",
        "turk_cayi": "Türk Çayı",
        "turk_kahvesi": "Türk Kahvesi",
        "elma": "Elma",
        "portakal": "Portakal",
        "muz": "Muz",
        "domates": "Domates",
        "salatalik": "Salatalık",
        "pizza": "Pizza",
        "hamburger": "Hamburger",
        "patates_kizartmasi": "Patates Kızartması",
        "pilav": "Pilav",
        "makarna": "Makarna",
        "ekmek": "Ekmek",
        "yumurta": "Yumurta",
        "tavuk_gogsu": "Tavuk Göğsü",
        "yogurt": "Yoğurt",
        "peynir": "Peynir",
    }

    def __init__(self, database_path: str = None):
        """JSON veritabanını yükler."""
        if database_path is None:
            # Varsayılan konum
            database_path = str(
                Path(__file__).parent / "calorie_database.json"
            )

        with open(database_path, "r", encoding="utf-8") as f:
            raw_data = json.load(f)

        # _meta anahtarını çıkar
        self.database: Dict[str, dict] = {
            k: v for k, v in raw_data.items() if k != "_meta"
        }

        print(f"✅ Kalori veritabanı yüklendi: {len(self.database)} yiyecek")

    def calculate(
        self,
        food_name: str,
        portion_grams: Optional[float] = None,
        confidence: float = 1.0,
    ) -> Optional[CalorieResult]:
        """
        Yiyecek adına göre kalori hesaplar.

        Args:
            food_name: Yiyecek adı (veritabanı anahtarı)
            portion_grams: Porsiyon gramı (None = varsayılan porsiyon)
            confidence: Model güven skoru

        Returns:
            CalorieResult veya None (bulunamazsa)
        """
        food_key = food_name.lower().replace(" ", "_")

        if food_key not in self.database:
            print(f"⚠️ '{food_name}' veritabanında bulunamadı")
            return None

        data = self.database[food_key]
        portion = portion_grams or data["default_portion_g"]

        # 100g değerlerini porsiyon boyutuna ölçekle
        scale = portion / 100.0
        nutrients = NutrientInfo(
            calories=data["calories_per_100g"] * scale,
            protein=data["protein_per_100g"] * scale,
            carbs=data["carbs_per_100g"] * scale,
            fat=data["fat_per_100g"] * scale,
            fiber=data["fiber_per_100g"] * scale,
        )

        display_name = self.DISPLAY_NAMES.get(food_key, food_name.title())

        return CalorieResult(
            food_name=food_key,
            display_name=display_name,
            portion_grams=portion,
            nutrients=nutrients,
            confidence=confidence,
            method="lookup",
        )

    def get_all_foods(self) -> List[str]:
        """Tüm yiyecek isimlerini döner."""
        return sorted(self.database.keys())

    def search(self, query: str) -> List[str]:
        """Arama sorgusuyla eşleşen yiyecekleri döner."""
        query = query.lower()
        return [
            name for name in self.database
            if query in name or query in self.DISPLAY_NAMES.get(name, "").lower()
        ]


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 2: Gelişmiş Porsiyon Tahmini — Referans Nesne ile Boyut Hesaplama
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 📏 Yaklaşım B: Referans Nesne ile Boyut Tahmini

Görüntüdeki referans nesnenin (el, tabak, çatal) bilinen boyutuyla
yiyeceğin yaklaşık hacmini ve ağırlığını tahmin eder.

Yöntem:
1. Görüntüde referans nesne algıla (el veya standart tabak)
2. Referans nesnesinin piksel boyutunu ölç
3. Piksel/cm oranını hesapla
4. Yiyeceğin piksel alanını ölç → gerçek alanı hesapla
5. Yoğunluk tablosuyla ağırlık tahmin et

Avantaj:   Daha doğru porsiyon tahmini, kişiye özel
Dezavantaj: Referans nesne gerekli, hesaplama karmaşıklığı fazla
"""


@dataclass
class ReferenceObject:
    """Referans nesne bilgisi."""
    name: str              # "hand", "plate", "fork"
    real_width_cm: float   # Gerçek genişlik (cm)
    real_height_cm: float  # Gerçek yükseklik (cm)


# Bilinen referans nesneler
REFERENCE_OBJECTS = {
    "hand": ReferenceObject("hand", real_width_cm=8.5, real_height_cm=19.0),
    "standard_plate": ReferenceObject("standard_plate", real_width_cm=26.0, real_height_cm=26.0),
    "dinner_plate": ReferenceObject("dinner_plate", real_width_cm=28.0, real_height_cm=28.0),
    "salad_plate": ReferenceObject("salad_plate", real_width_cm=21.0, real_height_cm=21.0),
    "fork": ReferenceObject("fork", real_width_cm=2.5, real_height_cm=20.0),
    "spoon": ReferenceObject("spoon", real_width_cm=4.0, real_height_cm=17.0),
}

# Yiyecek yoğunluk tablosu (g/cm³) — hacim → ağırlık dönüşümü
FOOD_DENSITY = {
    "default": 0.8,
    # Katı yiyecekler
    "ekmek": 0.35,
    "simit": 0.40,
    "pogaca": 0.45,
    "borek": 0.50,
    "baklava": 1.10,
    "kunefe": 0.90,
    # Et / protein
    "kofte": 1.05,
    "adana_kebap": 1.0,
    "iskender_kebap": 0.85,
    "tavuk_gogsu": 1.05,
    # Çorbalar / sıvılar
    "mercimek_corbasi": 1.02,
    "ayran": 1.03,
    # Meyve / sebze
    "elma": 0.85,
    "portakal": 0.95,
    "muz": 0.95,
    "domates": 0.95,
}


class PortionEstimator:
    """
    Referans nesne tabanlı porsiyon tahmin edici.

    Kullanım:
        estimator = PortionEstimator()

        # Referans nesne ve yiyecek bounding box'ları
        ref_bbox = (100, 50, 200, 300)    # (x, y, w, h) piksel
        food_bbox = (250, 100, 180, 160)  # (x, y, w, h) piksel

        grams = estimator.estimate_portion(
            ref_type="hand",
            ref_bbox=ref_bbox,
            food_bbox=food_bbox,
            food_name="elma",
        )
    """

    def __init__(self):
        self.references = REFERENCE_OBJECTS
        self.densities = FOOD_DENSITY

    def estimate_portion(
        self,
        ref_type: str,
        ref_bbox: Tuple[int, int, int, int],
        food_bbox: Tuple[int, int, int, int],
        food_name: str,
        food_height_cm: float = 3.0,
    ) -> float:
        """
        Referans nesneye göre yiyeceğin ağırlığını tahmin eder.

        Args:
            ref_type: Referans nesne tipi ("hand", "standard_plate" vb.)
            ref_bbox: Referans nesne bounding box'ı (x, y, width, height) piksel
            food_bbox: Yiyecek bounding box'ı (x, y, width, height) piksel
            food_name: Yiyecek adı (yoğunluk tablosu için)
            food_height_cm: Tahmini yiyecek yüksekliği (varsayılan 3 cm)

        Returns:
            Tahmini ağırlık (gram)
        """
        if ref_type not in self.references:
            print(f"⚠️ Bilinmeyen referans nesne: {ref_type}, 'hand' kullanılacak")
            ref_type = "hand"

        ref = self.references[ref_type]

        # ── Piksel/cm oranını hesapla ──
        _, _, ref_w_px, ref_h_px = ref_bbox
        px_per_cm_w = ref_w_px / ref.real_width_cm
        px_per_cm_h = ref_h_px / ref.real_height_cm
        px_per_cm = (px_per_cm_w + px_per_cm_h) / 2  # Ortalama

        # ── Yiyeceğin gerçek boyutlarını hesapla ──
        _, _, food_w_px, food_h_px = food_bbox
        food_width_cm = food_w_px / px_per_cm
        food_length_cm = food_h_px / px_per_cm

        # ── Hacim tahmini (elipsoid yaklaşımı) ──
        # V = (4/3) × π × (a/2) × (b/2) × (c/2)
        # a = genişlik, b = uzunluk, c = yükseklik
        volume_cm3 = (4 / 3) * math.pi * (
            (food_width_cm / 2) *
            (food_length_cm / 2) *
            (food_height_cm / 2)
        )

        # ── Ağırlık = hacim × yoğunluk ──
        density = self.densities.get(food_name, self.densities["default"])
        weight_grams = volume_cm3 * density

        print(f"📏 Porsiyon tahmini ({food_name}):")
        print(f"   Referans: {ref_type} ({ref.real_width_cm}×{ref.real_height_cm} cm)")
        print(f"   Piksel/cm: {px_per_cm:.1f}")
        print(f"   Yiyecek boyutu: {food_width_cm:.1f}×{food_length_cm:.1f}×{food_height_cm:.1f} cm")
        print(f"   Tahmini hacim: {volume_cm3:.1f} cm³")
        print(f"   Yoğunluk: {density} g/cm³")
        print(f"   Tahmini ağırlık: {weight_grams:.0f} gram")

        return weight_grams

    def estimate_from_plate_coverage(
        self,
        plate_type: str,
        food_coverage_ratio: float,
        food_name: str,
        food_height_cm: float = 2.5,
    ) -> float:
        """
        Tabaktaki kaplama oranına göre porsiyon tahmin eder.
        Daha basit ama çoğu durum için yeterli.

        Args:
            plate_type: Tabak tipi ("standard_plate", "dinner_plate", "salad_plate")
            food_coverage_ratio: Yiyeceğin tabağı kaplama oranı (0.0 - 1.0)
            food_name: Yiyecek adı
            food_height_cm: Tahmini yükseklik

        Returns:
            Tahmini ağırlık (gram)
        """
        plate = self.references.get(plate_type, self.references["standard_plate"])
        plate_radius_cm = plate.real_width_cm / 2

        # Tabak alanı (daire)
        plate_area_cm2 = math.pi * plate_radius_cm ** 2

        # Yiyecek alanı
        food_area_cm2 = plate_area_cm2 * food_coverage_ratio

        # Hacim = alan × yükseklik (silindir yaklaşımı)
        volume_cm3 = food_area_cm2 * food_height_cm

        # Ağırlık
        density = self.densities.get(food_name, self.densities["default"])
        weight_grams = volume_cm3 * density

        print(f"📏 Tabak bazlı tahmin ({food_name}):")
        print(f"   Tabak: {plate_type} (Ø{plate.real_width_cm} cm)")
        print(f"   Kaplama oranı: %{food_coverage_ratio * 100:.0f}")
        print(f"   Tahmini ağırlık: {weight_grams:.0f} gram")

        return weight_grams


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 3: Birleşik Kalori Hesaplayıcı
# ═══════════════════════════════════════════════════════════════════════════════

"""
## 🧮 Birleşik Kalori Hesaplayıcı
Basit lookup (A) ve boyut tahmini (B) yaklaşımlarını birleştirir.
Referans nesne varsa gelişmiş tahmin, yoksa basit lookup kullanılır.
"""


class NutriSenseCalculator:
    """
    NutriSense birleşik kalori hesaplayıcı.
    İki yaklaşımı birleştirir ve en uygun yöntemi otomatik seçer.

    Kullanım:
        calc = NutriSenseCalculator("calorie_database.json")

        # Basit hesaplama (sabit porsiyon)
        result = calc.calculate_simple("elma")

        # Gelişmiş hesaplama (referans nesne ile)
        result = calc.calculate_advanced(
            food_name="elma",
            ref_type="hand",
            ref_bbox=(100, 50, 85, 190),
            food_bbox=(250, 100, 120, 110),
        )
    """

    def __init__(self, database_path: str = None):
        self.lookup = CalorieLookup(database_path)
        self.estimator = PortionEstimator()

    def calculate_simple(
        self,
        food_name: str,
        confidence: float = 1.0,
    ) -> Optional[CalorieResult]:
        """Basit yaklaşım: sabit porsiyon + lookup."""
        return self.lookup.calculate(food_name, confidence=confidence)

    def calculate_advanced(
        self,
        food_name: str,
        ref_type: str,
        ref_bbox: Tuple[int, int, int, int],
        food_bbox: Tuple[int, int, int, int],
        confidence: float = 1.0,
        food_height_cm: float = 3.0,
    ) -> Optional[CalorieResult]:
        """Gelişmiş yaklaşım: referans nesne ile boyut tahmini."""

        # Porsiyon tahmini
        estimated_grams = self.estimator.estimate_portion(
            ref_type=ref_type,
            ref_bbox=ref_bbox,
            food_bbox=food_bbox,
            food_name=food_name,
            food_height_cm=food_height_cm,
        )

        # Tahmini porsiyon ile kalori hesapla
        result = self.lookup.calculate(
            food_name,
            portion_grams=estimated_grams,
            confidence=confidence,
        )

        if result:
            result.method = "size_estimation"

        return result

    def calculate_auto(
        self,
        food_name: str,
        confidence: float = 1.0,
        ref_type: Optional[str] = None,
        ref_bbox: Optional[Tuple[int, int, int, int]] = None,
        food_bbox: Optional[Tuple[int, int, int, int]] = None,
    ) -> Optional[CalorieResult]:
        """
        Otomatik yöntem seçimi.
        Referans nesne algılandıysa gelişmiş, değilse basit yaklaşım kullanır.
        """
        if ref_type and ref_bbox and food_bbox:
            return self.calculate_advanced(
                food_name, ref_type, ref_bbox, food_bbox, confidence
            )
        return self.calculate_simple(food_name, confidence)

    def compare_methods(
        self,
        food_name: str,
        ref_type: str = "standard_plate",
        plate_coverage: float = 0.5,
    ) -> Dict[str, CalorieResult]:
        """İki yöntemi karşılaştırır ve sonuçları döner."""
        print(f"\n{'='*60}")
        print(f"  Yöntem Karşılaştırması: {food_name}")
        print(f"{'='*60}")

        results = {}

        # Yöntem A: Sabit porsiyon
        print("\n📌 Yöntem A: Sabit Porsiyon Lookup")
        result_a = self.calculate_simple(food_name)
        if result_a:
            results["lookup"] = result_a
            print(f"   → {result_a.portion_grams:.0f}g = "
                  f"{result_a.nutrients.calories:.0f} kcal")

        # Yöntem B: Tabak bazlı tahmin
        print(f"\n📐 Yöntem B: Tabak Bazlı Tahmin "
              f"({plate_coverage*100:.0f}% kaplama)")
        estimated_g = self.estimator.estimate_from_plate_coverage(
            plate_type=ref_type,
            food_coverage_ratio=plate_coverage,
            food_name=food_name,
        )
        result_b = self.lookup.calculate(food_name, portion_grams=estimated_g)
        if result_b:
            result_b.method = "size_estimation"
            results["size_estimation"] = result_b
            print(f"   → {result_b.portion_grams:.0f}g = "
                  f"{result_b.nutrients.calories:.0f} kcal")

        # Karşılaştırma
        if len(results) == 2:
            diff = abs(
                results["lookup"].nutrients.calories -
                results["size_estimation"].nutrients.calories
            )
            print(f"\n📊 Fark: {diff:.0f} kcal "
                  f"({diff/max(results['lookup'].nutrients.calories, 1)*100:.1f}%)")

        return results


# ═══════════════════════════════════════════════════════════════════════════════
# HÜCRE 4: Demo — Her İki Yaklaşımı Test Et
# ═══════════════════════════════════════════════════════════════════════════════

"""
## ▶️ Demo: Kalori Hesaplama
Birkaç Türk yemeci ile her iki yaklaşımı test eder.
"""

def run_calorie_demo():
    """Kalori hesaplama demosunu çalıştırır."""
    print("=" * 70)
    print("  NutriSense — Kalori Hesaplama Demosu")
    print("=" * 70)

    # Veritabanı yolu (Colab veya yerel)
    db_path = str(Path(__file__).parent / "calorie_database.json")
    if not Path(db_path).exists():
        db_path = str(BASE_DIR / "calorie_database.json")

    calc = NutriSenseCalculator(db_path)

    # ── Test 1: Basit hesaplama ──
    print("\n" + "─" * 50)
    print("TEST 1: Basit Lookup")
    print("─" * 50)

    test_foods = ["elma", "lahmacun", "mercimek_corbasi", "baklava", "simit"]
    for food in test_foods:
        result = calc.calculate_simple(food)
        if result:
            print(f"  {result.display_name}: "
                  f"{result.portion_grams:.0f}g → "
                  f"{result.nutrients.calories:.0f} kcal "
                  f"(P:{result.nutrients.protein:.0f}g "
                  f"C:{result.nutrients.carbs:.0f}g "
                  f"F:{result.nutrients.fat:.0f}g)")

    # ── Test 2: Yöntem karşılaştırması ──
    print("\n" + "─" * 50)
    print("TEST 2: Yöntem Karşılaştırması")
    print("─" * 50)

    comparison_foods = [
        ("kofte", 0.4),
        ("pilav", 0.6),
        ("baklava", 0.2),
    ]
    for food, coverage in comparison_foods:
        calc.compare_methods(food, plate_coverage=coverage)

    # ── Test 3: TTS çıktısı ──
    print("\n" + "─" * 50)
    print("TEST 3: TTS Metin Çıktıları")
    print("─" * 50)

    for food in ["iskender_kebap", "ayran", "kunefe"]:
        result = calc.calculate_simple(food)
        if result:
            print(f"\n  🔊 {result.tts_text}")

    print("\n✅ Demo tamamlandı!")


# Demo'yu çalıştır
# run_calorie_demo()
print("\n💡 Demo'yu başlatmak için: run_calorie_demo()")
