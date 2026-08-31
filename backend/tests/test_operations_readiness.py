"""Deployment configuration and privacy-safe operations regression tests."""

from __future__ import annotations

import hashlib

import pytest

from app import main
from app.config import Settings
from scripts.fetch_ml_artifact import fetch


def _staging_settings(**overrides) -> Settings:
    values = {
        "_env_file": None,
        "app_environment": "staging",
        "debug": False,
        "public_base_url": "https://staging.nutrisense.example",
        "api_docs_enabled": False,
        "database_url": (
            "mysql+pymysql://app:"
            + ("d" * 40)
            + "@db/nutrisense_staging?charset=utf8mb4"
        ),
        "jwt_secret_key": "j" * 40,
        "secret_key": "a" * 40,
        "research_export_token": "r" * 40,
        "trusted_hosts": "staging.nutrisense.example",
        "cors_origins": "https://staging-app.nutrisense.example",
        "research_mode": "synthetic",
        "notification_mode": "sandbox",
        "migration_startup_mode": "verify",
    }
    values.update(overrides)
    return Settings(**values)


def test_staging_rejects_real_research_and_production_notifications():
    _staging_settings().validate_security()
    with pytest.raises(RuntimeError, match="katılımcı"):
        _staging_settings(research_mode="approved").validate_security()
    with pytest.raises(RuntimeError, match="bildirim"):
        _staging_settings(notification_mode="production").validate_security()


def test_required_provider_modes_fail_closed_without_credentials():
    with pytest.raises(RuntimeError, match="Google Vision"):
        _staging_settings(vision_provider_mode="google").validate_security()
    with pytest.raises(RuntimeError, match="Nutritionix"):
        _staging_settings(
            nutrition_provider_mode="nutritionix",
        ).validate_security()


def test_public_capabilities_never_expose_credentials():
    settings = _staging_settings(
        vision_provider_mode="disabled",
        nutrition_provider_mode="disabled",
    )
    payload = settings.public_capabilities
    serialized = str(payload).lower()
    assert payload["research"]["mode"] == "synthetic"
    assert payload["vision"]["enabled"] is False
    assert "secret" not in serialized
    assert "token" not in serialized
    assert "password" not in serialized


def test_operations_metrics_are_closed_and_low_cardinality(client, monkeypatch):
    assert client.get("/operations/metrics").status_code == 404

    monkeypatch.setattr(main.settings, "metrics_enabled", True)
    monkeypatch.setattr(main.settings, "operations_token", "o" * 40)
    response = client.get(
        "/operations/metrics",
        headers={"X-Operations-Token": "o" * 40},
    )
    assert response.status_code == 200
    payload = response.json()
    assert "request_count" in payload
    assert "queue_depth" in payload
    assert "db_pool" in payload
    serialized = str(payload).lower()
    for forbidden in ("email", "phone", "food_name", "authorization"):
        assert forbidden not in serialized


def test_ml_artifact_requires_https_and_verified_checksum(tmp_path):
    destination = tmp_path / "model.tflite"
    with pytest.raises(SystemExit, match="HTTPS"):
        fetch(
            url="http://localhost/model.tflite",
            sha256=hashlib.sha256(b"fixture").hexdigest(),
            destination=destination,
            max_bytes=1024,
        )
    assert not destination.exists()
