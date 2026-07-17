# ==============================================================================
# backend/app/config.py
# NutriSense — Uygulama Ayarları
#
# python-dotenv ile .env dosyasından yüklenir.
# Pydantic Settings ile tip güvenli ayar yönetimi.
# ==============================================================================

from functools import lru_cache
from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    """Uygulama geneli ayarlar — .env dosyasından okunur."""

    # ── Uygulama ──
    app_name: str = "NutriSense"
    app_version: str = "1.0.0"
    app_environment: str = "dev"
    debug: bool = False
    secret_key: str = "change-me-in-production"

    # ── Veritabanı ──
    db_host: str = "localhost"
    db_port: int = 3306
    db_user: str = "nutrisense"
    db_password: str = ""
    db_name: str = "nutrisense_db"
    database_url_override: str = Field(default="", validation_alias="DATABASE_URL")

    @property
    def database_url(self) -> str:
        """SQLAlchemy bağlantı URL'i (PyMySQL driver)."""
        if self.database_url_override:
            return self.database_url_override
        return (
            f"mysql+pymysql://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
            f"?charset=utf8mb4"
        )

    # ── JWT ──
    jwt_secret_key: str = "change-me"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60
    jwt_refresh_token_expire_days: int = 30

    # ── Google Cloud Vision ──
    google_application_credentials: str = ""
    google_cloud_project_id: str = ""

    # ── Nutritionix ──
    nutritionix_app_id: str = ""
    nutritionix_api_key: str = ""

    # ── Twilio (SMS) ──
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_phone_number: str = ""

    # ── SMTP (E-posta) ──
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from_name: str = "NutriSense"
    smtp_from_email: str = ""

    # ── CORS ──
    cors_origins: str = "http://localhost:3000"
    research_export_token: str = ""

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",")]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}

    def validate_security(self) -> None:
        if self.app_environment.lower() == "prod" and self.jwt_secret_key in {
            "change-me",
            "change-me-in-production",
            "",
        }:
            raise RuntimeError(
                "Production JWT_SECRET_KEY güvenli ve dışarıdan sağlanan bir değer olmalıdır."
            )


@lru_cache()
def get_settings() -> Settings:
    """Singleton ayar nesnesi döner (her yerde aynı instance)."""
    return Settings()
