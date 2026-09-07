import uuid

import pytest

from app.config import Settings
from app.models.database import SessionLocal, DietitianReport, FoodLog, Dietitian, NotificationDelivery
from app.routers import food_router
from app.services.notification_service import ChannelDeliveryError
from tests.test_dietitian_report_delivery import _register, _auth, _relationship


class LocalNotification:
    def __init__(self):
        self.settings = Settings(
            app_environment="test", notification_mode="sandbox", smtp_host="mailpit",
            sms_provider_mode="local_outbox",
        )
        self.calls = []
        self.fail = False

    async def send_channel(self, *, channel, destination, report_data, **kwargs):
        self.calls.append((channel, report_data))
        if self.fail:
            raise ChannelDeliveryError("TEST_UNAVAILABLE", retryable=True)
        return {"provider_message_id": f"local-{channel}", "provider_status": "accepted"}


@pytest.fixture
def setup(client, monkeypatch):
    notification = LocalNotification()
    monkeypatch.setattr(food_router, "notification_service", notification)
    tokens = _register(client, "automatic@example.com")
    _relationship(tokens["user_id"])
    return _auth(tokens), notification


def confirm(client, headers, action="confirm"):
    search = client.get("/api/v1/food/search", params={"query": "omlet"}, headers=headers)
    assert search.status_code == 200, search.text
    endpoint = f"/api/v1/food-analysis/{search.json()['analysis_id']}/decision"
    result = client.post(endpoint, json={"action": action}, headers=headers)
    assert result.status_code == 200, result.text
    return endpoint


def toggle(client, headers, enabled):
    result = client.put("/api/v1/dietitian-auto-share", json={"enabled": enabled}, headers=headers)
    assert result.status_code == 200, result.text


def test_opt_in_single_record_both_channels_duplicate_and_revoke(client, setup):
    headers, notification = setup
    assert client.get("/api/v1/dietitian-auto-share", headers=headers).json() == {"enabled": False}
    confirm(client, headers)
    assert notification.calls == []
    toggle(client, headers, True)
    endpoint = confirm(client, headers)
    assert [channel for channel, _ in notification.calls] == ["email", "sms"]
    payload = notification.calls[0][1]
    assert len(payload["records"]) == 1
    for key in ["food_name_tr", "portion_grams", "logged_at", "total_calories"]:
        assert payload["records"][0][key] is not None
    assert client.post(endpoint, json={"action": "confirm"}, headers=headers).status_code == 200
    assert len(notification.calls) == 2
    confirm(client, headers, "reject")
    assert len(notification.calls) == 2
    toggle(client, headers, False)
    confirm(client, headers)
    assert len(notification.calls) == 2
    with SessionLocal() as db:
        assert db.query(DietitianReport).count() == 1
        assert db.query(FoodLog).count() == 3


def test_delivery_failure_does_not_undo_food_and_external_retry_is_blocked(client, setup):
    headers, notification = setup
    toggle(client, headers, True)
    notification.fail = True
    confirm(client, headers)
    with SessionLocal() as db:
        assert db.query(FoodLog).count() == 1
        report_id = db.query(DietitianReport).one().id
        db.query(NotificationDelivery).update({"next_attempt_at": None})
        db.commit()
    notification.settings.smtp_host = "smtp.external.invalid"
    assert client.put("/api/v1/dietitian-auto-share", json={"enabled": True}, headers=headers).status_code == 409
    result = client.post(f"/api/v1/dietitian-reports/{report_id}/retry", headers=headers)
    assert result.status_code == 409
    confirm(client, headers)
    assert len(notification.calls) == 2


def test_revocation_blocks_failed_report_retry_and_missing_contacts(client, setup):
    headers, notification = setup
    assert client.put("/api/v1/dietitian-auto-share", json={"enabled": True}).status_code == 401
    toggle(client, headers, True)
    notification.fail = True
    confirm(client, headers)
    toggle(client, headers, False)
    with SessionLocal() as db:
        report_id = db.query(DietitianReport).one().id
        db.query(NotificationDelivery).update({"next_attempt_at": None})
        db.commit()
    result = client.post(f"/api/v1/dietitian-reports/{report_id}/retry", headers=headers)
    assert result.status_code == 409
    assert len(notification.calls) == 2
    with SessionLocal() as db:
        db.query(Dietitian).one().phone_verified = False
        db.commit()
    assert client.put("/api/v1/dietitian-auto-share", json={"enabled": True}, headers=headers).status_code == 422


def test_changed_contact_invalidates_opt_in(client, setup):
    headers, notification = setup
    toggle(client, headers, True)
    with SessionLocal() as db:
        db.query(Dietitian).one().email = "different@example.invalid"
        db.commit()
    confirm(client, headers)
    assert notification.calls == []
    assert client.get("/api/v1/dietitian-auto-share", headers=headers).json() == {"enabled": False}


def test_manual_food_confirmation_also_sends_once(client, setup):
    headers, notification = setup
    toggle(client, headers, True)
    body = {"capture_id": str(uuid.uuid4()), "food_name": "omlet", "portion_value": 100, "confirmed": True,
            "portion_unit": "gram", "portion_method": "user_selected", "meal_type": "kahvalti"}
    for _ in range(2):
        response = client.post("/api/v1/food-log/manual", json=body, headers=headers)
        assert response.status_code == 200, response.text
    assert len(notification.calls) == 2
