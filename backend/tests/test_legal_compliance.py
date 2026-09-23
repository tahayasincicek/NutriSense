"""Hukuki yayın kapıları ve uygulama dışı KVKK sayfaları."""

import pytest

from app.config import Settings, get_settings

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
        nutrition_provider_mode="verified_local",
        ml_artifact_enabled=False,
        data_controller_name="NutriSense Proje Ekibi",
        data_controller_contact_email="kvkk@nutrisense.org.tr",
        data_controller_postal_address="Üniversite Yerleşkesi, 34000 İstanbul",
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
        {"data_controller_postal_address": ""},
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
            "sms_provider_mode": "twilio",
            "twilio_account_sid": "AC" + "1" * 32,
            "twilio_auth_token": "t" * 40,
            "twilio_phone_number": "+15551234567",
        },
    ],
)
def test_cross_border_provider_requires_transfer_reference(overrides):
    with pytest.raises(RuntimeError, match="CROSS_BORDER_TRANSFER_REFERENCE"):
        _production(**overrides).validate_security()
    _production(
        **overrides, cross_border_transfer_reference=TRANSFER_REFERENCE
    ).validate_security()


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


@pytest.mark.parametrize("path", ["/gizlilik", "/privacy-policy"])
def test_public_privacy_policy_discloses_processing_and_user_controls(client, path):
    response = client.get(path)
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    assert "İşlenen veriler ve amaçlar" in response.text
    assert "Saklama ve silme" in response.text
    assert "/hesap-silme" in response.text
    assert "/kvkk-basvuru" in response.text
    assert "<form" not in response.text


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
    assert not {
        "/hesap-silme", "/account-deletion", "/kvkk-basvuru",
        "/gizlilik", "/privacy-policy",
    } & set(paths)
