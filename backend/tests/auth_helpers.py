"""Testlerde e-posta doğrulamalı kaydı tamamlayan yardımcılar."""

import re

from app.routers import food_router


def register_user(client, payload: dict):
    """Hasta kaydını başlatır, e-postadaki kodu yakalar ve hesabı açar.

    Kod onayının yanıtını (201 ve token çifti) döndürür.
    """
    return _register_with_code(client, "/api/v1/auth/register", payload)


def register_dietitian(client, payload: dict):
    """Diyetisyen kaydını başlatır ve e-postadaki kodla hesabı açar."""
    return _register_with_code(client, "/api/v1/auth/register-dietitian", payload)


def _register_with_code(client, path: str, payload: dict):
    sent = []
    service = food_router.notification_service
    had_override = "send_email_message" in vars(service)
    original = vars(service).get("send_email_message")

    async def capture(message, destination):
        sent.append(message)
        return {"provider_message_id": "test-capture", "provider_status": "captured"}

    service.send_email_message = capture
    try:
        started = client.post(path, json=payload)
    finally:
        if had_override:
            service.send_email_message = original
        else:
            del service.send_email_message
    assert started.status_code == 202, started.text
    body = sent[-1].get_payload()[0].get_payload(decode=True).decode("utf-8")
    code = re.search(r"Doğrulama kodunuz: (\d{8})", body).group(1)
    return client.post(
        "/api/v1/auth/register/confirm",
        json={"email": payload["email"], "code": code},
    )
