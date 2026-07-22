"""SQLAlchemy data model for product and pseudonymous research data."""

import uuid
from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    create_engine,
    event,
)
from sqlalchemy.orm import declarative_base, relationship, sessionmaker
from sqlalchemy.pool import StaticPool
from sqlalchemy.types import TypeDecorator

from ..config import get_settings


def utc_now() -> datetime:
    """Return an aware UTC timestamp for every application timestamp."""
    return datetime.now(timezone.utc)


def utc_today() -> date:
    return utc_now().date()


ISTANBUL_TIMEZONE = ZoneInfo("Europe/Istanbul")


def istanbul_date(value: datetime | None = None) -> date:
    """Return the product's explicit local calendar day from a UTC instant."""

    instant = value or utc_now()
    if instant.tzinfo is None:
        instant = instant.replace(tzinfo=timezone.utc)
    return instant.astimezone(ISTANBUL_TIMEZONE).date()


settings = get_settings()
_engine_options: dict = {"pool_pre_ping": True, "echo": settings.debug}
if settings.database_url.startswith("sqlite"):
    _engine_options["connect_args"] = {"check_same_thread": False}
    if ":memory:" in settings.database_url:
        _engine_options["poolclass"] = StaticPool
else:
    _engine_options.update(pool_size=10, max_overflow=20, pool_recycle=1800)

engine = create_engine(settings.database_url, **_engine_options)


if settings.database_url.startswith("sqlite"):
    @event.listens_for(engine, "connect")
    def _enable_sqlite_foreign_keys(dbapi_connection, _connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()


SessionLocal = sessionmaker(autocommit=False, autoflush=False, expire_on_commit=False, bind=engine)
Base = declarative_base()
UUIDString = String(36)


class UTCDateTime(TypeDecorator):
    """Persist UTC consistently and always return timezone-aware values."""

    impl = DateTime
    cache_ok = True

    def load_dialect_impl(self, dialect):
        return dialect.type_descriptor(DateTime(timezone=dialect.name != "mysql"))

    def process_bind_param(self, value, _dialect):
        if value is None:
            return None
        if value.tzinfo is None:
            raise ValueError("Timezone-aware UTC datetime gerekli.")
        return value.astimezone(timezone.utc).replace(tzinfo=None)

    def process_result_value(self, value, _dialect):
        if value is None:
            return None
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


class User(Base):
    __tablename__ = "users"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    phone = Column(String(20), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False)
    updated_at = Column(UTCDateTime, default=utc_now, onupdate=utc_now, nullable=False)
    daily_calorie_target = Column(Float, default=2000.0, nullable=False)
    preferred_language = Column(String(10), default="tr-TR", nullable=False)
    tts_speed = Column(Float, default=0.5, nullable=False)
    high_contrast = Column(Boolean, default=True, nullable=False)
    dietitian_id = Column(UUIDString, ForeignKey("dietitians.id", ondelete="SET NULL"), nullable=True)

    food_logs = relationship("FoodLog", back_populates="user", cascade="all, delete-orphan")
    dietitian = relationship("Dietitian", back_populates="patients")


class Dietitian(Base):
    __tablename__ = "dietitians"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, nullable=False, index=True)
    full_name = Column(String(255), nullable=False)
    phone = Column(String(20), nullable=True)
    email_verified = Column(Boolean, default=False, nullable=False)
    phone_verified = Column(Boolean, default=False, nullable=False)
    specialization = Column(String(255), default="Beslenme ve Diyet", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False)

    patients = relationship("User", back_populates="dietitian")


class DietitianAssignment(Base):
    __tablename__ = "dietitian_assignments"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(UUIDString, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    dietitian_id = Column(UUIDString, ForeignKey("dietitians.id", ondelete="RESTRICT"), nullable=False, index=True)
    status = Column(Enum("pending", "approved", "cancelled", name="assignment_status_enum"), default="pending", nullable=False)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False)
    approved_at = Column(UTCDateTime, nullable=True)
    cancelled_at = Column(UTCDateTime, nullable=True)


class ConsentRecord(Base):
    __tablename__ = "consent_records"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(UUIDString, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    assignment_id = Column(UUIDString, ForeignKey("dietitian_assignments.id", ondelete="CASCADE"), nullable=True)
    consent_type = Column(String(64), nullable=False)
    policy_version = Column(String(32), nullable=False)
    granted = Column(Boolean, nullable=False)
    context_hash = Column(String(64), nullable=True, index=True)
    channels_json = Column(JSON, nullable=True)
    record_count = Column(Integer, nullable=True)
    date_from = Column(Date, nullable=True)
    date_to = Column(Date, nullable=True)
    recipient_masked = Column(JSON, nullable=True)
    request_id = Column(String(64), nullable=True, index=True)
    granted_at = Column(UTCDateTime, default=utc_now, nullable=False)
    revoked_at = Column(UTCDateTime, nullable=True)


class RecognitionAttempt(Base):
    __tablename__ = "recognition_attempts"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(UUIDString, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    provider = Column(String(64), nullable=False)
    capture_id = Column(UUIDString, nullable=True)
    status = Column(Enum("succeeded", "failed", name="recognition_status_enum"), nullable=False)
    food_name = Column(String(255), nullable=True)
    confidence = Column(Float, nullable=True)
    request_id = Column(String(64), nullable=True, index=True)
    error_code = Column(String(64), nullable=True)
    analysis_payload = Column(JSON, nullable=True)
    decision = Column(String(16), nullable=True)
    expires_at = Column(UTCDateTime, nullable=True)
    decided_at = Column(UTCDateTime, nullable=True)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False, index=True)
    __table_args__ = (
        UniqueConstraint("user_id", "capture_id", name="uq_recognition_user_capture"),
    )


class NutritionSource(Base):
    __tablename__ = "nutrition_sources"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    provider = Column(String(64), nullable=False)
    external_reference = Column(String(255), nullable=True)
    canonical_food_id = Column(String(255), default="food.legacy.unmapped", nullable=False)
    source_item_id = Column(String(255), default="legacy-unverified", nullable=False)
    locale = Column(String(16), default="und", nullable=False)
    serving_unit = Column(String(64), default="gram", nullable=False)
    serving_grams = Column(Numeric(14, 6), default=100, nullable=False)
    license_name = Column(String(255), default="UNVERIFIED LEGACY", nullable=False)
    attribution = Column(Text, default="Legacy record; source unavailable", nullable=False)
    normalization_version = Column(String(64), default="legacy-unmapped", nullable=False)
    food_name = Column(String(255), nullable=False)
    calories_per_100g = Column(Numeric(14, 6), nullable=False)
    payload_checksum = Column(String(64), nullable=True)
    retrieved_at = Column(UTCDateTime, default=utc_now, nullable=False)


class FoodLog(Base):
    __tablename__ = "food_logs"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(UUIDString, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    recognition_attempt_id = Column(UUIDString, ForeignKey("recognition_attempts.id", ondelete="RESTRICT"), nullable=True, unique=True)
    nutrition_source_id = Column(UUIDString, ForeignKey("nutrition_sources.id", ondelete="RESTRICT"), nullable=True)
    food_name = Column(String(255), nullable=False)
    food_name_tr = Column(String(255), nullable=False)
    original_food_name = Column(String(255), nullable=True)
    original_food_name_tr = Column(String(255), nullable=True)
    canonical_food_id = Column(String(255), default="food.legacy.unmapped", nullable=False)
    calories_per_100g = Column(Numeric(14, 6), nullable=False)
    estimated_portion_g = Column(Numeric(14, 6), nullable=False)
    portion_value = Column(Numeric(14, 6), default=100, nullable=False)
    portion_unit = Column(String(16), default="gram", nullable=False)
    portion_method = Column(String(32), default="legacy_unknown", nullable=False)
    portion_is_estimate = Column(Boolean, default=True, nullable=False)
    total_calories = Column(Numeric(14, 6), nullable=False)
    protein = Column(Numeric(14, 6), default=0, nullable=False)
    carbs = Column(Numeric(14, 6), default=0, nullable=False)
    fat = Column(Numeric(14, 6), default=0, nullable=False)
    fiber = Column(Numeric(14, 6), default=0, nullable=False)
    macro_calories = Column(Numeric(14, 6), default=0, nullable=False)
    macro_calorie_delta = Column(Numeric(14, 6), default=0, nullable=False)
    nutrition_reliability = Column(String(32), default="unverified", nullable=False)
    confidence = Column(Float, default=0.0, nullable=False)
    meal_type = Column(Enum("kahvalti", "ogle", "aksam", "atistirmalik", name="meal_type_enum"), default="atistirmalik", nullable=False)
    recognition_source = Column(Enum("google_vision", "tflite", "manual", name="recognition_source_enum"), default="google_vision", nullable=False)
    is_user_confirmed = Column(Boolean, default=True, nullable=False, index=True)
    is_corrected = Column(Boolean, default=False, nullable=False)
    image_url = Column(Text, nullable=True)
    logged_at = Column(UTCDateTime, default=utc_now, nullable=False, index=True)
    log_date = Column(Date, default=istanbul_date, nullable=False, index=True)
    updated_at = Column(UTCDateTime, default=utc_now, onupdate=utc_now, nullable=False)
    deleted_at = Column(UTCDateTime, nullable=True, index=True)

    user = relationship("User", back_populates="food_logs")
    recognition_attempt = relationship("RecognitionAttempt")
    nutrition_source = relationship("NutritionSource")
    __table_args__ = (
        Index("idx_user_date", "user_id", "log_date"),
        Index("idx_user_meal", "user_id", "meal_type"),
    )


class DietitianReport(Base):
    __tablename__ = "dietitian_reports"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(UUIDString, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    dietitian_id = Column(UUIDString, ForeignKey("dietitians.id", ondelete="RESTRICT"), nullable=False)
    idempotency_key = Column(String(128), nullable=False)
    request_id = Column(String(64), nullable=True, index=True)
    consent_context_hash = Column(String(64), nullable=False)
    channels_json = Column(JSON, nullable=False, default=list)
    recipient_snapshot_json = Column(JSON, nullable=False, default=dict)
    payload_json = Column(JSON, nullable=False, default=dict)
    report_type = Column(Enum("daily", "weekly", "monthly", name="report_type_enum"), default="weekly", nullable=False)
    date_from = Column(Date, nullable=False)
    date_to = Column(Date, nullable=False)
    total_calories = Column(Float, default=0.0, nullable=False)
    total_meals = Column(Integer, default=0, nullable=False)
    record_count = Column(Integer, default=0, nullable=False)
    status = Column(Enum(
        "queued", "sending", "sent", "partial_failed", "failed",
        name="report_status_enum",
    ), default="queued", nullable=False)
    sent_via_email = Column(Boolean, default=False, nullable=False)
    sent_via_sms = Column(Boolean, default=False, nullable=False)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False)
    sent_at = Column(UTCDateTime, nullable=True)
    completed_at = Column(UTCDateTime, nullable=True)
    __table_args__ = (UniqueConstraint("user_id", "idempotency_key", name="uq_report_user_idempotency"),)


class NotificationDelivery(Base):
    __tablename__ = "notification_deliveries"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    report_id = Column(UUIDString, ForeignKey("dietitian_reports.id", ondelete="CASCADE"), nullable=False, index=True)
    channel = Column(Enum("email", "sms", name="notification_channel_enum"), nullable=False)
    status = Column(Enum(
        "queued", "sending", "sent", "failed", "skipped",
        name="notification_status_enum",
    ), default="queued", nullable=False)
    provider_message_id = Column(String(255), nullable=True)
    provider_status = Column(String(64), nullable=True)
    error_code = Column(String(64), nullable=True)
    error_message = Column(String(255), nullable=True)
    destination_masked = Column(String(255), nullable=False)
    attempt_count = Column(Integer, default=0, nullable=False)
    max_attempts = Column(Integer, default=3, nullable=False)
    next_attempt_at = Column(UTCDateTime, nullable=True, index=True)
    attempted_at = Column(UTCDateTime, nullable=True)
    sent_at = Column(UTCDateTime, nullable=True)
    __table_args__ = (UniqueConstraint("report_id", "channel", name="uq_report_delivery_channel"),)


class SurveyVersion(Base):
    __tablename__ = "survey_versions"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    version = Column(String(32), unique=True, nullable=False)
    schema_json = Column(JSON, nullable=False, default=dict)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False)


class SurveySubmission(Base):
    __tablename__ = "survey_submissions"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    participant_pseudonym = Column(UUIDString, nullable=False, index=True)
    survey_version_id = Column(UUIDString, ForeignKey("survey_versions.id", ondelete="RESTRICT"), nullable=False)
    answers_json = Column(JSON, nullable=False)
    completion_seconds = Column(Integer, nullable=True)
    device_info = Column(String(255), nullable=True)
    protocol_version = Column(String(64), nullable=False, default="legacy-unverified")
    approval_reference = Column(String(128), nullable=False, default="legacy-unverified")
    data_origin = Column(String(16), nullable=False, default="synthetic")
    idempotency_key = Column(String(128), nullable=True)
    submitted_at = Column(UTCDateTime, default=utc_now, nullable=False, index=True)
    __table_args__ = (
        UniqueConstraint(
            "participant_pseudonym",
            "idempotency_key",
            name="uq_survey_participant_idempotency",
        ),
    )


class UsabilitySession(Base):
    __tablename__ = "usability_sessions"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    participant_pseudonym = Column(UUIDString, nullable=False, index=True)
    session_date = Column(UTCDateTime, default=utc_now, nullable=False)
    general_note = Column(String(1000), nullable=True)
    success_rate = Column(Float, nullable=True)
    avg_task_duration = Column(Float, nullable=True)
    schema_version = Column(String(32), nullable=False, default="1.0")
    counterbalance_sequence = Column(String(2), nullable=True)
    protocol_version = Column(String(64), nullable=False, default="legacy-unverified")
    approval_reference = Column(String(128), nullable=False, default="legacy-unverified")
    data_origin = Column(String(16), nullable=False, default="synthetic")
    idempotency_key = Column(String(128), nullable=True)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False)
    __table_args__ = (
        UniqueConstraint(
            "participant_pseudonym",
            "idempotency_key",
            name="uq_usability_participant_idempotency",
        ),
    )


class UsabilityTask(Base):
    __tablename__ = "usability_tasks"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = Column(UUIDString, ForeignKey("usability_sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    task_key = Column(String(64), nullable=False)
    condition = Column(String(32), nullable=False, default="nutrisense")
    title = Column(String(255), nullable=False)
    description = Column(String(1000), nullable=True)
    status = Column(String(32), nullable=False)
    started_at = Column(UTCDateTime, nullable=True)
    ended_at = Column(UTCDateTime, nullable=True)
    duration_seconds = Column(Float, nullable=True)
    is_success = Column(Boolean, nullable=True)
    error_count = Column(Integer, nullable=False, default=0)
    assistance_level = Column(String(32), nullable=False, default="none")
    abort_reason = Column(String(255), nullable=True)
    timing_source = Column(String(32), nullable=False, default="monotonic")
    manually_edited = Column(Boolean, nullable=False, default=False)
    edit_reason = Column(String(255), nullable=True)
    researcher_note = Column(String(1000), nullable=True)


class ResearchConsent(Base):
    """Consent evidence kept separate from survey and usability outcomes."""

    __tablename__ = "research_consents"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    participant_pseudonym = Column(UUIDString, nullable=False, unique=True, index=True)
    protocol_version = Column(String(64), nullable=False)
    consent_version = Column(String(64), nullable=False)
    approval_reference = Column(String(128), nullable=False)
    consent_method = Column(String(32), nullable=False)
    evidence_reference = Column(String(255), nullable=True)
    witness_reference = Column(String(255), nullable=True)
    withdrawal_code_hash = Column(String(64), nullable=False, unique=True)
    data_origin = Column(String(16), nullable=False)
    granted_at = Column(UTCDateTime, nullable=False, default=utc_now)
    withdrawn_at = Column(UTCDateTime, nullable=True)
    created_at = Column(UTCDateTime, nullable=False, default=utc_now)


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    jti = Column(UUIDString, primary_key=True)
    user_id = Column(UUIDString, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    token_hash = Column(String(64), nullable=False, unique=True)
    expires_at = Column(UTCDateTime, nullable=False, index=True)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False)
    revoked_at = Column(UTCDateTime, nullable=True)
    replaced_by_jti = Column(UUIDString, nullable=True)


class AuditEvent(Base):
    __tablename__ = "audit_events"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(UUIDString, nullable=True, index=True)
    actor_type = Column(String(32), default="user", nullable=False)
    event = Column(String(64), nullable=False, index=True)
    email_hash = Column(String(64), nullable=True)
    ip_address = Column(String(64), nullable=True)
    success = Column(Boolean, nullable=False)
    reason = Column(String(128), nullable=True)
    metadata_json = Column(JSON, nullable=True)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False, index=True)


# Compatibility alias for existing auth code and tests.
AuthAuditLog = AuditEvent
