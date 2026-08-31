# ==============================================================================
# backend/app/services/gemini_vision_service.py
# NutriSense — Google Gemini (Generative AI) Görüntü Tanıma Servisi
#
# Google Cloud Vision'ın etiket eşleme yaklaşımının aksine çok modlu bir model
# kullanır: görüntü doğrudan Gemini'ye verilir ve yapılandırılmış JSON döner.
# GoogleVisionService ile aynı sözleşmeyi (analyze_image çıktısı) uygular,
# böylece food_router tarafında sağlayıcı değiştirilebilir.
# ==============================================================================

import asyncio
import base64
import json
import logging

from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

from ..config import get_settings
from ..operations.metrics import runtime_metrics
from .google_vision_service import FoodNotFoundError, VisionAPIError

logger = logging.getLogger(__name__)
settings = get_settings()


# Modelin serbest metin üretmesini engellemek için izin verilen besin anahtarları.
# Değerler yerel besin veri tabanı ve FOOD_NAME_TR anahtarlarıyla hizalıdır.
SUPPORTED_FOOD_KEYS: list[str] = [
    "elma", "muz", "portakal", "uzum", "cilek", "karpuz", "limon", "armut",
    "seftali", "domates", "salatalik", "patates", "sogan", "biber", "patlican",
    "havuc", "marul", "brokoli", "pizza", "hamburger", "sandvic", "sushi",
    "biftek", "corba", "salata", "makarna", "pilav", "ekmek", "pasta",
    "kurabiye", "patates_kizartmasi", "tavuk", "dondurma", "cikolata",
    "kebap", "baklava", "pide", "lahmacun", "kofte", "manti", "yogurt",
    "peynir", "yumurta", "menemen", "simit", "borek", "ayran",
    "turk_cayi", "turk_kahvesi",
]

_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "is_food": {"type": "boolean"},
        "candidates": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "food_name": {"type": "string", "enum": SUPPORTED_FOOD_KEYS},
                    "confidence": {"type": "number"},
                },
                "required": ["food_name", "confidence"],
            },
        },
    },
    "required": ["is_food", "candidates"],
}

_PROMPT = (
    "Sen bir besin tanıma modelisin. Verilen fotoğraftaki ana yiyecek veya "
    "içeceği belirle.\n"
    "Kurallar:\n"
    "1. Yalnızca izin verilen listedeki anahtarları kullan.\n"
    "2. En olası 3 adayı, güven skoru (0.0-1.0) azalan sırada döndür.\n"
    "3. Fotoğrafta yiyecek/içecek yoksa is_food=false ve boş candidates döndür.\n"
    "4. Listede karşılığı olmayan bir yiyecek görürsen is_food=true ver ve "
    "en yakın anahtarı düşük güven skoruyla döndür.\n"
    "Sadece JSON döndür, açıklama yazma."
)


class GeminiVisionService:
    """
    Google Gemini çok modlu modeli ile besin tanıma servisi.

    GoogleVisionService ile aynı arayüz:
    - `is_available`
    - `analyze_image(image_base64) -> dict`
    - FoodNotFoundError / VisionAPIError hataları
    """

    def __init__(self):
        if settings.vision_provider_mode != "gemini":
            logger.info("Gemini sağlayıcısı yapılandırma ile kapalı")
            runtime_metrics.provider_outcome("gemini_vision", "disabled")
            self._available = False
            self.client = None
            return
        try:
            from google import genai  # noqa: PLC0415 - opsiyonel bağımlılık

            self.client = genai.Client(api_key=settings.gemini_api_key)
            self._available = True
            logger.info(
                "Gemini API bağlantısı hazır model=%s", settings.gemini_model
            )
        except Exception as exc:
            logger.warning(
                "Gemini API başlatılamadı exception_type=%s", type(exc).__name__
            )
            self._available = False
            self.client = None

    @property
    def is_available(self) -> bool:
        return self._available

    async def analyze_image(self, image_base64: str, mime_type: str = "image/jpeg") -> dict:
        """
        Görüntüyü Gemini ile analiz eder.

        Returns:
            {
                "food_name": "elma",
                "confidence": 0.94,
                "is_food": True,
                "bounding_box": None,
                "candidates": [{"food_name": ..., "confidence": ...}, ...],
            }
        """
        if not self._available:
            raise VisionAPIError("Gemini görüntü analizi kullanılamıyor.")

        try:
            image_bytes = base64.b64decode(image_base64)
        except Exception:
            raise VisionAPIError("Görüntü çözümlenemedi.") from None

        try:
            raw_text = await self._call_with_retry(image_bytes, mime_type)
        except Exception as exc:
            runtime_metrics.provider_outcome("gemini_vision", "error")
            logger.error(
                "Gemini çağrısı başarısız exception_type=%s", type(exc).__name__
            )
            raise VisionAPIError("Görüntü analizi sağlayıcı hatası.") from None

        result = self._parse_response(raw_text)
        runtime_metrics.provider_outcome("gemini_vision", "success")
        return result

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(Exception),
        reraise=True,
    )
    async def _call_with_retry(self, image_bytes: bytes, mime_type: str) -> str:
        """Geçici API hataları için exponential backoff ile yeniden dener."""
        return await asyncio.to_thread(self._request_analysis, image_bytes, mime_type)

    def _request_analysis(self, image_bytes: bytes, mime_type: str) -> str:
        """Bloklayan Gemini çağrısı FastAPI event loop dışında çalışır."""
        from google.genai import types  # noqa: PLC0415

        response = self.client.models.generate_content(
            model=settings.gemini_model,
            contents=[
                types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                _PROMPT,
            ],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=_RESPONSE_SCHEMA,
                temperature=0.0,
                http_options=types.HttpOptions(
                    timeout=int(settings.vision_timeout_seconds * 1000)
                ),
            ),
        )
        return response.text or ""

    def _parse_response(self, raw_text: str) -> dict:
        try:
            payload = json.loads(raw_text)
        except json.JSONDecodeError:
            runtime_metrics.provider_outcome("gemini_vision", "error")
            raise VisionAPIError("Gemini yanıtı çözümlenemedi.") from None

        candidates = []
        seen: set[str] = set()
        for item in payload.get("candidates") or []:
            name = item.get("food_name")
            if not name or name in seen or name not in SUPPORTED_FOOD_KEYS:
                continue
            seen.add(name)
            confidence = max(0.0, min(1.0, float(item.get("confidence", 0.0))))
            candidates.append(
                {"food_name": name, "confidence": round(confidence, 4)}
            )
            if len(candidates) == 3:
                break

        if not candidates:
            runtime_metrics.provider_outcome("gemini_vision", "not_found")
            raise FoodNotFoundError(
                "Görüntüde yiyecek tespit edilemedi. "
                "Lütfen kamerayı yiyeceğe doğru tutun."
            )

        candidates.sort(key=lambda item: item["confidence"], reverse=True)
        best = candidates[0]
        return {
            "food_name": best["food_name"],
            "confidence": best["confidence"],
            "is_food": True,
            "bounding_box": None,
            "candidates": candidates,
            "all_labels": [],
            "all_objects": [],
        }
