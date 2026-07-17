# ==============================================================================
# backend/app/models/database.py
# NutriSense — SQLAlchemy Veritabanı Modelleri
#
# MySQL tablolarını ORM ile tanımlar.
# SQL injection koruması SQLAlchemy sayesinde otomatiktir.
# ==============================================================================

import uuid
from datetime import date, datetime, timezone
from sqlalchemy import (
    create_engine, Column, String, Float, Integer, DateTime,
    Date, Text, Enum, ForeignKey, Boolean, Index,
)
from sqlalchemy.orm import (
    declarative_base, sessionmaker, relationship,
)
from sqlalchemy.pool import StaticPool
from sqlalchemy.dialects.mysql import CHAR
from ..config import get_settings

# ── Engine & Session ──
settings = get_settings()
_engine_options = {
    "pool_pre_ping": True,
    "echo": settings.debug,
}
if not settings.database_url.startswith("sqlite"):
    _engine_options.update(pool_size=10, max_overflow=20)
elif ":memory:" in settings.database_url:
    _engine_options.update(
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )

engine = create_engine(settings.database_url, **_engine_options)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def utcnow_naive() -> datetime:
    """Veritabanı DATETIME alanları için UTC, timezone-naive değer."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def get_db():
    """FastAPI dependency — her request için yeni DB session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Tüm tabloları oluşturur (ilk çalıştırmada)."""
    Base.metadata.create_all(bind=engine)


# ═══════════════════════════════════════════════════════════════════════════════
# KULLANICI TABLOSU
# ═══════════════════════════════════════════════════════════════════════════════

class User(Base):
    """Kullanıcı tablosu."""
    __tablename__ = "users"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    phone = Column(String(20), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow_naive)
    updated_at = Column(DateTime, default=utcnow_naive, onupdate=utcnow_naive)

    # Tercihler
    daily_calorie_target = Column(Float, default=2000.0)
    preferred_language = Column(String(10), default="tr-TR")
    tts_speed = Column(Float, default=0.5)
    high_contrast = Column(Boolean, default=True)

    # İlişkiler
    food_logs = relationship("FoodLog", back_populates="user", cascade="all, delete-orphan")
    dietitian_id = Column(CHAR(36), ForeignKey("dietitians.id"), nullable=True)
    dietitian = relationship("Dietitian", back_populates="patients")


# ═══════════════════════════════════════════════════════════════════════════════
# BESİN KAYDI TABLOSU
# ═══════════════════════════════════════════════════════════════════════════════

class FoodLog(Base):
    """Besin tüketim kaydı tablosu."""
    __tablename__ = "food_logs"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), ForeignKey("users.id"), nullable=False, index=True)
    food_name = Column(String(255), nullable=False)
    food_name_tr = Column(String(255), nullable=False)

    # Kalori & Besin değerleri
    calories_per_100g = Column(Float, nullable=False)
    estimated_portion_g = Column(Float, nullable=False)
    total_calories = Column(Float, nullable=False)
    protein = Column(Float, default=0.0)
    carbs = Column(Float, default=0.0)
    fat = Column(Float, default=0.0)
    fiber = Column(Float, default=0.0)

    # Meta
    confidence = Column(Float, default=0.0)
    meal_type = Column(
        Enum("kahvalti", "ogle", "aksam", "atistirmalik", name="meal_type_enum"),
        default="atistirmalik",
    )
    recognition_source = Column(
        Enum("google_vision", "tflite", "manual", name="recognition_source_enum"),
        default="google_vision",
    )
    image_url = Column(Text, nullable=True)

    # Zaman
    logged_at = Column(DateTime, default=utcnow_naive, index=True)
    log_date = Column(Date, default=date.today, index=True)

    # İlişkiler
    user = relationship("User", back_populates="food_logs")

    # Performans indeksleri
    __table_args__ = (
        Index("idx_user_date", "user_id", "log_date"),
        Index("idx_user_meal", "user_id", "meal_type"),
    )


# ═══════════════════════════════════════════════════════════════════════════════
# DİYETİSYEN TABLOSU
# ═══════════════════════════════════════════════════════════════════════════════

class Dietitian(Base):
    """Diyetisyen bilgileri tablosu."""
    __tablename__ = "dietitians"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, nullable=False)
    full_name = Column(String(255), nullable=False)
    phone = Column(String(20), nullable=True)
    email_verified = Column(Boolean, default=False, nullable=False)
    phone_verified = Column(Boolean, default=False, nullable=False)
    specialization = Column(String(255), default="Beslenme ve Diyet")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow_naive)

    # İlişkiler
    patients = relationship("User", back_populates="dietitian")


class DietitianAssignment(Base):
    """Kullanıcının doğrulanmış diyetisyene açık rıza ile atama kaydı."""

    __tablename__ = "dietitian_assignments"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), ForeignKey("users.id"), nullable=False, index=True)
    dietitian_id = Column(
        CHAR(36), ForeignKey("dietitians.id"), nullable=False, index=True
    )
    status = Column(
        Enum("pending", "approved", "cancelled", name="assignment_status_enum"),
        default="pending",
        nullable=False,
    )
    created_at = Column(DateTime, default=utcnow_naive, nullable=False)
    approved_at = Column(DateTime, nullable=True)
    cancelled_at = Column(DateTime, nullable=True)


# ═══════════════════════════════════════════════════════════════════════════════
# DİYETİSYEN RAPOR TABLOSU
# ═══════════════════════════════════════════════════════════════════════════════

class DietitianReport(Base):
    """Diyetisyene gönderilen rapor kaydı."""
    __tablename__ = "dietitian_reports"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), ForeignKey("users.id"), nullable=False)
    dietitian_id = Column(CHAR(36), ForeignKey("dietitians.id"), nullable=False)
    report_type = Column(
        Enum("daily", "weekly", "monthly", name="report_type_enum"),
        default="weekly",
    )
    date_from = Column(Date, nullable=False)
    date_to = Column(Date, nullable=False)
    total_calories = Column(Float, default=0.0)
    total_meals = Column(Integer, default=0)
    sent_via_email = Column(Boolean, default=False)
    sent_via_sms = Column(Boolean, default=False)
    sent_at = Column(DateTime, default=utcnow_naive)


class RefreshToken(Base):
    """Rotating refresh token kaydı; ham token hiçbir zaman saklanmaz."""

    __tablename__ = "refresh_tokens"

    jti = Column(CHAR(36), primary_key=True)
    user_id = Column(CHAR(36), ForeignKey("users.id"), nullable=False, index=True)
    token_hash = Column(String(64), nullable=False, unique=True)
    expires_at = Column(DateTime, nullable=False, index=True)
    created_at = Column(DateTime, default=utcnow_naive, nullable=False)
    revoked_at = Column(DateTime, nullable=True)
    replaced_by_jti = Column(CHAR(36), nullable=True)


class AuthAuditLog(Base):
    """Kimlik olayları; e-posta yerine geri döndürülemez hash saklar."""

    __tablename__ = "auth_audit_logs"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), nullable=True, index=True)
    event = Column(String(64), nullable=False, index=True)
    email_hash = Column(String(64), nullable=True)
    ip_address = Column(String(64), nullable=True)
    success = Column(Boolean, nullable=False)
    reason = Column(String(128), nullable=True)
    created_at = Column(DateTime, default=utcnow_naive, nullable=False, index=True)
