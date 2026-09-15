"""Kayıt e-posta doğrulaması: hesap kodla açılır, kayıt ekranı hesap varlığını ele vermez."""

import re
from datetime import timedelta

from auth_helpers import register_user
from app.models.database import PendingRegistration, SessionLocal, User
from app.routers import food_router

PASSWORD = "SyntheticPassword123"


def _payload(email):
    return {"email": email, "password": PASSWORD, "full_name": "Sentetik Kullanıcı"}


def _capturing(monkeypatch):
    sent = []

    async def capture(message, destination):
        sent.append((destination, message))
        return {"provider_message_id": "test", "provider_status": "captured"}

    monkeypatch.setattr(food_router.notification_service, "send_email_message", capture)
    return sent


def _body(message):
    return message.get_payload()[0].get_payload(decode=True).decode("utf-8")


def _code(message):
    return re.search(r"Doğrulama kodunuz: (\d{8})", _body(message)).group(1)


def test_registration_does_not_open_an_account_before_the_code(client, monkeypatch):
    sent = _capturing(monkeypatch)
    response = client.post("/api/v1/auth/register", json=_payload("yeni@example.com"))
    assert response.status_code == 202
    assert "access_token" not in response.json()
    code = _code(sent[0][1])
    db = SessionLocal()
    try:
        assert db.query(User).count() == 0
        pending = db.query(PendingRegistration).one()
        assert pending.email == "yeni@example.com"
        assert code not in pending.code_hash
        assert PASSWORD not in pending.hashed_password
    finally:
        db.close()


def test_existing_email_gets_the_same_response_and_no_code(client, monkeypatch):
    assert register_user(client, _payload("kayitli@example.com")).status_code == 201
    sent = _capturing(monkeypatch)
    new = client.post("/api/v1/auth/register", json=_payload("baska@example.com"))
    existing = client.post("/api/v1/auth/register", json=_payload("kayitli@example.com"))

    assert new.status_code == existing.status_code == 202
    assert new.json() == existing.json()
    to_owner = [message for destination, message in sent if destination == "kayitli@example.com"]
    assert len(to_owner) == 1
    assert "zaten bir hesabınız var" in _body(to_owner[0])
    assert not re.search(r"\d{8}", _body(to_owner[0]))
    db = SessionLocal()
    try:
        assert db.query(PendingRegistration).filter_by(email="kayitli@example.com").count() == 0
        assert db.query(User).filter_by(email="kayitli@example.com").count() == 1
    finally:
        db.close()


def test_correct_code_opens_the_account_once(client, monkeypatch):
    sent = _capturing(monkeypatch)
    client.post("/api/v1/auth/register", json=_payload("onay@example.com"))
    code = _code(sent[-1][1])

    opened = client.post("/api/v1/auth/register/confirm",
                         json={"email": "onay@example.com", "code": code})
    assert opened.status_code == 201
    assert opened.json()["access_token"]
    again = client.post("/api/v1/auth/register/confirm",
                        json={"email": "onay@example.com", "code": code})
    assert again.status_code == 400

    db = SessionLocal()
    try:
        assert db.query(User).filter_by(email="onay@example.com").count() == 1
        assert db.query(PendingRegistration).count() == 0
    finally:
        db.close()


def test_repeated_wrong_codes_cancel_the_pending_registration(client, monkeypatch):
    sent = _capturing(monkeypatch)
    client.post("/api/v1/auth/register", json=_payload("deneme@example.com"))
    code = _code(sent[-1][1])
    wrong = "00000000" if code != "00000000" else "11111111"

    for _ in range(5):
        response = client.post("/api/v1/auth/register/confirm",
                               json={"email": "deneme@example.com", "code": wrong})
        assert response.status_code == 400
    locked = client.post("/api/v1/auth/register/confirm",
                         json={"email": "deneme@example.com", "code": code})
    assert locked.status_code == 400

    db = SessionLocal()
    try:
        assert db.query(User).count() == 0
    finally:
        db.close()


def test_expired_code_is_rejected(client, monkeypatch):
    sent = _capturing(monkeypatch)
    client.post("/api/v1/auth/register", json=_payload("sure@example.com"))
    code = _code(sent[-1][1])
    db = SessionLocal()
    try:
        pending = db.query(PendingRegistration).one()
        pending.expires_at = pending.expires_at - timedelta(hours=1)
        db.commit()
    finally:
        db.close()

    response = client.post("/api/v1/auth/register/confirm",
                           json={"email": "sure@example.com", "code": code})
    assert response.status_code == 400
