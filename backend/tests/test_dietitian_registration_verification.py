"""Diyetisyen kaydı hesap varlığını ele vermez ve e-posta koduyla açılır."""

import re

from app.models.database import Dietitian, PendingRegistration, SessionLocal
from app.routers import food_router
from auth_helpers import register_user

PAYLOAD = {
    "email": "kod-diyetisyen@example.com",
    "password": "Guvenli123",
    "full_name": "Kodlu Diyetisyen",
    "specialization": "Beslenme ve Diyet",
    "data_processing_agreement_accepted": True,
    "data_processing_agreement_version": "DIETITIAN-DPA-2026-01",
}


def _capture_emails(monkeypatch) -> list:
    sent = []

    async def capture(message, destination):
        sent.append(message)
        return {"provider_message_id": "test-capture", "provider_status": "captured"}

    monkeypatch.setattr(food_router.notification_service, "send_email_message", capture)
    return sent


def _body(message) -> str:
    return message.get_payload()[0].get_payload(decode=True).decode("utf-8")


def test_dietitian_account_opens_only_after_email_code(client, monkeypatch):
    sent = _capture_emails(monkeypatch)

    started = client.post("/api/v1/auth/register-dietitian", json=PAYLOAD)
    assert started.status_code == 202, started.text
    with SessionLocal() as db:
        assert db.query(Dietitian).filter_by(email=PAYLOAD["email"]).count() == 0

    code = re.search(r"Doğrulama kodunuz: (\d{8})", _body(sent[-1])).group(1)
    confirmed = client.post(
        "/api/v1/auth/register/confirm",
        json={"email": PAYLOAD["email"], "code": code},
    )
    assert confirmed.status_code == 201, confirmed.text
    with SessionLocal() as db:
        profile = db.query(Dietitian).filter_by(email=PAYLOAD["email"]).one()
        assert profile.email_verified is True
        assert profile.data_processing_agreement_version == "DIETITIAN-DPA-2026-01"
        assert profile.data_processing_agreement_accepted_at is not None


def test_registered_address_gets_the_same_response(client, monkeypatch):
    register_user(client, {
        "email": PAYLOAD["email"],
        "password": "Guvenli123",
        "full_name": "Mevcut Hasta",
    })
    sent = _capture_emails(monkeypatch)

    existing = client.post("/api/v1/auth/register-dietitian", json=PAYLOAD)
    fresh = client.post(
        "/api/v1/auth/register-dietitian",
        json={**PAYLOAD, "email": "yeni-diyetisyen@example.com"},
    )

    assert existing.status_code == fresh.status_code == 202
    assert existing.json() == fresh.json()
    assert "Doğrulama kodunuz" not in _body(sent[0])
    with SessionLocal() as db:
        assert db.query(PendingRegistration).filter_by(email=PAYLOAD["email"]).count() == 0
        assert db.query(Dietitian).filter_by(email=PAYLOAD["email"]).count() == 0
