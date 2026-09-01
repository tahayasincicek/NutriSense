"""NutriSense configuration and environment safety gates."""

import hashlib
from functools import lru_cache
from pathlib import Path
from urllib.parse import urlsplit

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
    log_level: str = "INFO"
    log_format: str = "json"
    secret_key: str = "change-me-in-production"
    public_base_url: str = "http://localhost:8000"
    api_docs_enabled: bool = True
    build_revision: str = "unknown"
    graceful_shutdown_timeout_seconds: int = 30
    migration_startup_mode: str = "verify"
    staging_allow_insecure_localhost: bool = False

    database_url: str = ""
    db_host: str = "localhost"
    db_port: int = 3306
    db_user: str = "nutrisense"
    db_password: str = ""
    db_name: str = "nutrisense_db"

    jwt_secret_key: str = "change-me"
    jwt_algorithm: str = "HS256"
    jwt_issuer: str = "nutrisense-api"
    jwt_audience: str = "nutrisense-mobile"
    jwt_access_token_expire_minutes: int = 60
    jwt_refresh_token_expire_days: int = 30

    google_application_credentials: str = ""
    google_cloud_project_id: str = ""
    vision_provider_mode: str = "disabled"
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"
    nutritionix_app_id: str = ""
    nutritionix_api_key: str = ""
    nutrition_provider_mode: str = "verified_local"
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_phone_number: str = ""
    # SMS sağlayıcısı. local_outbox gerçek operatöre çıkmaz; mesajı dosyaya
    # yazar ve teslimat kaydı üretir. E-postadaki Mailpit'in karşılığıdır.
    sms_provider_mode: str = "disabled"
    sms_outbox_path: str = ".runtime/sms_outbox.jsonl"
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
    cors_allow_credentials: bool = False
    trusted_hosts: str = "localhost,127.0.0.1,testserver"
    security_hsts_max_age_seconds: int = 31536000
    research_export_token: str = ""
    # disabled: no collection; synthetic: fixtures only; approved: consented
    # participant collection is allowed after the external ethics gate is set.
    research_mode: str = "synthetic"
    research_protocol_version: str = ""
    research_consent_version: str = ""
    # Ürün tarafı aydınlatma metni sürümü. Rıza kayıtları bu sürümle
    # damgalanır; metin değişince yeni rıza istenebilmesi için gereklidir.
    privacy_notice_version: str = "taslak-yayinlanmadi"
    research_approval_reference: str = ""
    research_audio_consent_approved: bool = False
    migration_check_enabled: bool = True
    metrics_enabled: bool = False
    operations_token: str = ""
    ml_artifact_enabled: bool = False
    ml_artifact_path: str = ""
    ml_artifact_sha256: str = ""
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
    def trusted_hosts_list(self) -> list[str]:
        return [host.strip() for host in self.trusted_hosts.split(",") if host.strip()]

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
        public_url = urlsplit(self.public_base_url)

        if environment not in {"local", "dev", "test", "staging", "prod"}:
            raise RuntimeError(
                "APP_ENVIRONMENT local, dev, test, staging veya prod olmalıdır."
            )
        if self.log_level.upper() not in {
            "DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"
        }:
            raise RuntimeError("LOG_LEVEL geçersiz.")
        if self.log_format not in {"json", "text"}:
            raise RuntimeError("LOG_FORMAT json veya text olmalıdır.")
        if not 5 <= self.graceful_shutdown_timeout_seconds <= 120:
            raise RuntimeError("Graceful shutdown süresi 5-120 saniye olmalıdır.")
        if self.migration_startup_mode not in {"verify", "apply", "skip"}:
            raise RuntimeError("MIGRATION_STARTUP_MODE verify, apply veya skip olmalıdır.")
        if environment in {"staging", "prod"} and self.migration_startup_mode != "verify":
            raise RuntimeError(
                "Staging/production uygulama container'ı migration yalnız doğrulamalıdır."
            )
        if self.jwt_algorithm not in {"HS256", "HS384", "HS512"}:
            raise RuntimeError("JWT algorithm güvenli HMAC allowlist dışında.")
        if not self.jwt_issuer.strip() or not self.jwt_audience.strip():
            raise RuntimeError("JWT issuer ve audience boş olamaz.")
        if not 1 <= self.jwt_access_token_expire_minutes <= 60:
            raise RuntimeError("Access token süresi 1-60 dakika arasında olmalıdır.")
        if not 1 <= self.jwt_refresh_token_expire_days <= 30:
            raise RuntimeError("Refresh token süresi 1-30 gün arasında olmalıdır.")
        if self.sms_provider_mode not in {"disabled", "twilio", "local_outbox"}:
            raise RuntimeError(
                "SMS_PROVIDER_MODE disabled, twilio veya local_outbox olmalıdır."
            )
        if self.sms_provider_mode == "twilio":
            # Placeholder değerler kimlik sayılmaz; aksi hâlde "yapılandırıldı"
            # sanılıp gönderim çalışma zamanında sessizce düşer.
            placeholder = any(
                _unsafe_secret(value) or value.lower().startswith("your")
                for value in (self.twilio_account_sid, self.twilio_auth_token)
            )
            if placeholder or not self.twilio_phone_number.startswith("+"):
                raise RuntimeError(
                    "SMS_PROVIDER_MODE=twilio ise gerçek Twilio kimlik "
                    "bilgileri ve + ile başlayan gönderici numarası gereklidir."
                )
        if (
            self.app_environment.lower() in {"staging", "prod"}
            and self.sms_provider_mode == "local_outbox"
        ):
            raise RuntimeError(
                "local_outbox yalnız geliştirme içindir; gerçek alıcıya SMS "
                "göndermez."
            )
        if self.notification_mode not in {"disabled", "sandbox", "production"}:
            raise RuntimeError("NOTIFICATION_MODE disabled, sandbox veya production olmalıdır.")
        if self.vision_provider_mode not in {"disabled", "google", "gemini"}:
            raise RuntimeError(
                "VISION_PROVIDER_MODE disabled, google veya gemini olmalıdır."
            )
        if self.nutrition_provider_mode not in {
            "disabled", "verified_local", "nutritionix", "hybrid"
        }:
            raise RuntimeError(
                "NUTRITION_PROVIDER_MODE disabled, verified_local, nutritionix "
                "veya hybrid olmalıdır."
            )
        if self.vision_provider_mode == "google" and not (
            self.google_application_credentials and self.google_cloud_project_id
        ):
            raise RuntimeError(
                "Google Vision etkinse credentials mount yolu ve project id gereklidir."
            )
        if self.vision_provider_mode == "gemini" and not self.gemini_api_key:
            raise RuntimeError(
                "Gemini etkinse GEMINI_API_KEY secret store'dan gelmelidir."
            )
        if self.nutrition_provider_mode in {"nutritionix", "hybrid"} and not (
            self.nutritionix_app_id and self.nutritionix_api_key
        ):
            raise RuntimeError(
                "Nutritionix etkinse app id ve API key secret store'dan gelmelidir."
            )
        if self.metrics_enabled and _unsafe_secret(self.operations_token):
            raise RuntimeError(
                "Metrics etkinse güçlü OPERATIONS_TOKEN gereklidir."
            )
        if self.ml_artifact_enabled:
            self.validate_ml_artifact()

        if environment == "staging":
            if self.research_mode not in {"disabled", "synthetic"}:
                raise RuntimeError(
                    "Staging gerçek araştırma katılımcı verisi kabul edemez."
                )
            if self.notification_mode == "production":
                raise RuntimeError("Staging production bildirim sağlayıcısı kullanamaz.")
            if url.get_backend_name() == "sqlite":
                raise RuntimeError("Staging SQLite kullanamaz.")
            if _unsafe_secret(self.jwt_secret_key) or _unsafe_secret(self.secret_key):
                raise RuntimeError("Staging secret'ları güçlü ve dışarıdan sağlanmalıdır.")
            local_staging = (
                self.staging_allow_insecure_localhost
                and public_url.scheme == "http"
                and public_url.hostname in {"localhost", "127.0.0.1"}
            )
            if not local_staging and (
                public_url.scheme != "https" or not public_url.netloc
            ):
                raise RuntimeError("Staging PUBLIC_BASE_URL HTTPS olmalıdır.")

        if environment == "prod":
            if self.debug:
                raise RuntimeError("Production DEBUG kapalı olmalıdır.")
            if _unsafe_secret(self.jwt_secret_key):
                raise RuntimeError("Production JWT secret dışarıdan ve güvenli sağlanmalıdır.")
            if _unsafe_secret(self.secret_key):
                raise RuntimeError("Production application secret dışarıdan sağlanmalıdır.")
            if _unsafe_secret(self.research_export_token):
                raise RuntimeError("Production araştırma export anahtarı güvenli sağlanmalıdır.")
            if public_url.scheme != "https" or not public_url.netloc:
                raise RuntimeError("Production PUBLIC_BASE_URL mutlak HTTPS olmalıdır.")
            if public_url.username or public_url.password:
                raise RuntimeError("PUBLIC_BASE_URL kullanıcı bilgisi içeremez.")
            if self.api_docs_enabled:
                raise RuntimeError("Production API dokümantasyonu kapalı olmalıdır.")
            if not self.trusted_hosts_list or "*" in self.trusted_hosts_list:
                raise RuntimeError("Production TRUSTED_HOSTS açık allowlist olmalıdır.")
            public_host = (public_url.hostname or "").lower()
            if public_host not in {host.lower() for host in self.trusted_hosts_list}:
                raise RuntimeError("PUBLIC_BASE_URL hostu TRUSTED_HOSTS içinde olmalıdır.")
            if self.cors_allow_credentials:
                raise RuntimeError("Bearer token API'sinde CORS credentials kapalı olmalıdır.")
            for origin in self.cors_origins_list:
                parsed_origin = urlsplit(origin)
                if (
                    origin == "*"
                    or parsed_origin.scheme != "https"
                    or not parsed_origin.netloc
                    or parsed_origin.hostname in {"localhost", "127.0.0.1"}
                ):
                    raise RuntimeError("Production CORS originleri HTTPS allowlist olmalıdır.")
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
                if not (self.smtp_use_tls or self.smtp_start_tls):
                    raise RuntimeError("Production SMTP aktarım şifrelemesi etkin olmalıdır.")
            if self.notification_mode == "sandbox":
                raise RuntimeError("Production sandbox bildirim modunda başlatılamaz.")
            if self.research_mode == "synthetic":
                raise RuntimeError("Production araştırma modu synthetic olamaz.")

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

    def validate_ml_artifact(self) -> None:
        expected = self.ml_artifact_sha256.strip().lower()
        if len(expected) != 64 or any(
            character not in "0123456789abcdef" for character in expected
        ):
            raise RuntimeError("ML artefaktı için geçerli SHA-256 gereklidir.")
        path = Path(self.ml_artifact_path)
        if not path.is_file():
            raise RuntimeError("ML artefakt dosyası bulunamadı.")
        digest = hashlib.sha256()
        with path.open("rb") as artifact:
            for chunk in iter(lambda: artifact.read(1024 * 1024), b""):
                digest.update(chunk)
        if digest.hexdigest() != expected:
            raise RuntimeError("ML artefakt checksum doğrulaması başarısız.")

    @property
    def public_capabilities(self) -> dict[str, object]:
        return {
            "environment": self.app_environment.lower(),
            "vision": {
                "enabled": self.vision_provider_mode != "disabled",
                "mode": self.vision_provider_mode,
            },
            "nutrition": {
                "enabled": self.nutrition_provider_mode != "disabled",
                "mode": self.nutrition_provider_mode,
            },
            "notifications": {
                "enabled": self.notification_mode != "disabled",
                "mode": self.notification_mode,
                "sms": self.sms_provider_mode,
            },
            "offline_ml": {
                "enabled": self.ml_artifact_enabled,
            },
            "research": {
                "enabled": self.research_mode == "approved",
                "mode": self.research_mode,
            },
        }

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
