from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

import pytest

from app.config import Settings
from app.models.database import (
    AuditEvent,
    ConsentRecord,
    Dietitian,
    DietitianAssignment,
    DietitianReport,
    FoodLog,
    NotificationDelivery,
    SessionLocal,
    User,
    utc_now,
)
from app.routers import food_router
from app.services.notification_service import (
    ChannelDeliveryError,
    NotificationService,
    build_safe_sms,
)


PASSWORD = "Guvenli123"
TODAY = date.today()


def _register(client, email: str) -> dict:
    response = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": PASSWORD,
        "full_name": "Sandbox Kullanıcı",
    })
    assert response.status_code == 201
    return response.json()


def _auth(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def _relationship(
    user_id: str,
    *,
    email_verified: bool = True,
    phone_verified: bool = True,
) -> Dietitian:
    db = SessionLocal()
    dietitian = Dietitian(
        email="sandbox-dietitian@nutrisense.invalid",
        phone="+15005550006",
        full_name="Sandbox Diyetisyen",
        email_verified=email_verified,
        phone_verified=phone_verified,
        is_active=True,
    )
    db.add(dietitian)
    db.flush()
    db.add(DietitianAssignment(
        user_id=user_id,
        dietitian_id=dietitian.id,
        status="approved",
        approved_at=utc_now(),
    ))
    user = db.query(User).filter(User.id == user_id).one()
    user.dietitian_id = dietitian.id
    db.commit()
    db.refresh(dietitian)
    db.expunge(dietitian)
    db.close()
    return dietitian


def _food_log(user_id: str, *, confirmed: bool = True) -> None:
    db = SessionLocal()
    db.add(FoodLog(
        user_id=user_id,
        food_name="apple",
        food_name_tr="Elma",
        canonical_food_id="food.apple",
        calories_per_100g=Decimal("52"),
        estimated_portion_g=Decimal("150"),
        portion_value=Decimal("150"),
        portion_unit="gram",
        portion_method="source_default",
        portion_is_estimate=True,
        total_calories=Decimal("78"),
        protein=Decimal("0.4"),
        carbs=Decimal("20.7"),
        fat=Decimal("0.3"),
        fiber=Decimal("3.6"),
        macro_calories=Decimal("86.7"),
        macro_calorie_delta=Decimal("8.7"),
        nutrition_reliability="verified_provider",
        confidence=0.93,
        meal_type="atistirmalik",
        recognition_source="google_vision",
        is_user_confirmed=confirmed,
        logged_at=datetime.now(timezone.utc),
        log_date=TODAY,
    ))
    db.commit()
    db.close()


def _preview(client, tokens: dict, channels=None):
    return client.post(
        "/api/v1/dietitian-reports/preview",
        headers=_auth(tokens),
        json={
            "user_id": tokens["user_id"],
            "report_type": "daily",
            "from_date": TODAY.isoformat(),
            "to_date": TODAY.isoformat(),
            "channels": channels or ["email", "sms"],
        },
    )


class ScriptedNotification:
    def __init__(self):
        self.calls: list[str] = []
        self.sms_should_fail = True

    async def send_channel(self, *, channel, destination, report_data):
        self.calls.append(channel)
        assert report_data["records"][0]["food_name_tr"] == "Elma"
        if channel == "sms" and self.sms_should_fail:
            raise ChannelDeliveryError("SMS_TEMPORARY", retryable=True)
        return {
            "provider_message_id": f"sandbox-{channel}-message-id",
            "provider_status": "accepted",
        }


def test_preview_partial_failure_duplicate_retry_history_and_kvkk_audit(
    client, monkeypatch,
):
    tokens = _register(client, "delivery-owner@example.com")
    _relationship(tokens["user_id"])
    _food_log(tokens["user_id"], confirmed=True)
    _food_log(tokens["user_id"], confirmed=False)

    preview = _preview(client, tokens)
    assert preview.status_code == 200, preview.text
    preview_body = preview.json()
    assert preview_body["record_count"] == 1
    assert preview_body["estimated_portion_count"] == 1
    assert preview_body["recipients"]["email"].endswith("@nutrisense.invalid")
    assert "sandbox-dietitian" not in preview_body["recipients"]["email"]
    assert preview_body["recipients"]["sms"].endswith("0006")

    sandbox = ScriptedNotification()
    monkeypatch.setattr(food_router, "notification_service", sandbox)
    headers = {
        **_auth(tokens),
        "Idempotency-Key": "delivery-idempotency-0001",
    }
    payload = {
        "user_id": tokens["user_id"],
        "report_type": "daily",
        "from_date": TODAY.isoformat(),
        "to_date": TODAY.isoformat(),
        "channels": ["email", "sms"],
        "consent_context_hash": preview_body["consent_context_hash"],
        "consent": True,
    }
    first = client.post("/api/v1/send-to-dietitian", headers=headers, json=payload)
    duplicate = client.post(
        "/api/v1/send-to-dietitian", headers=headers, json=payload,
    )
    assert first.status_code == 200, first.text
    assert first.json()["status"] == "partial_failed"
    assert first.json()["success"] is False
    assert duplicate.json()["duplicate"] is True
    assert duplicate.json()["report_id"] == first.json()["report_id"]
    assert sandbox.calls == ["email", "sms"]

    report_id = first.json()["report_id"]
    db = SessionLocal()
    try:
        report = db.query(DietitianReport).filter(
            DietitianReport.id == report_id,
        ).one()
        assert report.status == "partial_failed"
        assert report.record_count == 1
        assert report.payload_json["records"][0]["food_name_tr"] == "Elma"
        deliveries = {
            item.channel: item for item in db.query(NotificationDelivery).filter(
                NotificationDelivery.report_id == report_id,
            )
        }
        assert deliveries["email"].provider_message_id == "sandbox-email-message-id"
        assert deliveries["sms"].error_code == "SMS_TEMPORARY"
        deliveries["sms"].next_attempt_at = utc_now() - timedelta(seconds=1)
        consent = db.query(ConsentRecord).filter(
            ConsentRecord.context_hash == preview_body["consent_context_hash"],
        ).one()
        assert consent.record_count == 1
        assert consent.recipient_masked == preview_body["recipients"]
        assert db.query(AuditEvent).filter(
            AuditEvent.event == "dietitian_report_consent_granted",
        ).count() == 1
        db.commit()
    finally:
        db.close()

    sandbox.sms_should_fail = False
    retried = client.post(
        f"/api/v1/dietitian-reports/{report_id}/retry",
        headers=_auth(tokens),
    )
    assert retried.status_code == 200, retried.text
    assert retried.json()["status"] == "sent"
    assert sandbox.calls == ["email", "sms", "sms"]

    history = client.get("/api/v1/dietitian-reports", headers=_auth(tokens))
    assert history.status_code == 200
    assert history.json()[0]["report_id"] == report_id
    assert history.json()[0]["status"] == "sent"

    other = _register(client, "delivery-other@example.com")
    assert client.get(
        "/api/v1/dietitian-reports", headers=_auth(other),
    ).json() == []
    assert client.post(
        f"/api/v1/dietitian-reports/{report_id}/retry", headers=_auth(other),
    ).status_code == 404


def test_preview_guards_no_relationship_unverified_empty_and_idor(client):
    owner = _register(client, "preview-owner@example.com")
    other = _register(client, "preview-other@example.com")
    assert _preview(client, owner, ["email"]).status_code == 404

    _relationship(owner["user_id"], email_verified=True, phone_verified=False)
    assert _preview(client, owner, ["sms"]).status_code == 422
    assert _preview(client, owner, ["email"]).status_code == 422
    _food_log(owner["user_id"])

    idor = client.post(
        "/api/v1/dietitian-reports/preview",
        headers=_auth(other),
        json={
            "user_id": owner["user_id"],
            "report_type": "daily",
            "channels": ["email"],
        },
    )
    assert idor.status_code == 403
    assert client.post(
        "/api/v1/dietitian-reports/preview",
        json={
            "user_id": owner["user_id"],
            "report_type": "daily",
            "channels": ["email"],
        },
    ).status_code == 401


@pytest.mark.asyncio
async def test_mail_sandbox_message_has_html_plaintext_and_sms_is_minimal():
    captured = {}

    async def capture_email(message, destination):
        captured["message"] = message
        captured["destination"] = destination
        return {"provider_message_id": "mailpit-fixture-id", "provider_status": "accepted"}

    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        notification_mode="sandbox",
        notification_sandbox_email_allowlist=(
            "sandbox-dietitian@nutrisense.invalid"
        ),
        notification_sandbox_phone_allowlist="+15005550006",
        smtp_host="mailpit",
        smtp_port=1025,
        smtp_from_email="noreply@nutrisense.invalid",
        smtp_start_tls=False,
    )
    service = NotificationService(
        settings_override=settings,
        email_transport=capture_email,
    )
    payload = {
        "report_type": "daily",
        "from_date": TODAY.isoformat(),
        "to_date": TODAY.isoformat(),
        "record_count": 1,
        "total_calories": 78.0,
        "average_daily_calories": 78.0,
        "estimated_portion_count": 1,
        "source_explanations": ["google_vision"],
        "message": None,
        "disclaimer": "Bu rapor tıbbi tavsiye değildir.",
        "records": [{
            "food_name_tr": "Elma",
            "portion_grams": 150.0,
            "portion_is_estimate": True,
            "total_calories": 78.0,
            "logged_at": "2026-07-18T10:30:00+00:00",
            "recognition_source": "google_vision",
        }],
    }
    result = await service.send_channel(
        channel="email",
        destination="sandbox-dietitian@nutrisense.invalid",
        report_data=payload,
    )
    assert result["provider_message_id"] == "mailpit-fixture-id"
    message = captured["message"]
    assert message["To"] == "sandbox-dietitian@nutrisense.invalid"
    assert message.get_content_type() == "multipart/alternative"
    plain = message.get_payload()[0].get_payload(decode=True).decode("utf-8")
    html = message.get_payload()[1].get_payload(decode=True).decode("utf-8")
    assert "Elma" in plain and "tıbbi tavsiye değildir" in plain
    assert "Elma" in html and "<table>" in html and "<caption>" in html

    sms = build_safe_sms(payload)
    assert "Elma" not in sms
    assert "78" not in sms
    assert "kcal" not in sms

    with pytest.raises(ChannelDeliveryError) as error:
        await service.send_channel(
            channel="email",
            destination="real-person@example.com",
            report_data=payload,
        )
    assert error.value.code == "RECIPIENT_NOT_ALLOWLISTED"
