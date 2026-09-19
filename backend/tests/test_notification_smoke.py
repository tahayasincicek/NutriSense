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
