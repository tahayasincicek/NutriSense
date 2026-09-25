"""SMS hattının uçtan uca çalıştığını yerel kutu üzerinden kanıtlar.

Yerel kutu gerçek operatöre çıkmaz; e-posta tarafındaki Mailpit'in
karşılığıdır. Rıza, rapor içeriği, kanal seçimi ve teslimat kaydı gerçekten
çalışır, yalnız son adımda mesaj telefona ulaşmaz.
"""

import json

import httpx
import pytest

from app.config import Settings
from app.domain.report_messages import REPORT_SCHEMA_VERSION
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
        twilio_account_sid="",
        twilio_auth_token="",
        twilio_from_number="",
        iletimerkezi_api_key="",
        iletimerkezi_api_hash="",
        iletimerkezi_sender="",
    )
    base.update(overrides)
    return Settings(**base)


def _report() -> dict:
    return {
        "schema_version": REPORT_SCHEMA_VERSION,
        "patient_name": "Sentetik Hasta",
        "report_type": "weekly",
        "from_date": "2026-08-24",
        "to_date": "2026-08-30",
        "record_count": 1,
        "total_calories": 1850.0,
        "average_daily_calories": 264.0,
        "accessibility_summary": "12 kullanıcı onaylı kayıt paylaşılacak.",
        "records": [{
            "food_name_tr": "Mercimek Çorbası", "portion_grams": 150.5,
            "total_calories": 78.25, "portion_is_estimate": True,
            "logged_at": "2026-08-24T12:30:00+03:00",
        }],
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
async def test_sms_body_contains_every_approved_project_field(tmp_path):
    settings = _settings(tmp_path)
    service = NotificationService(settings_override=settings)

    report = _report()
    await service.send_channel(
        channel="sms", destination="+15005550006", report_data=report,
    )

    body = json.loads(
        (tmp_path / "sms_outbox.jsonl").read_text(encoding="utf-8").strip()
    )["body"]
    for detail in ("Mercimek Çorbası", "150.5 g", "24.08.2026", "12:30", "78.25 kcal"):
        assert detail in body
    assert "Sentetik Hasta" not in body


@pytest.mark.asyncio
async def test_recipient_outside_the_allowlist_is_rejected(tmp_path):
    settings = _settings(
        tmp_path, sms_provider_mode="twilio",
        twilio_account_sid="AC" + "1" * 32,
        twilio_auth_token="secret-test-token",
        twilio_phone_number="+15005550001",
    )
    service = NotificationService(settings_override=settings)

    with pytest.raises(ChannelDeliveryError) as excinfo:
        await service.send_channel(
            channel="sms",
            destination="+905000000001",
            report_data=_report(),
        )
    assert excinfo.value.args[0] == "RECIPIENT_NOT_ALLOWLISTED"
    assert not (tmp_path / "sms_outbox.jsonl").exists()


@pytest.mark.asyncio
async def test_local_sms_sink_accepts_verified_app_recipient_without_allowlist(tmp_path):
    settings = _settings(
        tmp_path, notification_sandbox_phone_allowlist="",
    )
    service = NotificationService(settings_override=settings)
    result = await service.send_channel(
        channel="sms", destination="+905000000001", report_data=_report(),
    )
    assert result["provider_status"] == "queued_local_outbox"


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


def test_iletimerkezi_mode_requires_credentials(tmp_path):
    settings = _settings(tmp_path, sms_provider_mode="iletimerkezi")
    with pytest.raises(RuntimeError, match="iletimerkezi"):
        settings.validate_security()


def test_iletimerkezi_sends_transactional_sms(monkeypatch, tmp_path):
    captured = {}

    class Response:
        def raise_for_status(self):
            return None

        def json(self):
            return {
                "response": {
                    "status": {"code": 200, "message": "İşlem başarılı"},
                    "order": {"id": "312891245"},
                },
            }

    def fake_post(url, *, json, timeout):
        captured.update(url=url, payload=json, timeout=timeout)
        return Response()

    monkeypatch.setattr(httpx, "post", fake_post)
    settings = _settings(
        tmp_path,
        sms_provider_mode="iletimerkezi",
        iletimerkezi_api_key="test-key-123456",
        iletimerkezi_api_hash="test-hash-123456",
        iletimerkezi_sender="APITEST",
    )
    result = NotificationService(settings_override=settings)._iletimerkezi_send(
        "TEST NutriSense", "+905551112233",
    )
    order = captured["payload"]["request"]["order"]
    assert captured["url"].endswith("/v1/send-sms/json")
    assert order["iys"] == "0"
    assert order["sender"] == "APITEST"
    assert order["message"]["receipents"]["number"] == ["905551112233"]
    assert result == {
        "provider_message_id": "312891245",
        "provider_status": "accepted",
    }


def test_iletimerkezi_maps_insufficient_credit_to_definitive_failure(
    monkeypatch,
    tmp_path,
):
    request = httpx.Request("POST", "https://api.iletimerkezi.com/v1/send-sms/json")
    response = httpx.Response(
        402,
        request=request,
        json={"response": {"status": {"code": 402, "message": "Bakiye yetersiz"}}},
    )

    def fake_post(*args, **kwargs):
        return response

    monkeypatch.setattr(httpx, "post", fake_post)
    settings = _settings(
        tmp_path,
        sms_provider_mode="iletimerkezi",
        iletimerkezi_api_key="test-key-123456",
        iletimerkezi_api_hash="test-hash-123456",
        iletimerkezi_sender="APITEST",
    )

    with pytest.raises(ChannelDeliveryError) as excinfo:
        NotificationService(settings_override=settings)._iletimerkezi_send(
            "TEST NutriSense", "+905551112233",
        )

    assert excinfo.value.args[0] == "SMS_INSUFFICIENT_CREDIT"
    assert excinfo.value.retryable is False


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
