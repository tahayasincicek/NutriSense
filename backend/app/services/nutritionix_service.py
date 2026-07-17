# ==============================================================================
# backend/app/services/nutritionix_service.py
# NutriSense — Nutritionix API Servisi
#
# 800.000+ besin kaydından kalori ve besin değeri çeker.
# Exponential backoff ile rate limit yönetimi.
# Fallback: yerel JSON veritabanı.
# ==============================================================================

import json
import logging
from pathlib import Path
from typing import Optional

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

# Yerel fallback veritabanı yolu
LOCAL_DB_PATH = Path(__file__).parent.parent.parent.parent / "ai_model" / "calorie_database.json"


class NutritionixService:
    """
    Nutritionix API ile besin değeri sorgulama servisi.

    Özellikler:
    - Natural language besin sorgulama
    - Detaylı makro besin değerleri (protein, carb, fat, fiber)
    - API başarısız olursa yerel JSON veritabanına fallback
    - Exponential backoff (rate limit koruması)
    """

    API_BASE = "https://trackapi.nutritionix.com/v2"

    def __init__(self):
        self.app_id = settings.nutritionix_app_id
        self.api_key = settings.nutritionix_api_key
        self._available = bool(self.app_id and self.api_key)
        self._local_db = self._load_local_db()

        if self._available:
            logger.info("Nutritionix API yapılandırıldı")
        else:
            logger.warning("Nutritionix API anahtarları eksik, yerel DB kullanılacak.")

    def _load_local_db(self) -> dict:
        """Yerel kalori veritabanını yükler (fallback)."""
        if LOCAL_DB_PATH.exists():
            with open(LOCAL_DB_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
            return {k: v for k, v in data.items() if k != "_meta"}
        return {}

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(httpx.HTTPError),
        reraise=True,
    )
    async def get_nutrition(
        self,
        food_name: str,
        portion_grams: Optional[float] = None,
    ) -> dict:
        """
        Besin adına göre kalori ve besin değerlerini döner.

        API başarısız olursa yerel veritabanına fallback yapar.

        Args:
            food_name: Besin adı (Türkçe veya İngilizce)
            portion_grams: Porsiyon gramı (None = varsayılan)

        Returns:
            {
                "food_name": "elma",
                "calories_per_100g": 52,
                "default_portion_g": 150,
                "total_calories": 78,
                "nutrients": {
                    "protein": 0.3,
                    "carb": 13.8,
                    "fat": 0.2,
                    "fiber": 2.4
                },
                "source": "nutritionix" | "local_db"
            }
        """
        # Önce API dene
        if self._available:
            try:
                result = await self._query_api(food_name)
                if result:
                    return self._format_result(result, portion_grams, "nutritionix")
            except Exception as e:
                logger.warning(f"Nutritionix API hatası: {e}, fallback'e geçiliyor")

        # Fallback: yerel veritabanı
        return self._query_local_db(food_name, portion_grams)

    async def _query_api(self, food_name: str) -> Optional[dict]:
        """Nutritionix API'ye natural language sorgusu gönderir."""
        headers = {
            "x-app-id": self.app_id,
            "x-app-key": self.api_key,
            "Content-Type": "application/json",
        }

        # Natural language endpoint — "150g elma" gibi sorgular
        body = {
            "query": food_name,
            "locale": "tr_TR",
        }

        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                f"{self.API_BASE}/natural/nutrients",
                headers=headers,
                json=body,
            )

            if response.status_code == 200:
                data = response.json()
                foods = data.get("foods", [])
                if foods:
                    return foods[0]

            elif response.status_code == 401:
                logger.error("Nutritionix API: Yetkisiz erişim (API key kontrolü)")
                self._available = False

            elif response.status_code == 429:
                logger.warning("Nutritionix API: Rate limit aşıldı")
                raise httpx.HTTPError("Rate limit aşıldı")

            return None

    def _format_result(
        self, api_food: dict, portion_grams: Optional[float], source: str
    ) -> dict:
        """API yanıtını standart formata dönüştürür."""
        # Nutritionix API alanları
        serving_weight = api_food.get("serving_weight_grams", 100)
        calories = api_food.get("nf_calories", 0)
        protein = api_food.get("nf_protein", 0)
        carbs = api_food.get("nf_total_carbohydrate", 0)
        fat = api_food.get("nf_total_fat", 0)
        fiber = api_food.get("nf_dietary_fiber", 0)

        # 100g başına hesapla
        scale_to_100 = 100 / max(serving_weight, 1)
        cal_per_100 = calories * scale_to_100
        prot_per_100 = protein * scale_to_100
        carb_per_100 = carbs * scale_to_100
        fat_per_100 = fat * scale_to_100
        fiber_per_100 = fiber * scale_to_100

        # Porsiyon hesabı
        portion = portion_grams or serving_weight
        scale = portion / 100

        return {
            "food_name": api_food.get("food_name", "bilinmeyen"),
            "calories_per_100g": round(cal_per_100, 1),
            "default_portion_g": round(serving_weight, 0),
            "estimated_portion_g": round(portion, 0),
            "total_calories": round(cal_per_100 * scale, 1),
            "nutrients": {
                "protein": round(prot_per_100 * scale, 1),
                "carb": round(carb_per_100 * scale, 1),
                "fat": round(fat_per_100 * scale, 1),
                "fiber": round(fiber_per_100 * scale, 1),
            },
            "source": source,
        }

    def _query_local_db(
        self, food_name: str, portion_grams: Optional[float]
    ) -> dict:
        """Yerel JSON veritabanından besin bilgisi çeker."""
        key = food_name.lower().replace(" ", "_")

        if key in self._local_db:
            data = self._local_db[key]
            portion = portion_grams or data.get("default_portion_g", 100)
            scale = portion / 100

            return {
                "food_name": key,
                "calories_per_100g": data["calories_per_100g"],
                "default_portion_g": data.get("default_portion_g", 100),
                "estimated_portion_g": round(portion, 0),
                "total_calories": round(data["calories_per_100g"] * scale, 1),
                "nutrients": {
                    "protein": round(data.get("protein_per_100g", 0) * scale, 1),
                    "carb": round(data.get("carbs_per_100g", 0) * scale, 1),
                    "fat": round(data.get("fat_per_100g", 0) * scale, 1),
                    "fiber": round(data.get("fiber_per_100g", 0) * scale, 1),
                },
                "source": "local_db",
            }

        # Bulunamazsa varsayılan
        logger.warning(f"Besin '{food_name}' ne API'de ne yerel DB'de bulunamadı")
        return {
            "food_name": food_name,
            "calories_per_100g": 0,
            "default_portion_g": 100,
            "estimated_portion_g": portion_grams or 100,
            "total_calories": 0,
            "nutrients": {"protein": 0, "carb": 0, "fat": 0, "fiber": 0},
            "source": "not_found",
        }

    async def search_foods(self, query: str, limit: int = 10) -> list[dict]:
        """Besin adı araması yapar."""
        if self._available:
            try:
                headers = {
                    "x-app-id": self.app_id,
                    "x-app-key": self.api_key,
                }
                async with httpx.AsyncClient(timeout=10.0) as client:
                    response = await client.get(
                        f"{self.API_BASE}/search/instant",
                        headers=headers,
                        params={"query": query},
                    )
                    if response.status_code == 200:
                        data = response.json()
                        common = data.get("common", [])[:limit]
                        return [
                            {
                                "food_name": f.get("food_name", ""),
                                "photo": f.get("photo", {}).get("thumb", ""),
                            }
                            for f in common
                        ]
            except Exception as e:
                logger.warning(f"Nutritionix arama hatası: {e}")

        # Yerel arama
        results = []
        query_lower = query.lower()
        for key in self._local_db:
            if query_lower in key:
                results.append({"food_name": key, "photo": ""})
                if len(results) >= limit:
                    break
        return results
