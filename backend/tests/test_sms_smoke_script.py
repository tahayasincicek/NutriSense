from types import SimpleNamespace

import pytest

from scripts.send_sms_smoke import CONFIRMATION, validate_request


def _settings(**overrides):
    values = {
        "notification_mode": "sandbox",
        "sms_provider_mode": "twilio",
        "sandbox_phone_allowlist": ["+905001112233"],
    }
    values.update(overrides)
    settings = SimpleNamespace(**values)
    settings.validate_security = lambda: None
    return settings


def test_trial_requires_allowlisted_phone():
    with pytest.raises(ValueError, match="ALLOWLIST"):
        validate_request(_settings(), CONFIRMATION, "+905009998877", trial=True)


def test_trial_accepts_configured_real_provider_and_phone():
    validate_request(_settings(), CONFIRMATION, "+905001112233", trial=True)


def test_real_sms_requires_explicit_confirmation():
    with pytest.raises(ValueError, match="SEND_REAL_SMS"):
        validate_request(_settings(), "WRONG", "+905001112233", trial=True)
