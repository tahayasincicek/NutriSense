"""Send one privacy-safe email and SMS through configured real providers."""

from __future__ import annotations

import argparse
import asyncio
import uuid

from app.config import Settings
from app.domain.report_messages import REPORT_SCHEMA_VERSION
from app.services.notification_service import NotificationService

CONFIRMATION = "SEND_REAL_NOTIFICATIONS"


def validate_smoke_request(
    settings: Settings,
    confirmation: str,
    *,
    trial: bool = False,
    email: str | None = None,
    phone: str | None = None,
) -> None:
    if confirmation != CONFIRMATION:
        raise ValueError(
            f"Gerçek gönderim için --confirm {CONFIRMATION} gereklidir."
        )
    settings.validate_security()
    expected_mode = "sandbox" if trial else "production"
    if settings.notification_mode != expected_mode:
        raise ValueError(
            f"NOTIFICATION_MODE={expected_mode} olmalıdır."
        )
    if settings.sms_provider_mode not in {"twilio", "iletimerkezi"}:
        raise ValueError(
            "SMS_PROVIDER_MODE twilio veya iletimerkezi olmalıdır."
        )
    if trial:
        if email is None or email.lower() not in settings.sandbox_email_allowlist:
            raise ValueError(
                "Deneme e-postası NOTIFICATION_SANDBOX_EMAIL_ALLOWLIST "
                "içinde olmalıdır."
            )
        if phone is None or phone not in settings.sandbox_phone_allowlist:
            raise ValueError(
                "Deneme telefonu NOTIFICATION_SANDBOX_PHONE_ALLOWLIST "
                "içinde olmalıdır."
            )
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


async def send_smoke(
    email: str,
    phone: str,
    confirmation: str,
    *,
    trial: bool = False,
) -> None:
    if "@" not in email:
        raise ValueError("Geçerli bir e-posta adresi girin.")
    if not phone.startswith("+") or not phone[1:].isdigit():
        raise ValueError("Telefon E.164 biçiminde olmalıdır; ör. +905...")
    settings = Settings()
    validate_smoke_request(
        settings,
        confirmation,
        trial=trial,
        email=email,
        phone=phone,
    )
    service = NotificationService(settings_override=settings)
    reference = f"SMOKE-{uuid.uuid4().hex[:12].upper()}"
    payload = {
        "schema_version": REPORT_SCHEMA_VERSION,
        "patient_code": "KANAL-TESTI",
        "report_reference": reference,
        "records": [{
            "food_name_tr": "Test besini",
            "portion_grams": 100,
            "logged_at": "2026-09-23T12:00:00+03:00",
            "total_calories": 100,
        }],
        "record_count": 1,
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
    parser.add_argument(
        "--trial",
        action="store_true",
        help=(
            "Sandbox izin listeleriyle yalnız doğrulanmış kişisel alıcılara "
            "deneme gönderimi yap"
        ),
    )
    args = parser.parse_args()
    asyncio.run(
        send_smoke(
            args.email,
            args.phone,
            args.confirm,
            trial=args.trial,
        )
    )


if __name__ == "__main__":
    main()
