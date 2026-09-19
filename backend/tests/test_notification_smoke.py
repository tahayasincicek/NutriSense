import pytest

from app.config import Settings
from scripts.send_notification_smoke import (
    CONFIRMATION,
    validate_smoke_request,
)


def _settings(**overrides) -> Settings:
    values = {
        "_env_file": None,
        "notification_mode": "production",
        "sms_provider_mode": "twilio",
        "twilio_account_sid": "AC" + "1" * 32,
        "twilio_auth_token": "t" * 40,
        "twilio_phone_number": "+15551234567",
        "smtp_host": "smtp.example.test",
        "smtp_user": "configured",
        "smtp_password": "configured",
        "smtp_from_email": "noreply@example.test",
        "smtp_start_tls": True,
    }
    values.update(overrides)
    return Settings(**values)


def test_real_smoke_requires_explicit_confirmation():
    with pytest.raises(ValueError, match="confirm"):
        validate_smoke_request(_settings(), "")


def test_real_smoke_refuses_non_production_delivery():
    with pytest.raises(ValueError, match="production"):
        validate_smoke_request(
            _settings(notification_mode="sandbox"), CONFIRMATION
        )


def test_real_smoke_accepts_complete_provider_configuration():
    validate_smoke_request(_settings(), CONFIRMATION)


def test_trial_smoke_accepts_only_allowlisted_personal_recipients():
    settings = _settings(
        notification_mode="sandbox",
        notification_sandbox_email_allowlist="owner@example.test",
        notification_sandbox_phone_allowlist="+905551112233",
    )

    validate_smoke_request(
        settings,
        CONFIRMATION,
        trial=True,
        email="owner@example.test",
        phone="+905551112233",
    )


@pytest.mark.parametrize(
    ("email", "phone", "error"),
    [
        ("other@example.test", "+905551112233", "e-postası"),
        ("owner@example.test", "+905559999999", "telefonu"),
    ],
)
def test_trial_smoke_refuses_recipient_outside_allowlists(
    email: str,
    phone: str,
    error: str,
):
    settings = _settings(
        notification_mode="sandbox",
        notification_sandbox_email_allowlist="owner@example.test",
        notification_sandbox_phone_allowlist="+905551112233",
    )

    with pytest.raises(ValueError, match=error):
        validate_smoke_request(
            settings,
            CONFIRMATION,
            trial=True,
            email=email,
            phone=phone,
        )
