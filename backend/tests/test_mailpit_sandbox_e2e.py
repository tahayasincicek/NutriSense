"""Opt-in SMTP integration proof against a local Mailpit instance only."""

import json
import os
from urllib.request import urlopen

import pytest

from app.config import Settings
from app.services.notification_service import NotificationService


pytestmark = pytest.mark.skipif(
    os.getenv("MAILPIT_E2E") != "1",
    reason="Set MAILPIT_E2E=1 only while the documented local Mailpit is running.",
)


@pytest.mark.asyncio
async def test_local_mailpit_receives_plain_text_and_html() -> None:
    """Send only synthetic data to an RFC-reserved invalid recipient."""
    settings = Settings(
        notification_mode="sandbox",
        notification_sandbox_email_allowlist="dietitian@example.invalid",
        smtp_host="127.0.0.1",
        smtp_port=1025,
        smtp_use_tls=False,
        smtp_start_tls=False,
        smtp_user="",
        smtp_password="",
        smtp_from_email="noreply@example.invalid",
    )
    report = {
        "report_type": "daily",
        "from_date": "2026-07-18",
        "to_date": "2026-07-18",
        "record_count": 1,
        "total_calories": 78.0,
        "average_daily_calories": 78.0,
        "estimated_portion_count": 1,
        "source_explanations": ["fixture"],
        "message": "Sentetik test",
        "disclaimer": "Bu bilgi tıbbi tavsiye değildir.",
        "records": [
            {
                "food_name_tr": "Sentetik Elma",
                "portion_grams": 150.0,
                "portion_is_estimate": True,
                "total_calories": 78.0,
                "logged_at": "2026-07-18T09:00:00+03:00",
                "recognition_source": "fixture",
            }
        ],
    }

    result = await NotificationService(settings_override=settings).send_channel(
        channel="email",
        destination="dietitian@example.invalid",
        report_data=report,
    )
    assert result["provider_status"] == "accepted"
    assert result["provider_message_id"]

    with urlopen("http://127.0.0.1:8025/api/v1/messages", timeout=5) as response:
        messages = json.load(response)
    assert messages["total"] == 1

    message_id = messages["messages"][0]["ID"]
    with urlopen(
        f"http://127.0.0.1:8025/api/v1/message/{message_id}", timeout=5,
    ) as response:
        detail = json.load(response)
    assert detail["Text"]
    assert detail["HTML"]
    assert "tıbbi tavsiye değildir" in detail["Text"]
    assert "<table>" in detail["HTML"]
    assert not detail["Attachments"]
