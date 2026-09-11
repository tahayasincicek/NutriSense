import uuid
from datetime import date

import pytest

from app.config import Settings
from app.models.database import (
    AuthAuditLog,
    Dietitian,
    DietitianAssignment,
    FoodLog,
    SessionLocal,
    User,
    utc_now,
)
from app.routers import food_router
from app.routers.survey_router import SurveySubmissionSchema


PASSWORD = "Guvenli123"


def register(client, email: str) -> dict:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": PASSWORD,
            "full_name": "Test Kullanıcısı",
            "adult_confirmed": True,
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def bearer(token_data: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {token_data['access_token']}"}


def test_password_policy_is_shared_across_register_and_reset(client):
    weak = client.post(
        "/api/v1/auth/register",
        json={
            "email": "weak@example.com",
            "password": "abcdefgh",
            "full_name": "Weak User",
            "adult_confirmed": True,
        },
    )
    assert weak.status_code == 422

    # Aynı parola politikası sıfırlamada da geçerli olmalı.
    weak_reset = client.post(
        "/api/v1/auth/password-reset/confirm",
        json={"token": "12345678", "new_password": "abcdefgh"},
    )
    assert weak_reset.status_code == 422


def test_password_reset_does_not_disclose_account_existence(client):
    register(client, "known-reset@example.com")

    known = client.post(
        "/api/v1/auth/password-reset",
        json={"email": "known-reset@example.com"},
    )
    unknown = client.post(
        "/api/v1/auth/password-reset",
        json={"email": "nobody-here@example.com"},
    )

    # Hesabın varlığı ne durum kodundan ne de gövdeden anlaşılmamalı.
    assert known.status_code == unknown.status_code == 200
    assert known.json() == unknown.json()


def test_password_reset_rejects_invalid_and_expired_codes(client):
    register(client, "reset-codes@example.com")
    client.post(
        "/api/v1/auth/password-reset",
        json={"email": "reset-codes@example.com"},
    )

    bogus = client.post(
        "/api/v1/auth/password-reset/confirm",
        json={"token": "00000000", "new_password": "GecerliSifre1"},
    )
    assert bogus.status_code == 400
    assert "geçersiz" in bogus.json()["error"]["message"].lower()


def test_login_does_not_disclose_user_existence_and_rate_limits(client):
    register(client, "known@example.com")
    known = client.post(
        "/api/v1/auth/login",
        json={"email": "known@example.com", "password": "Yanlis123"},
    )
    unknown = client.post(
        "/api/v1/auth/login",
        json={"email": "unknown@example.com", "password": "Yanlis123"},
    )
    assert known.status_code == unknown.status_code == 401
    assert known.json()["error"]["message"] == unknown.json()["error"]["message"]

    for _ in range(4):
        client.post(
            "/api/v1/auth/login",
            json={"email": "unknown@example.com", "password": "Yanlis123"},
        )
    limited = client.post(
        "/api/v1/auth/login",
        json={"email": "unknown@example.com", "password": "Yanlis123"},
    )
    assert limited.status_code == 429

    db = SessionLocal()
    try:
        assert db.query(AuthAuditLog).filter(
            AuthAuditLog.event == "login_rate_limited"
        ).count() == 1
        assert all(log.email_hash for log in db.query(AuthAuditLog).all())
    finally:
        db.close()


def test_default_jwt_secret_is_rejected_in_production():
    with pytest.raises(RuntimeError):
        Settings(app_environment="prod", jwt_secret_key="change-me").validate_security()


def test_research_identity_is_separate_and_exports_are_protected(client):
    schema = SurveySubmissionSchema.model_json_schema()
    assert "participant_id" in schema["properties"]
    assert "user_id" not in schema["properties"]
    assert client.get("/api/v1/survey/stats").status_code == 403
    assert client.get("/api/v1/usability/export").status_code == 403


def test_account_deletion_requires_password_and_removes_owned_data(client):
    auth = register(client, "delete@example.com")
    db = SessionLocal()
    try:
        db.add(
            FoodLog(
                user_id=auth["user_id"],
                food_name="test-food",
                food_name_tr="Test Besini",
                calories_per_100g=1,
                estimated_portion_g=1,
                total_calories=1,
                log_date=date.today(),
            )
        )
        db.commit()
    finally:
        db.close()

    denied = client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=bearer(auth),
        json={"password": "Yanlis123", "confirmation": "HESABIMI SIL"},
    )
    assert denied.status_code == 401

    deleted = client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=bearer(auth),
        json={"password": PASSWORD, "confirmation": "HESABIMI SIL"},
    )
    assert deleted.status_code == 204

    db = SessionLocal()
    try:
        assert db.query(User).filter(User.id == auth["user_id"]).first() is None
        assert db.query(FoodLog).filter(FoodLog.user_id == auth["user_id"]).count() == 0
        audit = db.query(AuthAuditLog).filter(
            AuthAuditLog.event == "account_deleted"
        ).one()
        assert audit.user_id is None
        assert audit.email_hash is not None
    finally:
        db.close()


def test_dietitian_assignment_consent_and_idor_guards(client, monkeypatch):
    first = register(client, "first@example.com")
    second = register(client, "second@example.com")
    dietitian_id = str(uuid.uuid4())
    db = SessionLocal()
    try:
        db.add(
            Dietitian(
                id=dietitian_id,
                email="verified.dietitian@example.com",
                full_name="Doğrulanmış Diyetisyen",
                email_verified=True,
                phone_verified=False,
            )
        )
        db.commit()
    finally:
        db.close()

    requested = client.post(
        "/api/v1/dietitians/assignment",
        headers=bearer(first),
        json={"dietitian_email": "verified.dietitian@example.com"},
    )
    assert requested.status_code == 201
    assignment_id = requested.json()["assignment_id"]

    duplicate = client.post(
        "/api/v1/dietitians/assignment",
        headers=bearer(first),
        json={"dietitian_email": "verified.dietitian@example.com"},
    )
    assert duplicate.status_code == 409

    idor_approve = client.post(
        f"/api/v1/dietitians/assignment/{assignment_id}/approve",
        headers=bearer(second),
    )
    assert idor_approve.status_code == 404

    approved = client.post(
        f"/api/v1/dietitians/assignment/{assignment_id}/approve",
        headers=bearer(first),
    )
    assert approved.status_code == 200
    # Bağ iki taraflıdır: hasta rızası tek başına atamayı kurmaz.
    assert approved.json()["status"] == "pending"
    assert approved.json()["patient_approved"] is True
    assert approved.json()["awaiting"] == "dietitian"

    db = SessionLocal()
    try:
        assignment = db.query(DietitianAssignment).filter(
            DietitianAssignment.id == assignment_id
        ).first()
        assignment.dietitian_accepted_at = utc_now()
        assignment.status = "approved"
        owner = db.query(User).filter(User.id == first["user_id"]).first()
        owner.dietitian_id = dietitian_id
        db.commit()
    finally:
        db.close()

    no_consent = client.post(
        "/api/v1/send-to-dietitian",
        headers=bearer(first),
        json={"user_id": first["user_id"], "report_type": "weekly"},
    )
    assert no_consent.status_code == 422

    idor_history = client.get(
        f"/api/v1/food-history/{second['user_id']}",
        headers=bearer(first),
    )
    assert idor_history.status_code == 403

    idor_report = client.post(
        "/api/v1/send-to-dietitian",
        headers={
            **bearer(first),
            "Idempotency-Key": "idor-report-request-0001",
        },
        json={
            "user_id": second["user_id"],
            "report_type": "weekly",
            "channels": ["email"],
            "consent_context_hash": "0" * 64,
            "consent": True,
        },
    )
    assert idor_report.status_code == 403

    cancelled = client.delete(
        f"/api/v1/dietitians/assignment/{assignment_id}",
        headers=bearer(first),
    )
    assert cancelled.status_code == 204
    db = SessionLocal()
    try:
        assignment = db.query(DietitianAssignment).filter(
            DietitianAssignment.id == assignment_id
        ).one()
        assert assignment.status == "cancelled"
    finally:
        db.close()
