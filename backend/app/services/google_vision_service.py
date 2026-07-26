# ==============================================================================
# backend/app/services/google_vision_service.py
# NutriSense — Google Cloud Vision API Servisi
#
# Görüntü tanıma: label detection + object localization.
# Exponential backoff ile rate limit yönetimi.
# Tanınamayan görüntüler için fallback mantığı.
# ==============================================================================

import asyncio
import base64
import logging

from google.cloud import vision
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


# ═══════════════════════════════════════════════════════════════════════════════
# BESİN ETİKETİ EŞLEME TABLOSU
# Google Vision etiketlerini besin isimlerine dönüştürür
# ═══════════════════════════════════════════════════════════════════════════════

FOOD_LABEL_MAP: dict[str, str] = {
    # Meyveler
    "apple": "elma", "banana": "muz", "orange": "portakal",
    "grape": "uzum", "strawberry": "cilek", "watermelon": "karpuz",
    "lemon": "limon", "pear": "armut", "peach": "seftali",
    # Sebzeler
    "tomato": "domates", "cucumber": "salatalik", "potato": "patates",
    "onion": "sogan", "pepper": "biber", "eggplant": "patlican",
    "carrot": "havuc", "lettuce": "marul", "broccoli": "brokoli",
    # Pişmiş yemekler
    "pizza": "pizza", "hamburger": "hamburger", "sandwich": "sandvic",
    "sushi": "sushi", "steak": "biftek", "soup": "corba",
    "salad": "salata", "pasta": "makarna", "rice": "pilav",
    "bread": "ekmek", "cake": "pasta", "cookie": "kurabiye",
    "french fries": "patates_kizartmasi", "fried chicken": "tavuk",
    "ice cream": "dondurma", "chocolate": "cikolata",
    # Türk yemekleri (Vision bazen bunları tanır)
    "kebab": "kebap", "baklava": "baklava", "pita": "pide",
    "flatbread": "lahmacun", "meatball": "kofte",
    "dumpling": "manti", "yogurt": "yogurt", "cheese": "peynir",
    "egg": "yumurta", "omelette": "menemen",
    # İçecekler
    "tea": "turk_cayi", "coffee": "turk_kahvesi",
    # Genel kategoriler
    "food": None, "dish": None, "meal": None, "cuisine": None,
    "ingredient": None, "produce": None, "fruit": None,
    "vegetable": None, "baked goods": None, "snack": None,
}

# Besin olma ihtimali yüksek genel etiketler
FOOD_RELATED_LABELS = {
    "food", "dish", "meal", "cuisine", "ingredient", "produce",
    "fruit", "vegetable", "baked goods", "snack", "dessert",
    "breakfast", "lunch", "dinner", "recipe", "plate",
    "tableware", "fast food", "comfort food",
}


class GoogleVisionService:
    """
    Google Cloud Vision API ile besin tanıma servisi.

    Özellikler:
    - Label detection (etiket tanıma)
    - Object localization (nesne konumu)
    - Exponential backoff (rate limit yönetimi)
    - Besin etiketi eşleme (İngilizce → Türkçe)
    - Fallback mantığı (tanınamayan görüntüler)
    """

    def __init__(self):
        """Vision API istemcisini başlatır."""
        try:
            self.client = vision.ImageAnnotatorClient()
            self._available = True
            logger.info("Google Vision API bağlantısı başarılı")
        except Exception as exc:
            logger.warning(
                "Google Vision API başlatılamadı exception_type=%s",
                type(exc).__name__,
            )
            self._available = False
            self.client = None

    @property
    def is_available(self) -> bool:
        return self._available

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(Exception),
        reraise=True,
    )
    async def analyze_image(self, image_base64: str) -> dict:
        """
        Görüntüyü analiz eder ve besin bilgilerini döner.

        Args:
            image_base64: Base64 kodlanmış görüntü

        Returns:
            {
                "food_name": "elma",
                "confidence": 0.94,
                "all_labels": [...],
                "is_food": True,
                "bounding_box": {...} veya None
            }

        Raises:
            VisionAPIError: API hatası
            FoodNotFoundError: Besin tespit edilemedi
        """
        if not self._available:
            raise VisionAPIError("Google Vision API kullanılamıyor.")

        try:
            # ── Base64'ten görüntü oluştur ──
            image_bytes = base64.b64decode(image_base64)
            image = vision.Image(content=image_bytes)

            # ── Label Detection ──
            label_response, localization_response = await asyncio.to_thread(
                self._request_annotations, image
            )

            if label_response.error.message:
                raise VisionAPIError(
                    f"Vision API hatası: {label_response.error.message}"
                )

            labels = [
                {
                    "name": label.description.lower(),
                    "score": label.score,
                    "topicality": label.topicality,
                }
                for label in label_response.label_annotations
            ]

            objects = [
                {
                    "name": obj.name.lower(),
                    "score": obj.score,
                    "bounding_box": {
                        "vertices": [
                            {"x": v.x, "y": v.y}
                            for v in obj.bounding_poly.normalized_vertices
                        ]
                    },
                }
                for obj in localization_response.localized_object_annotations
            ]

            # ── Besin tespiti ve eşleme ──
            result = self._map_labels_to_food(labels, objects)
            result["all_labels"] = labels
            result["all_objects"] = objects

            return result

        except VisionAPIError:
            raise
        except Exception as exc:
            logger.error(
                "Vision API çağrısı başarısız exception_type=%s",
                type(exc).__name__,
            )
            raise VisionAPIError("Görüntü analizi sağlayıcı hatası.") from None

    def _request_annotations(self, image):
        """Blocking Google client calls run outside the FastAPI event loop."""
        timeout = settings.vision_timeout_seconds
        label_response = self.client.label_detection(
            image=image,
            max_results=15,
            timeout=timeout,
        )
        localization_response = self.client.object_localization(
            image=image,
            max_results=5,
            timeout=timeout,
        )
        return label_response, localization_response

    def _map_labels_to_food(
        self, labels: list[dict], objects: list[dict]
    ) -> dict:
        """
        Vision API etiketlerini besin ismine dönüştürür.

        Strateji:
        1. Önce object localization'dan spesifik besin ara
        2. Sonra label detection'dan en iyi eşleşmeyi bul
        3. Bulunamazsa genel besin kategorisi kontrol et
        4. Hiçbiri yoksa FoodNotFoundError fırlat
        """
        best_food = None
        best_confidence = 0.0
        bounding_box = None
        candidate_scores: dict[str, float] = {}

        # 1. Object detection'dan ara (daha spesifik)
        for obj in objects:
            mapped = FOOD_LABEL_MAP.get(obj["name"])
            if mapped:
                candidate_scores[mapped] = max(
                    candidate_scores.get(mapped, 0.0), float(obj["score"])
                )
            if mapped and obj["score"] > best_confidence:
                best_food = mapped
                best_confidence = obj["score"]
                bounding_box = obj["bounding_box"]

        # 2. Label detection'dan ara
        for label in labels:
            mapped = FOOD_LABEL_MAP.get(label["name"])
            if mapped:
                candidate_scores[mapped] = max(
                    candidate_scores.get(mapped, 0.0), float(label["score"])
                )
            if mapped and label["score"] > best_confidence:
                best_food = mapped
                best_confidence = label["score"]

        # 3. Besin olup olmadığını kontrol et
        is_food = any(
            label["name"] in FOOD_RELATED_LABELS
            for label in labels
        )

        if best_food:
            candidates = [
                {"food_name": name, "confidence": round(score, 4)}
                for name, score in sorted(
                    candidate_scores.items(), key=lambda item: item[1], reverse=True
                )[:3]
            ]
            return {
                "food_name": best_food,
                "confidence": round(best_confidence, 4),
                "is_food": True,
                "bounding_box": bounding_box,
                "candidates": candidates,
            }

        if is_food:
            # Besin tespit edildi ama spesifik olarak eşlenemedi
            # En yüksek skorlu etiketi "bilinmeyen besin" olarak döndür
            top_label = labels[0]["name"] if labels else "bilinmeyen"
            return {
                "food_name": top_label,
                "confidence": labels[0]["score"] if labels else 0.0,
                "is_food": True,
                "bounding_box": bounding_box,
                "needs_manual_mapping": True,
                "candidates": [],
            }

        # 4. Besin değil
        raise FoodNotFoundError(
            "Görüntüde yiyecek tespit edilemedi. "
            "Lütfen kamerayı yiyeceğe doğru tutun."
        )


# ═══════════════════════════════════════════════════════════════════════════════
# ÖZEL HATALAR
# ═══════════════════════════════════════════════════════════════════════════════

class VisionAPIError(Exception):
    """Google Vision API hatası."""
    pass


class FoodNotFoundError(Exception):
    """Görüntüde besin tespit edilemedi."""
    pass
