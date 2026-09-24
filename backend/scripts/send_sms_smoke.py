"""Send one privacy-safe SMS through the configured real provider."""

from __future__ import annotations

import argparse
import asyncio
import uuid

from app.config import Settings
from app.domain.report_messages import REPORT_SCHEMA_VERSION
from app.services.notification_service import NotificationService


CONFIRMATION = "SEND_REAL_SMS"


def validate_request(
    settings: Settings,
    confirmation: str,
    phone: str,
    *,
    trial: bool,
) -> None:
    if confirmation != CONFIRMATION:
        raise ValueError(f"Gerçek SMS için --confirm {CONFIRMATION} gereklidir.")
    if not phone.startswith("+") or not phone[1:].isdigit():
        raise ValueError("Telefon E.164 biçiminde olmalıdır; ör. +905...")
    settings.validate_security()
    expected_mode = "sandbox" if trial else "production"
    if settings.notification_mode != expected_mode:
        raise ValueError(f"NOTIFICATION_MODE={expected_mode} olmalıdır.")
    if settings.sms_provider_mode not in {"twilio", "iletimerkezi"}:
        raise ValueError("SMS_PROVIDER_MODE twilio veya iletimerkezi olmalıdır.")
    if trial and phone not in settings.sandbox_phone_allowlist:
        raise ValueError(
            "Deneme telefonu NOTIFICATION_SANDBOX_PHONE_ALLOWLIST içinde olmalıdır."
        )


async def send(phone: str, confirmation: str, *, trial: bool) -> None:
    settings = Settings()
    validate_request(settings, confirmation, phone, trial=trial)
    service = NotificationService(settings_override=settings)
    reference = f"SMS-SMOKE-{uuid.uuid4().hex[:12].upper()}"
    payload = {
        "schema_version": REPORT_SCHEMA_VERSION,
        "patient_code": "KANAL-TESTI",
        "report_reference": reference,
        "records": [],
        "record_count": 0,
    }
    result = await service.send_channel(
        channel="sms", destination=phone, report_data=payload
    )
    print(
        "Gerçek SMS isteği sağlayıcı tarafından kabul edildi. "
        f"referans={reference} "
        f"sms_id={result['provider_message_id']} "
        f"durum={result['provider_status']}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--phone", required=True, help="E.164, ör. +905...")
    parser.add_argument("--confirm", required=True)
    parser.add_argument(
        "--trial",
        action="store_true",
        help="Yalnız sandbox izin listesindeki doğrulanmış telefona gönder.",
    )
    args = parser.parse_args()
    asyncio.run(send(args.phone, args.confirm, trial=args.trial))


if __name__ == "__main__":
    main()
