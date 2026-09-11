"""Hukuki yayın kapıları, yetişkin beyanı ve uygulama dışı KVKK sayfaları."""

import pytest

from app.config import Settings, get_settings
from app.models.database import SessionLocal, User

PASSWORD = "SyntheticPassword123"
TRANSFER_REFERENCE = "KVKK-AKTARIM-2026-01"


def _production(**overrides) -> Settings:
    values = dict(
        _env_file=None,
        app_environment="prod",
        debug=False,
        database_url="mysql+pymysql://app:fake-password@db/product",
        jwt_secret_key="j" * 48,
        secret_key="s" * 48,
        research_export_token="r" * 48,
        research_pseudonymization_key="p" * 48,
        privacy_notice_version="KVKK-AYD-2026-01",
        public_base_url="https://nutrisense.org.tr",
        trusted_hosts="nutrisense.org.tr",
        cors_origins="https://nutrisense.org.tr",
        api_docs_enabled=False,
        migration_startup_mode="verify",
        research_mode="disabled",
        notification_mode="disabled",
        sms_provider_mode="disabled",
        vision_provider_mode="disabled",
        nutrition_provider_mode="verified_local",
        ml_artifact_enabled=False,
        data_controller_name="NutriSense Proje Ekibi",
        data_controller_contact_email="kvkk@nutrisense.org.tr",
    )
    values.update(overrides)
    return Settings(**values)


def test_configured_production_passes_legal_gates():
    _production().validate_security()


@pytest.mark.parametrize(
    "overrides",
    [
        {"data_controller_name": ""},
        {"data_controller_contact_email": ""},
        {"data_controller_contact_email": "kvkk-birimi"},
        {"data_controller_name": "REPLACE_WITH_CONTROLLER"},
    ],
)
def test_production_requires_data_controller_identity(overrides):
    with pytest.raises(RuntimeError, match="veri sorumlusu"):
        _production(**overrides).validate_security()


@pytest.mark.parametrize(
    "overrides",
    [
        {
            "nutrition_provider_mode": "nutritionix",
            "nutritionix_app_id": "synthetic-app",
            "nutritionix_api_key": "synthetic-key",
        },
        {
            "notification_mode": "production",
            "smtp_user": "mailer",
            "smtp_password": "synthetic-smtp-password",
            "smtp_from_email": "bildirim@nutrisense.org.tr",
        },
    ],
)
def test_cross_border_provider_requires_transfer_reference(overrides):
    with pytest.raises(RuntimeError, match="CROSS_BORDER_TRANSFER_REFERENCE"):
        _production(**overrides).validate_security()
    _production(
        **overrides, cross_border_transfer_reference=TRANSFER_REFERENCE
    ).validate_security()


def test_production_gemini_requires_paid_tier():
    gemini = {
        "vision_provider_mode": "gemini",
        "gemini_api_key": "synthetic-gemini-key",
        "cross_border_transfer_reference": TRANSFER_REFERENCE,
    }
    with pytest.raises(RuntimeError, match="GEMINI_PAID_TIER_CONFIRMED"):
        _production(**gemini).validate_security()
    _production(**gemini, gemini_paid_tier_confirmed=True).validate_security()


def _register(client, **extra):
    return client.post("/api/v1/auth/register", json={
        "email": "yetiskin@example.com",
        "password": PASSWORD,
        "full_name": "Sentetik Kullanıcı",
        **extra,
    })


def test_registration_requires_adult_confirmation(client):
    assert _register(client).status_code == 422
    assert _register(client, adult_confirmed=False).status_code == 422
    db = SessionLocal()
    try:
        assert db.query(User).count() == 0
    finally:
        db.close()


def test_registration_records_adult_confirmation_time(client):
    assert _register(client, adult_confirmed=True).status_code == 201
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == "yetiskin@example.com").one()
        assert user.adult_confirmed_at is not None
    finally:
        db.close()


@pytest.mark.parametrize("path", ["/hesap-silme", "/account-deletion"])
def test_account_deletion_page_is_public_and_collects_nothing(client, path):
    response = client.get(path)
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    assert "Hesabı Sil" in response.text
    assert "30 gün" in response.text
    assert "<form" not in response.text


def test_data_subject_request_page_lists_rights_and_deadlines(client):
    response = client.get("/kvkk-basvuru")
    assert response.status_code == 200
    assert "11. maddesi" in response.text
    assert "30 gün" in response.text
    assert "60 gün" in response.text


def test_legal_pages_escape_configured_contact(client, monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "data_controller_name", "<script>x</script>")
    monkeypatch.setattr(settings, "data_controller_contact_email", "kvkk@nutrisense.org.tr")
    response = client.get("/kvkk-basvuru")
    assert "<script>" not in response.text
    assert "&lt;script&gt;" in response.text
    assert 'href="mailto:kvkk@nutrisense.org.tr"' in response.text


def test_legal_pages_stay_out_of_api_contract(client):
    paths = client.get("/openapi.json").json()["paths"]
    assert not {"/hesap-silme", "/account-deletion", "/kvkk-basvuru"} & set(paths)
