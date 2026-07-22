"""NutriSense configuration and environment safety gates."""

from functools import lru_cache

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import make_url


_PLACEHOLDER_SECRETS = {
    "",
    "change-me",
    "change-me-in-production",
    "replace-with-a-long-random-value",
}


def _unsafe_secret(value: str) -> bool:
    normalized = value.strip()
    upper = normalized.upper()
    return (
        normalized in _PLACEHOLDER_SECRETS
        or len(normalized) < 32
        or "REPLACE" in upper
        or "CHANGE-ME" in upper
        or "YOUR_" in upper
    )


class Settings(BaseSettings):
    """Environment-backed application settings.

    ``DATABASE_URL`` is canonical. The split DB_* fields only provide a
    backwards-compatible development default and are never accepted as a
    production substitute for an explicit URL.
    """

    app_name: str = "NutriSense"
    app_version: str = "1.0.0"
    app_environment: str = "dev"
    debug: bool = False
    secret_key: str = "change-me-in-production"

    database_url: str = ""
    db_host: str = "localhost"
    db_port: int = 3306
    db_user: str = "nutrisense"
    db_password: str = ""
    db_name: str = "nutrisense_db"

    jwt_secret_key: str = "change-me"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60
    jwt_refresh_token_expire_days: int = 30

    google_application_credentials: str = ""
    google_cloud_project_id: str = ""
    nutritionix_app_id: str = ""
    nutritionix_api_key: str = ""
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_phone_number: str = ""
    notification_mode: str = "disabled"
    notification_sandbox_email_allowlist: str = ""
    notification_sandbox_phone_allowlist: str = ""
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from_name: str = "NutriSense"
    smtp_from_email: str = ""
    smtp_use_tls: bool = False
    smtp_start_tls: bool = True

    cors_origins: str = "http://localhost:3000"
    research_export_token: str = ""
    # disabled: no collection; synthetic: fixtures only; approved: consented
    # participant collection is allowed after the external ethics gate is set.
    research_mode: str = "synthetic"
    research_protocol_version: str = ""
    research_consent_version: str = ""
    research_approval_reference: str = ""
    research_audio_consent_approved: bool = False
    migration_check_enabled: bool = True
    max_analysis_image_bytes: int = 5 * 1024 * 1024
    max_analysis_image_pixels: int = 20_000_000
    vision_timeout_seconds: float = 15.0
    analysis_rate_limit_per_minute: int = 20

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    @model_validator(mode="after")
    def resolve_database_url(self):
        if not self.database_url:
            self.database_url = (
                f"mysql+pymysql://{self.db_user}:{self.db_password}"
                f"@{self.db_host}:{self.db_port}/{self.db_name}?charset=utf8mb4"
            )
        return self

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def sandbox_email_allowlist(self) -> set[str]:
        return {
            value.strip().lower() for value in
            self.notification_sandbox_email_allowlist.split(",") if value.strip()
        }

    @property
    def sandbox_phone_allowlist(self) -> set[str]:
        return {
            value.strip() for value in
            self.notification_sandbox_phone_allowlist.split(",") if value.strip()
        }

    def validate_security(self) -> None:
        environment = self.app_environment.lower()
        url = make_url(self.database_url)

        if environment == "prod":
            if self.debug:
                raise RuntimeError("Production DEBUG kapalı olmalıdır.")
            if _unsafe_secret(self.jwt_secret_key):
                raise RuntimeError("Production JWT secret dışarıdan ve güvenli sağlanmalıdır.")
            if _unsafe_secret(self.secret_key):
                raise RuntimeError("Production application secret dışarıdan sağlanmalıdır.")
            if _unsafe_secret(self.research_export_token):
                raise RuntimeError("Production araştırma export anahtarı güvenli sağlanmalıdır.")
            if url.get_backend_name() == "sqlite":
                raise RuntimeError("Production SQLite kullanamaz.")
            if not url.password or "REPLACE" in str(url.password).upper():
                raise RuntimeError("Production veritabanı parolası boş olamaz.")
            if "database_url" not in self.model_fields_set:
                raise RuntimeError("Production DATABASE_URL açıkça tanımlanmalıdır.")
            if self.notification_mode == "production":
                if not self.smtp_user or not self.smtp_password:
                    raise RuntimeError("Production SMTP kimlik bilgileri secret store'dan gelmelidir.")
                if not self.smtp_from_email:
                    raise RuntimeError("Production SMTP gönderici adresi tanımlanmalıdır.")
            if self.notification_mode == "sandbox":
                raise RuntimeError("Production sandbox bildirim modunda başlatılamaz.")

        if environment == "test":
            self.validate_test_database_safety()

        if self.research_mode not in {"disabled", "synthetic", "approved"}:
            raise RuntimeError(
                "RESEARCH_MODE disabled, synthetic veya approved olmalıdır."
            )
        if self.research_mode == "approved":
            required = {
                "RESEARCH_PROTOCOL_VERSION": self.research_protocol_version,
                "RESEARCH_CONSENT_VERSION": self.research_consent_version,
                "RESEARCH_APPROVAL_REFERENCE": self.research_approval_reference,
            }
            invalid = [name for name, value in required.items() if _unsafe_research_value(value)]
            if invalid:
                raise RuntimeError(
                    "Onaylı araştırma modu için gerçek ve kurulca doğrulanmış "
                    f"alanlar gerekli: {', '.join(invalid)}"
                )

    def validate_test_database_safety(self) -> None:
        """Prevent tests from ever targeting a production-like database."""
        url = make_url(self.database_url)
        backend = url.get_backend_name()
        database_name = (url.database or "").lower()
        if backend == "sqlite":
            return
        if not database_name.endswith("_test"):
            raise RuntimeError("Test veritabanı adı güvenlik için '_test' ile bitmelidir.")


@lru_cache()
def get_settings() -> Settings:
    return Settings()


def _unsafe_research_value(value: str) -> bool:
    normalized = value.strip()
    upper = normalized.upper()
    return (
        not normalized
        or normalized in {"0", "N/A", "NA", "NONE"}
        or "PLACEHOLDER" in upper
        or "REPLACE" in upper
        or "TBD" in upper
        or "TODO" in upper
        or "ÖRNEK" in upper
        or "EXAMPLE" in upper
    )
