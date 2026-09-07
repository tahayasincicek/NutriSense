from copy import deepcopy

import pytest

from app.config import Settings
from app.domain.report_messages import build_report_sms, build_sms_parts, SMS_BODY_LIMIT
from app.services.notification_service import ChannelDeliveryError, NotificationService


def report(count=1):
    return {
        "schema_version": "dietitian-report-v3",
        "from_date": "2026-09-01", "to_date": "2026-09-07", "record_count": count,
        "records": [{
            "food_name_tr": f"Öğün {i} Çiğ köfte 🥗",
            "portion_grams": 125.5, "portion_is_estimate": i % 2 == 0,
            "total_calories": 214.75, "logged_at": "2026-09-07T12:35:01+03:00",
        } for i in range(count)],
    }


def service(transport):
    return NotificationService(settings_override=Settings(
        notification_mode="sandbox",
        notification_sandbox_phone_allowlist="+15005550006",
    ), sms_transport=transport)


def test_long_unicode_report_is_complete_and_every_body_fits():
    payload = report(120)
    # Long individual names must also split without losing Unicode characters.
    payload["records"][0]["food_name_tr"] = "Çığ🥗" * 400
    parts = build_sms_parts(payload)
    assert len(parts) > 1
    restored = "".join(part.split("\n", 1)[1] for part in parts)
    assert restored == build_report_sms(payload)
    for index, part in enumerate(parts, 1):
        assert part.startswith(f"NutriSense ({index}/{len(parts)})\n")
        assert len(part.encode("utf-16-le")) // 2 <= SMS_BODY_LIMIT


def test_legacy_consent_does_not_expand_to_details_on_retry():
    payload = report()
    payload["schema_version"] = "dietitian-report-v2"
    assert "kcal" not in build_report_sms(payload)
    assert "Çiğ köfte" not in build_report_sms(payload)


def test_incomplete_records_cannot_produce_a_successful_summary():
    payload = report()
    payload["record_count"] = 2
    with pytest.raises(ValueError):
        build_sms_parts(payload)


@pytest.mark.asyncio
async def test_retry_resumes_after_acknowledged_part_and_keeps_all_ids():
    payload = report(20)
    calls = []
    state = {}
    fail = True

    def checkpoint(progress):
        state.clear()
        state.update(deepcopy(progress))

    def transport(body, destination):
        calls.append(body)
        if fail and len(calls) == 2:
            raise ChannelDeliveryError("SMS_TEMPORARY", retryable=True)
        return {"provider_message_id": f"SM-{len(calls)}", "provider_status": "accepted"}

    sender = service(transport)
    with pytest.raises(ChannelDeliveryError, match="SMS_TEMPORARY"):
        await sender.send_channel(channel="sms", destination="+15005550006",
                                  report_data=payload, sms_progress=state, sms_checkpoint=checkpoint)
    assert state["parts"][0]["status"] == "sent"
    assert state["parts"][1]["status"] == "failed"
    fail = False
    result = await sender.send_channel(
        channel="sms", destination="+15005550006", report_data=payload,
        sms_progress=state, sms_checkpoint=checkpoint,
    )
    assert calls.count(build_sms_parts(payload)[0]) == 1
    assert all(part["status"] == "sent" and part["provider_message_id"] for part in state["parts"])
    assert result["provider_status"].startswith("accepted_parts:")


@pytest.mark.asyncio
async def test_timeout_is_not_blindly_retried():
    state = {}
    calls = []

    def transport(body, destination):
        calls.append(body)
        raise TimeoutError()

    sender = service(transport)
    for _ in range(2):
        with pytest.raises(ChannelDeliveryError, match="SMS_DELIVERY_UNCERTAIN"):
            await sender.send_channel(channel="sms", destination="+15005550006",
                                      report_data=report(), sms_progress=state,
                                      sms_checkpoint=lambda value: state.update(value))
    assert len(calls) == 1


@pytest.mark.asyncio
async def test_multipart_requires_durable_checkpoint_before_any_send():
    calls = []
    sender = service(lambda body, destination: calls.append(body))
    with pytest.raises(ChannelDeliveryError, match="SMS_CHECKPOINT_REQUIRED"):
        await sender.send_channel(channel="sms", destination="+15005550006", report_data=report(20))
    assert calls == []


@pytest.mark.asyncio
async def test_content_change_cannot_reuse_previous_progress():
    state = {}
    calls = []

    def transport(body, destination):
        calls.append(body)
        return {"provider_message_id": "SM-one", "provider_status": "accepted"}

    sender = service(transport)
    payload = report()
    await sender.send_channel(channel="sms", destination="+15005550006", report_data=payload,
                              sms_checkpoint=lambda value: state.update(value))
    payload["records"][0]["total_calories"] = 500
    with pytest.raises(ChannelDeliveryError, match="SMS_CONTENT_CHANGED"):
        await sender.send_channel(channel="sms", destination="+15005550006", report_data=payload,
                                  sms_progress=state, sms_checkpoint=lambda value: state.update(value))
    assert len(calls) == 1
