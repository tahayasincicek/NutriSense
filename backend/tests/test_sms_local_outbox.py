"""SMS hattının uçtan uca çalıştığını yerel kutu üzerinden kanıtlar.

Yerel kutu gerçek operatöre çıkmaz; e-posta tarafındaki Mailpit'in
karşılığıdır. Rıza, rapor içeriği, kanal seçimi ve teslimat kaydı gerçekten
çalışır, yalnız son adımda mesaj telefona ulaşmaz.
"""

import json

import pytest

from app.config import Settings
from app.services.notification_service import (
    ChannelDeliveryError,
    NotificationService,
)


def _settings(tmp_path, **overrides) -> Settings:
    base = dict(
        app_environment="test",
        database_url="sqlite+pysqlite:///:memory:",
        jwt_secret_key="synthetic-ci-jwt-key-000000000000000000000000",
        notification_mode="sandbox",
        notification_sandbox_phone_allowlist="+15005550006",
        sms_provider_mode="local_outbox",
        sms_outbox_path=str(tmp_path / "sms_outbox.jsonl"),
    )
    base.update(overrides)
    return Settings(**base)


def _report() -> dict:
    return {
        "patient_name": "Sentetik Hasta",
        "report_type": "weekly",
        "from_date": "2026-08-24",
        "to_date": "2026-08-30",
        "record_count": 12,
        "total_calories": 1850.0,
        "average_daily_calories": 264.0,
        "accessibility_summary": "12 kullanıcı onaylı kayıt paylaşılacak.",
    }


@pytest.mark.asyncio
async def test_sms_reaches_the_outbox_with_a_message_id(tmp_path):
    settings = _settings(tmp_path)
    service = NotificationService(settings_override=settings)

    result = await service.send_channel(
        channel="sms",
        destination="+15005550006",
        report_data=_report(),
    )

    assert result["provider_message_id"].startswith("local-")
    assert result["provider_status"] == "queued_local_outbox"

    lines = (tmp_path / "sms_outbox.jsonl").read_text(encoding="utf-8").strip()
    record = json.loads(lines)
    assert record["to"] == "+15005550006"
    assert record["body"]
    assert record["message_id"] == result["provider_message_id"]


@pytest.mark.asyncio
async def test_sms_body_never_contains_the_full_food_log(tmp_path):
    """Rapor SMS'i ayrıntı taşımaz; bu bir gizlilik kuralıdır."""
    settings = _settings(tmp_path)
    service = NotificationService(settings_override=settings)

    report = _report()
    report["records"] = [{"food_name_tr": "Mercimek Çorbası"}]
    await service.send_channel(
        channel="sms", destination="+15005550006", report_data=report,
    )

    body = json.loads(
        (tmp_path / "sms_outbox.jsonl").read_text(encoding="utf-8").strip()
    )["body"]
    assert "Mercimek" not in body
    # Uzun mesaj bölünüp maliyet/karışıklık yaratmasın.
    assert len(body) <= 320


@pytest.mark.asyncio
async def test_recipient_outside_the_allowlist_is_rejected(tmp_path):
    settings = _settings(tmp_path)
    service = NotificationService(settings_override=settings)

    with pytest.raises(ChannelDeliveryError) as excinfo:
        await service.send_channel(
            channel="sms",
            destination="+905551112233",
            report_data=_report(),
        )
    assert excinfo.value.args[0] == "RECIPIENT_NOT_ALLOWLISTED"
    assert not (tmp_path / "sms_outbox.jsonl").exists()


@pytest.mark.asyncio
async def test_multiple_sends_append_without_overwriting(tmp_path):
    settings = _settings(tmp_path)
    service = NotificationService(settings_override=settings)

    for _ in range(3):
        await service.send_channel(
            channel="sms", destination="+15005550006", report_data=_report(),
        )

    lines = (tmp_path / "sms_outbox.jsonl").read_text(
        encoding="utf-8"
    ).strip().splitlines()
    assert len(lines) == 3
    ids = {json.loads(line)["message_id"] for line in lines}
    assert len(ids) == 3


def test_local_outbox_is_refused_in_production(tmp_path):
    """Yerel kutu gerçek teslimat sanılmamalı; production'da yapılandırılamaz."""
    settings = _settings(
        tmp_path,
        app_environment="prod",
        public_base_url="https://nutrisense.example.org",
        secret_key="x" * 48,
        jwt_secret_key="y" * 48,
        research_export_token="z" * 48,
        cors_origins="https://nutrisense.example.org",
        trusted_hosts="nutrisense.example.org",
        migration_startup_mode="verify",
    )
    with pytest.raises(RuntimeError, match="local_outbox"):
        settings.validate_security()


def test_twilio_mode_requires_credentials(tmp_path):
    settings = _settings(tmp_path, sms_provider_mode="twilio")
    with pytest.raises(RuntimeError, match="Twilio"):
        settings.validate_security()


@pytest.mark.asyncio
async def test_unwritable_outbox_reports_a_specific_error(tmp_path):
    """Salt okunur dizinde hata genel sağlayıcı hatası gibi görünmemeli."""
    unwritable = tmp_path / "dosya.txt"
    unwritable.write_text("bu bir dizin degil", encoding="utf-8")
    settings = _settings(tmp_path, sms_outbox_path=str(unwritable / "outbox.jsonl"))
    service = NotificationService(settings_override=settings)

    with pytest.raises(ChannelDeliveryError) as excinfo:
        await service.send_channel(
            channel="sms", destination="+15005550006", report_data=_report(),
        )
    assert excinfo.value.args[0] == "SMS_OUTBOX_NOT_WRITABLE"
