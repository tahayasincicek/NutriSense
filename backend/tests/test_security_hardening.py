"""Regression tests for production safety and privacy-preserving boundaries."""

from __future__ import annotations

import importlib.util
import logging
import sys
import uuid
from pathlib import Path

import pytest
import jwt
from fastapi import HTTPException

from app.config import Settings
from app.middleware.auth import create_access_token, decode_token, settings as auth_settings
from app.models.database import AuthAuditLog, SessionLocal
from app.security.logging import SensitiveDataFilter, redact_text


def _valid_production_settings(**overrides) -> Settings:
    values = {
        "_env_file": None,
        "app_environment": "prod",
        "debug": False,
        "public_base_url": "https://api.nutrisense.example",
        "api_docs_enabled": False,
        "database_url": (
            "mysql+pymysql://app:"
            + ("d" * 40)
            + "@db/nutrisense?charset=utf8mb4"
        ),
        "jwt_secret_key": "j" * 40,
        "secret_key": "a" * 40,
        "research_export_token": "r" * 40,
        "trusted_hosts": "api.nutrisense.example",
        "cors_origins": "https://app.nutrisense.example",
        "cors_allow_credentials": False,
        "research_mode": "disabled",
        "notification_mode": "disabled",
    }
    values.update(overrides)
    return Settings(**values)


def test_production_requires_https_closed_docs_and_explicit_allowlists():
    _valid_production_settings().validate_security()

    with pytest.raises(RuntimeError, match="HTTPS"):
        _valid_production_settings(
            public_base_url="http://api.nutrisense.example",
        ).validate_security()
    with pytest.raises(RuntimeError, match="dokümantasyonu"):
        _valid_production_settings(api_docs_enabled=True).validate_security()
    with pytest.raises(RuntimeError, match="TRUSTED_HOSTS"):
        _valid_production_settings(trusted_hosts="*").validate_security()
    with pytest.raises(RuntimeError, match="CORS"):
        _valid_production_settings(cors_origins="*").validate_security()


def test_jwt_has_bound_issuer_audience_time_type_and_unique_identifier():
    subject = str(uuid.uuid4())
    token = create_access_token(subject)
    claims = jwt.decode(token, options={"verify_signature": False})

    assert claims["sub"] == subject
    assert claims["iss"] == auth_settings.jwt_issuer
    assert claims["aud"] == auth_settings.jwt_audience
    assert claims["type"] == "access"
    assert claims["iat"] <= claims["exp"]
    uuid.UUID(claims["jti"])
    assert decode_token(token)["sub"] == subject

    wrong_audience = {**claims, "aud": "another-client"}
    rejected = jwt.encode(
        wrong_audience,
        auth_settings.jwt_secret_key,
        algorithm=auth_settings.jwt_algorithm,
    )
    with pytest.raises(HTTPException) as exc_info:
        decode_token(rejected)
    assert exc_info.value.status_code == 401


def test_security_headers_host_allowlist_and_request_id_sanitization(client):
    response = client.get(
        "/health/live",
        headers={"X-Request-ID": "invalid request id with spaces"},
    )
    assert response.status_code == 200
    uuid.UUID(response.headers["x-request-id"])
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"
    assert response.headers["referrer-policy"] == "no-referrer"
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["permissions-policy"] == "camera=(), microphone=(), geolocation=()"

    rejected_host = client.get("/health/live", headers={"Host": "untrusted.invalid"})
    assert rejected_host.status_code == 400


def test_log_redaction_removes_contact_token_password_and_image_payload():
    synthetic = (
        "email=person@example.invalid phone=+905551112233 "
        "password=not-a-real-password Bearer abc.def.ghi "
        "data:image/jpeg;base64," + ("A" * 160)
    )
    redacted = redact_text(synthetic)
    for forbidden in (
        "person@example.invalid",
        "+905551112233",
        "not-a-real-password",
        "abc.def.ghi",
        "A" * 80,
    ):
        assert forbidden not in redacted

    record = logging.LogRecord(
        "security-test",
        logging.ERROR,
        __file__,
        1,
        "request failed for %s",
        ("person@example.invalid",),
        None,
    )
    assert SensitiveDataFilter().filter(record)
    assert "person@example.invalid" not in record.getMessage()


def test_secret_scanner_distinguishes_placeholder_from_literal_secret():
    scanner_path = Path(__file__).resolve().parents[2] / "scripts" / "security" / "secret_scan.py"
    spec = importlib.util.spec_from_file_location("nutrisense_secret_scan", scanner_path)
    assert spec and spec.loader
    scanner = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = scanner
    spec.loader.exec_module(scanner)

    assert scanner.scan_text(
        "backend/.env.example",
        'JWT_SECRET_KEY="REPLACE_WITH_LONG_RANDOM_JWT_SECRET"',
    ) == set()
    findings = scanner.scan_text(
        "backend/app/config_override.py",
        'JWT_SECRET_KEY="abcdefghijklmnopqrstuvwxyz0123456789ABCD"',
    )
    assert "GENERIC_QUOTED_SECRET" in findings


def test_self_service_correction_and_export_are_owned_and_audited(client):
    def register(email: str) -> dict:
        response = client.post(
            "/api/v1/auth/register",
            json={
                "email": email,
                "password": "SyntheticPassword123",
                "full_name": "Sentetik Kullanıcı",
            },
        )
        assert response.status_code == 201
        return response.json()

    first = register("privacy-first@example.com")
    second = register("privacy-second@example.com")
    first_headers = {"Authorization": f"Bearer {first['access_token']}"}
    second_headers = {"Authorization": f"Bearer {second['access_token']}"}

    corrected = client.patch(
        "/api/v1/users/me",
        headers=first_headers,
        json={"full_name": "Düzeltilmiş Sentetik Kullanıcı", "tts_speed": 0.7},
    )
    assert corrected.status_code == 200
    assert corrected.json()["full_name"] == "Düzeltilmiş Sentetik Kullanıcı"

    exported = client.get("/api/v1/users/me/export", headers=first_headers)
    assert exported.status_code == 200
    body = exported.json()
    assert body["account"]["id"] == first["user_id"]
    assert body["account"]["email"] == "privacy-first@example.com"
    assert "hashed_password" not in str(body)
    assert "refresh_token" not in str(body)

    other_export = client.get("/api/v1/users/me/export", headers=second_headers)
    assert other_export.status_code == 200
    assert other_export.json()["account"]["id"] == second["user_id"]
    assert "privacy-first@example.com" not in str(other_export.json())

    with SessionLocal() as db:
        assert db.query(AuthAuditLog).filter(
            AuthAuditLog.user_id == first["user_id"],
            AuthAuditLog.event == "personal_data_exported",
        ).count() == 1
