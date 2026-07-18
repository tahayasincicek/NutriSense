"""SQLAlchemy data model for product and pseudonymous research data."""

import uuid
from datetime import date, datetime, timezone

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
    food_name = Column(String(255), nullable=False)
    calories_per_100g = Column(Float, nullable=False)
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
    calories_per_100g = Column(Float, nullable=False)
    estimated_portion_g = Column(Float, nullable=False)
    total_calories = Column(Float, nullable=False)
    protein = Column(Float, default=0.0, nullable=False)
    carbs = Column(Float, default=0.0, nullable=False)
    fat = Column(Float, default=0.0, nullable=False)
    fiber = Column(Float, default=0.0, nullable=False)
    confidence = Column(Float, default=0.0, nullable=False)
    meal_type = Column(Enum("kahvalti", "ogle", "aksam", "atistirmalik", name="meal_type_enum"), default="atistirmalik", nullable=False)
    recognition_source = Column(Enum("google_vision", "tflite", "manual", name="recognition_source_enum"), default="google_vision", nullable=False)
    image_url = Column(Text, nullable=True)
    logged_at = Column(UTCDateTime, default=utc_now, nullable=False, index=True)
    log_date = Column(Date, default=utc_today, nullable=False, index=True)

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
    report_type = Column(Enum("daily", "weekly", "monthly", name="report_type_enum"), default="weekly", nullable=False)
    date_from = Column(Date, nullable=False)
    date_to = Column(Date, nullable=False)
    total_calories = Column(Float, default=0.0, nullable=False)
    total_meals = Column(Integer, default=0, nullable=False)
    status = Column(Enum("pending", "sent", "failed", name="report_status_enum"), default="pending", nullable=False)
    sent_via_email = Column(Boolean, default=False, nullable=False)
    sent_via_sms = Column(Boolean, default=False, nullable=False)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False)
    sent_at = Column(UTCDateTime, nullable=True)
    __table_args__ = (UniqueConstraint("user_id", "idempotency_key", name="uq_report_user_idempotency"),)


class NotificationDelivery(Base):
    __tablename__ = "notification_deliveries"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    report_id = Column(UUIDString, ForeignKey("dietitian_reports.id", ondelete="CASCADE"), nullable=False, index=True)
    channel = Column(Enum("email", "sms", name="notification_channel_enum"), nullable=False)
    status = Column(Enum("sent", "failed", "skipped", name="notification_status_enum"), nullable=False)
    provider_message_id = Column(String(255), nullable=True)
    error_code = Column(String(64), nullable=True)
    attempted_at = Column(UTCDateTime, default=utc_now, nullable=False)
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
    submitted_at = Column(UTCDateTime, default=utc_now, nullable=False, index=True)


class UsabilitySession(Base):
    __tablename__ = "usability_sessions"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    participant_pseudonym = Column(UUIDString, nullable=False, index=True)
    session_date = Column(UTCDateTime, default=utc_now, nullable=False)
    general_note = Column(String(1000), nullable=True)
    success_rate = Column(Float, nullable=True)
    avg_task_duration = Column(Float, nullable=True)
    created_at = Column(UTCDateTime, default=utc_now, nullable=False)


class UsabilityTask(Base):
    __tablename__ = "usability_tasks"

    id = Column(UUIDString, primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = Column(UUIDString, ForeignKey("usability_sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    task_key = Column(String(64), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(String(1000), nullable=True)
    status = Column(String(32), nullable=False)
    started_at = Column(UTCDateTime, nullable=True)
    ended_at = Column(UTCDateTime, nullable=True)
    duration_seconds = Column(Float, nullable=True)
    is_success = Column(Boolean, nullable=True)
    researcher_note = Column(String(1000), nullable=True)


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
