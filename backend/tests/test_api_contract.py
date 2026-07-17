import io
import json
from pathlib import Path
from types import SimpleNamespace

import pytest
from PIL import Image

from app.main import app
from app.middleware.auth import issue_token_pair
from app.models.database import SessionLocal, User
from app.models.schemas import ErrorResponse, FoodAnalysisResponse
from app.routers import food_router
from app.middleware.auth import get_current_user
from app.services.google_vision_service import FoodNotFoundError, VisionAPIError


FIXTURES = Path(__file__).parents[2] / "contracts" / "fixtures"


def fixture(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


def jpeg_bytes() -> bytes:
    output = io.BytesIO()
    Image.new("RGB", (8, 8), color=(200, 20, 20)).save(output, "JPEG")
    return output.getvalue()


def test_shared_success_fixtures_validate_against_pydantic():
    success = FoodAnalysisResponse.model_validate(
        fixture("food_analysis_success.json")
    )
    low = FoodAnalysisResponse.model_validate(
        fixture("food_analysis_low_confidence.json")
    )
    assert success.confidence == 0.93
    assert success.nutrients.carbs == 20.7
    assert low.needs_confirmation is True


@pytest.mark.parametrize(
    "name",
    [
        "error_unauthorized.json",
        "error_invalid_image.json",
        "error_food_not_found.json",
        "error_provider_unavailable.json",
        "error_timeout.json",
    ],
)
def test_shared_error_fixtures_validate(name):
    assert ErrorResponse.model_validate(fixture(name)).error.code


def test_openapi_uses_canonical_paths_and_multipart_only():
    schema = app.openapi()
    paths = schema["paths"]
    assert "/api/v1/analyze-food" in paths
    assert "/api/v1/food-history/{user_id}" in paths
    assert "/api/v1/send-to-dietitian" in paths
    assert "/api/v1/auth/refresh" in paths
    assert "/api/v1/survey" in paths
    assert "/api/v1/usability" in paths
    assert "/api/v1/food/recognize" not in paths

    content = paths["/api/v1/analyze-food"]["post"]["requestBody"]["content"]
    assert "multipart/form-data" in content
    assert "application/json" not in content


def test_analyze_food_requires_authorization(client):
    response = client.post(
        "/api/v1/analyze-food",
        files={"image": ("food.jpg", jpeg_bytes(), "image/jpeg")},
        data={"meal_type": "ogle"},
    )
    assert response.status_code in (401, 403)
    assert response.json()["error"]["code"] in ("UNAUTHORIZED", "FORBIDDEN")


def test_corrupt_image_has_standard_error_and_request_id(client):
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(
        id="9e4e5356-b491-4575-a9dd-c5abbc777fe9"
    )
    response = client.post(
        "/api/v1/analyze-food",
        files={"image": ("bad.jpg", b"not-an-image", "image/jpeg")},
        data={"meal_type": "ogle"},
        headers={"X-Request-ID": "contract-request-id"},
    )
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
    assert response.json()["error"]["request_id"] == "contract-request-id"
    assert response.headers["x-request-id"] == "contract-request-id"


def test_multipart_food_analysis_matches_shared_fixture_shape(client, monkeypatch):
    class SuccessfulVision:
        async def analyze_image(self, _):
            return {"food_name": "elma", "confidence": 0.93}

    class SuccessfulNutrition:
        async def get_nutrition(self, _):
            return {
                "calories_per_100g": 52.0,
                "estimated_portion_g": 150.0,
                "total_calories": 78.0,
                "nutrients": {
                    "protein": 0.4,
                    "carb": 20.7,
                    "fat": 0.3,
                    "fiber": 3.6,
                },
                "source": "nutritionix",
            }

    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(
        id="9e4e5356-b491-4575-a9dd-c5abbc777fe9"
    )
    monkeypatch.setattr(food_router, "vision_service", SuccessfulVision())
    monkeypatch.setattr(food_router, "nutrition_service", SuccessfulNutrition())

    response = client.post(
        "/api/v1/analyze-food",
        files={"image": ("food.jpg", jpeg_bytes(), "image/jpeg")},
        data={"meal_type": "atistirmalik"},
    )

    assert response.status_code == 200
    parsed = FoodAnalysisResponse.model_validate(response.json())
    assert parsed.food_name_tr == "Elma"
    assert parsed.portion_grams == 150.0
    assert parsed.nutrients.carbs == 20.7
    assert parsed.needs_confirmation is False


@pytest.mark.parametrize(
    ("exception", "status_code", "code"),
    [
        (FoodNotFoundError("not found"), 404, "NOT_FOUND"),
        (VisionAPIError("offline"), 503, "PROVIDER_UNAVAILABLE"),
    ],
)
def test_recognition_failures_have_canonical_errors(
    client, monkeypatch, exception, status_code, code
):
    class FailingVision:
        async def analyze_image(self, _):
            raise exception

    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(
        id="9e4e5356-b491-4575-a9dd-c5abbc777fe9"
    )
    monkeypatch.setattr(food_router, "vision_service", FailingVision())
    response = client.post(
        "/api/v1/analyze-food",
        files={"image": ("food.jpg", jpeg_bytes(), "image/jpeg")},
        data={"meal_type": "ogle"},
    )
    assert response.status_code == status_code
    assert response.json()["error"]["code"] == code


def test_refresh_rotates_and_rejects_replay(client):
    db = SessionLocal()
    try:
        user = User(
            id="9e4e5356-b491-4575-a9dd-c5abbc777fe9",
            email="contract@example.test",
            hashed_password="unused-in-this-test",
            full_name="Contract User",
        )
        db.add(user)
        db.commit()
        token_pair = issue_token_pair(db, user)
    finally:
        db.close()

    first = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": token_pair["refresh_token"]},
    )
    assert first.status_code == 200
    assert first.json()["refresh_token"] != token_pair["refresh_token"]
    assert first.json()["refresh_expires_in"] == 30 * 86400

    replay = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": token_pair["refresh_token"]},
    )
    assert replay.status_code == 401
    assert replay.json()["error"]["code"] == "UNAUTHORIZED"
