"""Amaç bazlı ürün rızaları ve rızanın davranışı gerçekten kapatması."""

import io

from PIL import Image

PASSWORD = "Guvenli123"


def _auth(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def _register(client, email: str) -> dict:
    response = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": PASSWORD,
        "full_name": "Sentetik Kullanıcı",
        "adult_confirmed": True,
    })
    assert response.status_code == 201, response.text
    return response.json()


def _jpeg_bytes() -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (64, 64), (120, 160, 90)).save(buffer, format="JPEG")
    return buffer.getvalue()


def test_consents_start_empty(client):
    """Rıza kaydı yoksa sessiz kabul edilmez."""
    user = _register(client, "riza-bos@example.com")
    response = client.get("/api/v1/consents", headers=_auth(user))
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["health_data_processing"] is False
    assert body["image_cross_border_transfer"] is False
    assert body["privacy_notice_acknowledgement"] is False
    assert body["consents"] == []


def test_consent_can_be_granted_and_revoked(client):
    user = _register(client, "riza-degisim@example.com")
    headers = _auth(user)

    granted = client.put("/api/v1/consents", headers=headers, json={
        "consent_type": "image_cross_border_transfer",
        "granted": True,
    })
    assert granted.status_code == 200, granted.text
    assert granted.json()["image_cross_border_transfer"] is True
    # Diğer amaç etkilenmemeli; rıza amaç bazlıdır.
    assert granted.json()["health_data_processing"] is False

    revoked = client.put("/api/v1/consents", headers=headers, json={
        "consent_type": "image_cross_border_transfer",
        "granted": False,
    })
    assert revoked.status_code == 200, revoked.text
    assert revoked.json()["image_cross_border_transfer"] is False


def test_privacy_notice_acknowledgement_is_versioned_and_recorded(client):
    from app.models.database import ConsentRecord, SessionLocal

    user = _register(client, "aydinlatma-kanit@example.com")
    response = client.put(
        "/api/v1/consents",
        headers=_auth(user),
        json={
            "consent_type": "privacy_notice_acknowledgement",
            "granted": True,
        },
    )
    assert response.status_code == 200
    assert response.json()["privacy_notice_acknowledgement"] is True
    with SessionLocal() as db:
        record = db.query(ConsentRecord).filter_by(
            user_id=user["user_id"],
            consent_type="privacy_notice_acknowledgement",
        ).one()
        assert record.policy_version
        assert record.granted_at is not None


def test_old_notice_acknowledgement_does_not_open_current_gate(client):
    from app.models.database import ConsentRecord, SessionLocal

    user = _register(client, "eski-aydinlatma@example.com")
    with SessionLocal() as db:
        db.add(ConsentRecord(
            user_id=user["user_id"],
            consent_type="privacy_notice_acknowledgement",
            policy_version="OLD-NOTICE",
            granted=True,
        ))
        db.commit()
    state = client.get("/api/v1/consents", headers=_auth(user))
    assert state.status_code == 200
    assert state.json()["privacy_notice_acknowledgement"] is False


def test_revocation_keeps_the_earlier_record_as_evidence(client):
    """Geri çekme kaydı silmez; ne zaman verilip alındığı kanıtlanabilmeli."""
    from app.models.database import ConsentRecord, SessionLocal

    user = _register(client, "riza-kanit@example.com")
    headers = _auth(user)
    client.put("/api/v1/consents", headers=headers, json={
        "consent_type": "health_data_processing", "granted": True,
    })
    client.put("/api/v1/consents", headers=headers, json={
        "consent_type": "health_data_processing", "granted": False,
    })

    db = SessionLocal()
    try:
        records = db.query(ConsentRecord).filter(
            ConsentRecord.user_id == user["user_id"],
            ConsentRecord.consent_type == "health_data_processing",
        ).all()
        assert len(records) == 2
        assert {record.granted for record in records} == {True, False}
        assert all(record.policy_version for record in records)
    finally:
        db.close()


def test_unknown_consent_type_is_rejected(client):
    user = _register(client, "riza-gecersiz@example.com")
    response = client.put("/api/v1/consents", headers=_auth(user), json={
        "consent_type": "pazarlama", "granted": True,
    })
    assert response.status_code == 422


def test_consents_are_scoped_to_the_owner(client):
    first = _register(client, "riza-sahip@example.com")
    second = _register(client, "riza-baskasi@example.com")
    client.put("/api/v1/consents", headers=_auth(first), json={
        "consent_type": "image_cross_border_transfer", "granted": True,
    })
    other = client.get("/api/v1/consents", headers=_auth(second))
    assert other.json()["image_cross_border_transfer"] is False


def test_analysis_is_blocked_without_cross_border_consent(client, monkeypatch):
    """Rıza yoksa görüntü hiç işlenmez ve sağlayıcıya gitmez."""
    from app.routers import food_router

    calls = []

    class RecordingVision:
        async def analyze_image(self, image_base64, **kwargs):
            calls.append(image_base64)
            raise AssertionError("rıza yokken sağlayıcı çağrılmamalı")

    monkeypatch.setattr(food_router.settings, "vision_provider_mode", "gemini")
    monkeypatch.setattr(food_router, "vision_service", RecordingVision())

    user = _register(client, "analiz-rizasiz@example.com")
    response = client.post(
        "/api/v1/analyze-food",
        headers=_auth(user),
        files={"image": ("meal.jpg", _jpeg_bytes(), "image/jpeg")},
        data={"capture_id": "11111111-1111-4111-8111-111111111111",
              "meal_type": "ogle"},
    )
    assert response.status_code == 403, response.text
    assert "yurt dışındaki sağlayıcıya" in response.json()["error"]["message"]
    assert calls == [], "görüntü sağlayıcıya gönderilmiş"


def test_analysis_is_not_blocked_when_provider_is_disabled(client, monkeypatch):
    """Sağlayıcı kapalıyken yurtdışı aktarımı yoktur; rıza kapısı da işlemez."""
    from app.routers import food_router
    from app.services.google_vision_service import VisionAPIError

    class UnavailableVision:
        async def analyze_image(self, image_base64, **kwargs):
            raise VisionAPIError("kapalı")

    monkeypatch.setattr(food_router.settings, "vision_provider_mode", "disabled")
    monkeypatch.setattr(food_router, "vision_service", UnavailableVision())

    user = _register(client, "analiz-kapali@example.com")
    response = client.post(
        "/api/v1/analyze-food",
        headers=_auth(user),
        files={"image": ("meal.jpg", _jpeg_bytes(), "image/jpeg")},
        data={"capture_id": "22222222-2222-4222-8222-222222222222",
              "meal_type": "ogle"},
    )
    # 403 değil: rıza kapısı devreye girmez, sağlayıcı hatası döner.
    assert response.status_code == 503, response.text
