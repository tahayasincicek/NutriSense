import re

from app.models.database import (
    AuditEvent, PendingEmailChange, RateLimitBucket, SessionLocal, User,
)
from app.routers import food_router
from auth_helpers import register_user


PASSWORD = "Guvenli123"


def _register(client, email: str):
    response = register_user(client, {
        "email": email,
        "password": PASSWORD,
        "full_name": "E-posta Testi",
    })
    assert response.status_code == 201, response.text
    return response.json()


def _headers(auth: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {auth['access_token']}"}


def _request_change(client, auth: dict, new_email: str, password: str = PASSWORD):
    sent = []
    service = food_router.notification_service
    had_override = "send_email_message" in vars(service)
    original = vars(service).get("send_email_message")

    async def capture(message, destination):
        sent.append((message, destination))
        return {"provider_message_id": "email-change", "provider_status": "captured"}

    service.send_email_message = capture
    try:
        response = client.post(
            "/api/v1/users/me/email-change",
            headers=_headers(auth),
            json={"new_email": new_email, "password": password},
        )
    finally:
        if had_override:
            service.send_email_message = original
        else:
            del service.send_email_message
    return response, sent


def _code(message) -> str:
    body = _body(message)
    return re.search(r"Doğrulama kodunuz: (\d{8})", body).group(1)


def _body(message) -> str:
    return message.get_payload()[0].get_payload(decode=True).decode("utf-8")


def test_email_change_requires_password_and_verified_new_address(client):
    auth = _register(client, "old@example.com")
    denied, sent = _request_change(
        client, auth, "new@example.com", password="Yanlis123",
    )
    assert denied.status_code == 401
    assert sent == []

    requested, sent = _request_change(client, auth, "new@example.com")
    assert requested.status_code == 202
    assert sent[0][1] == "new@example.com"
    code = _code(sent[0][0])

    changed = client.post(
        "/api/v1/users/me/email-change/confirm",
        headers=_headers(auth),
        json={"code": code},
    )
    assert changed.status_code == 200, changed.text
    replacement = changed.json()

    old_login = client.post(
        "/api/v1/auth/login",
        json={"email": "old@example.com", "password": PASSWORD},
    )
    new_login = client.post(
        "/api/v1/auth/login",
        json={"email": "new@example.com", "password": PASSWORD},
    )
    assert old_login.status_code == 401
    assert new_login.status_code == 200

    stale_refresh = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": auth["refresh_token"]},
    )
    fresh_refresh = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": replacement["refresh_token"]},
    )
    assert stale_refresh.status_code == 401
    assert fresh_refresh.status_code == 200

    db = SessionLocal()
    try:
        assert db.query(PendingEmailChange).count() == 0
        assert db.query(User).filter(User.email == "new@example.com").count() == 1
        event = db.query(AuditEvent).filter(AuditEvent.event == "email_changed").one()
        assert event.email_hash and "new@example.com" not in event.email_hash
    finally:
        db.close()


def test_email_change_does_not_reveal_that_target_is_registered(client):
    first = _register(client, "first@example.com")
    _register(client, "occupied@example.com")

    occupied, occupied_mail = _request_change(client, first, "occupied@example.com")
    available, available_mail = _request_change(client, first, "available@example.com")
    assert occupied.status_code == available.status_code == 202
    assert occupied.json() == available.json()
    assert occupied_mail[0][1] == "occupied@example.com"
    assert available_mail[0][1] == "available@example.com"
    assert "Doğrulama kodunuz" not in _body(occupied_mail[0][0])
    assert "Doğrulama kodunuz" in _body(available_mail[0][0])


def test_login_limit_is_shared_in_database_and_stores_no_raw_identity(client):
    for _ in range(5):
        response = client.post(
            "/api/v1/auth/login",
            json={"email": "rate@example.com", "password": "Yanlis123"},
        )
        assert response.status_code == 401
    limited = client.post(
        "/api/v1/auth/login",
        json={"email": "rate@example.com", "password": "Yanlis123"},
    )
    assert limited.status_code == 429

    db = SessionLocal()
    try:
        bucket = db.query(RateLimitBucket).filter_by(action="login").one()
        assert bucket.request_count == 5
        assert "rate@example.com" not in bucket.key_hash
        assert len(bucket.key_hash) == 64
    finally:
        db.close()
