"""Gemini görüntü tanıma servisi sözleşme testleri."""

import pytest

from app.services.gemini_vision_service import GeminiVisionService
from app.services.google_vision_service import FoodNotFoundError, VisionAPIError


def _service() -> GeminiVisionService:
    return GeminiVisionService.__new__(GeminiVisionService)


def test_parse_response_orders_candidates_and_picks_best():
    result = _service()._parse_response(
        '{"is_food": true, "candidates": ['
        '{"food_name": "armut", "confidence": 0.31},'
        '{"food_name": "elma", "confidence": 0.88}]}'
    )
    assert result["food_name"] == "elma"
    assert result["confidence"] == 0.88
    assert result["is_food"] is True
    assert [c["food_name"] for c in result["candidates"]] == ["elma", "armut"]


def test_parse_response_drops_unknown_keys_and_duplicates():
    result = _service()._parse_response(
        '{"is_food": true, "candidates": ['
        '{"food_name": "elma", "confidence": 0.9},'
        '{"food_name": "elma", "confidence": 0.5},'
        '{"food_name": "uydurma_besin", "confidence": 0.8}]}'
    )
    assert result["candidates"] == [{"food_name": "elma", "confidence": 0.9}]


def test_parse_response_without_food_raises_not_found():
    with pytest.raises(FoodNotFoundError):
        _service()._parse_response('{"is_food": false, "candidates": []}')


def test_parse_response_with_invalid_json_raises_vision_error():
    with pytest.raises(VisionAPIError):
        _service()._parse_response("cevap json degil")


@pytest.mark.asyncio
async def test_analyze_image_unavailable_raises_vision_error():
    service = _service()
    service._available = False
    with pytest.raises(VisionAPIError):
        await service.analyze_image("Zm9v")
