"""Send one privacy-safe email and SMS through configured real providers."""

from __future__ import annotations

import argparse
import asyncio
import uuid

from app.config import Settings
from app.services.notification_service import NotificationService

CONFIRMATION = "SEND_REAL_NOTIFICATIONS"


def validate_smoke_request(settings: Settings, confirmation: str) -> None:
    if confirmation != CONFIRMATION:
        raise ValueError(
            f"Gerçek gönderim için --confirm {CONFIRMATION} gereklidir."
        )
    settings.validate_security()
    if settings.notification_mode != "production":
        raise ValueError("NOTIFICATION_MODE=production olmalıdır.")
    if settings.sms_provider_mode != "twilio":
        raise ValueError("SMS_PROVIDER_MODE=twilio olmalıdır.")
    if not (
        settings.smtp_host
        and settings.smtp_user
        and settings.smtp_password
        and settings.smtp_from_email
        and (settings.smtp_use_tls or settings.smtp_start_tls)
    ):
        raise ValueError(
            "Gerçek SMTP sunucusu, kullanıcı/parola, gönderici ve TLS "
            "yapılandırılmalıdır."
        )


async def send_smoke(email: str, phone: str, confirmation: str) -> None:
    if "@" not in email:
        raise ValueError("Geçerli bir e-posta adresi girin.")
    if not phone.startswith("+") or not phone[1:].isdigit():
        raise ValueError("Telefon E.164 biçiminde olmalıdır; ör. +905...")
    settings = Settings()
    validate_smoke_request(settings, confirmation)
    service = NotificationService(settings_override=settings)
    reference = f"SMOKE-{uuid.uuid4().hex[:12].upper()}"
    payload = {
        "schema_version": "notification-smoke-v1",
        "patient_code": "KANAL-TESTI",
        "report_reference": reference,
        "records": [],
        "record_count": 0,
    }
    email_result = await service.send_channel(
        channel="email", destination=email, report_data=payload
    )
    sms_result = await service.send_channel(
        channel="sms", destination=phone, report_data=payload
    )
    print(
        "Gerçek kanal isteği sağlayıcılar tarafından kabul edildi. "
        f"referans={reference} "
        f"email_id={email_result['provider_message_id']} "
        f"sms_id={sms_result['provider_message_id']}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--email", required=True)
    parser.add_argument("--phone", required=True, help="E.164, ör. +905...")
    parser.add_argument("--confirm", required=True)
    args = parser.parse_args()
    asyncio.run(send_smoke(args.email, args.phone, args.confirm))


if __name__ == "__main__":
    main()
