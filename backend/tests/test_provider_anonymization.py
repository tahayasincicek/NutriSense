"""Yurt dışındaki sağlayıcılara giden verinin kimliksizleştirildiğini kanıtlar."""

import base64
import io

import pytest
from PIL import Image
from starlette.datastructures import Headers, UploadFile

from app.routers import food_router
from app.services import nutritionix_service as module
from app.services.nutritionix_service import (
    PROVIDER_QUERY_MAX_LENGTH,
    NutritionixService,
    anonymized_provider_query,
)


def test_query_drops_links_emails_and_phone_numbers():
    text = (
        "mercimek çorbası ayse@example.test +90 500 000 00 01 "
        "https://example.test/tarif"
    )
    assert anonymized_provider_query(text) == "mercimek çorbası"


def test_query_is_bounded_and_empty_text_is_not_sent():
    assert len(anonymized_provider_query("elma " * 50)) <= PROVIDER_QUERY_MAX_LENGTH
    assert anonymized_provider_query("+90 500 000 00 01") is None
    assert anonymized_provider_query("<script>") == "script"


@pytest.fixture()
def hybrid_service(monkeypatch):
    monkeypatch.setattr(module, "LOCAL_DB_PATH", module._resolve_local_db_path())
    monkeypatch.setattr(module.settings, "nutrition_provider_mode", "hybrid")
    monkeypatch.setattr(module.settings, "nutritionix_app_id", "synthetic-app")
    monkeypatch.setattr(module.settings, "nutritionix_api_key", "synthetic-key")
    service = NutritionixService()
    calls = []

    async def provider(query):
        calls.append(query)
        return None

    monkeypatch.setattr(service, "_query_api", provider)
    return service, calls


@pytest.mark.asyncio
async def test_catalog_hit_never_reaches_foreign_provider(hybrid_service):
    service, calls = hybrid_service
    result = await service.get_nutrition("baklava", 50, input_locale="tr-TR")
    assert result["available"] is True
    assert calls == []


@pytest.mark.asyncio
async def test_foreign_provider_receives_only_anonymized_food_text(hybrid_service):
    service, calls = hybrid_service
    result = await service.get_nutrition(
        "kereviz sapı 0500 000 00 01 ali@example.test", None, input_locale="tr-TR"
    )
    assert result["available"] is False
    assert calls == ["kereviz sapı"]


@pytest.mark.asyncio
async def test_uploaded_photo_is_downscaled_and_stripped_before_leaving_server():
    exif = Image.Exif()
    exif[0x010F] = "SyntheticCamera"
    buffer = io.BytesIO()
    Image.new("RGB", (3000, 2000), "white").save(buffer, format="JPEG", exif=exif)
    buffer.seek(0)
    upload = UploadFile(
        file=buffer,
        filename="yemek.jpg",
        headers=Headers({"content-type": "image/jpeg"}),
    )

    encoded = await food_router._sanitized_image_base64(upload)

    with Image.open(io.BytesIO(base64.b64decode(encoded))) as image:
        assert max(image.size) <= food_router.PROVIDER_IMAGE_MAX_SIDE
        assert not image.getexif()
