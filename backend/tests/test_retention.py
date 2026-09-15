"""Periyodik imha: süresi dolan kayıtlar silinir, yenileri kalır, imha kaydı yazılır."""

import uuid
from datetime import timedelta

from app.config import get_settings
from app.domain.retention import PURGE_EVENT, purge_expired_personal_data
from app.models.database import (
    AuditEvent,
    PasswordResetToken,
    PendingRegistration,
    RecognitionAttempt,
    RefreshToken,
    SessionLocal,
    User,
    utc_now,
)


def _user(db):
    user = User(
        id=str(uuid.uuid4()),
        email=f"{uuid.uuid4().hex}@example.invalid",
        hashed_password="not-a-real-hash",
        full_name="Sentetik Kullanıcı",
    )
    db.add(user)
    db.flush()
    return user


def test_purge_removes_expired_records_and_keeps_recent_ones():
    now = utc_now()
    recent = now - timedelta(days=1)
    db = SessionLocal()
    try:
        user = _user(db)
        db.add_all([
            AuditEvent(event="login", success=True, ip_address="203.0.113.7",
                       created_at=now - timedelta(days=400)),
            AuditEvent(event="login", success=True, ip_address="203.0.113.8",
                       created_at=now - timedelta(days=120)),
            AuditEvent(event="login", success=True, ip_address="203.0.113.9",
                       created_at=recent),
            RefreshToken(jti=str(uuid.uuid4()), user_id=user.id, token_hash="a" * 64,
                         expires_at=now - timedelta(days=30)),
            RefreshToken(jti=str(uuid.uuid4()), user_id=user.id, token_hash="b" * 64,
                         expires_at=now + timedelta(days=10)),
            PasswordResetToken(user_id=user.id, token_hash="c" * 64,
                               expires_at=now - timedelta(days=30)),
            RecognitionAttempt(user_id=user.id, provider="tflite", status="succeeded",
                               created_at=now - timedelta(days=30)),
            RecognitionAttempt(user_id=user.id, provider="tflite", status="succeeded",
                               created_at=recent),
            PendingRegistration(email="bekleyen@example.invalid", hashed_password="x",
                                full_name="Sentetik", code_hash="d" * 64,
                                expires_at=now - timedelta(minutes=1)),
            PendingRegistration(email="yeni@example.invalid", hashed_password="x",
                                full_name="Sentetik", code_hash="e" * 64,
                                expires_at=now + timedelta(minutes=20)),
        ])
        db.commit()

        counts = purge_expired_personal_data(db, get_settings(), now=now)

        assert counts == {
            "audit_events_deleted": 1,
            "audit_ip_addresses_cleared": 1,
            "refresh_tokens_deleted": 1,
            "password_reset_tokens_deleted": 1,
            "pending_recognitions_deleted": 1,
            "pending_registrations_deleted": 1,
        }
        assert db.query(PendingRegistration).one().email == "yeni@example.invalid"
        remaining_ips = sorted(
            event.ip_address or ""
            for event in db.query(AuditEvent).filter(AuditEvent.event == "login")
        )
        assert remaining_ips == ["", "203.0.113.9"]
        assert db.query(RefreshToken).count() == 1
        assert db.query(PasswordResetToken).count() == 0
        assert db.query(RecognitionAttempt).count() == 1
        record = db.query(AuditEvent).filter(AuditEvent.event == PURGE_EVENT).one()
        assert record.metadata_json == counts
        assert record.user_id is None and record.ip_address is None
    finally:
        db.close()


def test_purge_records_are_kept():
    now = utc_now()
    db = SessionLocal()
    try:
        db.add(AuditEvent(event=PURGE_EVENT, actor_type="system", success=True,
                          created_at=now - timedelta(days=900)))
        db.commit()
        purge_expired_personal_data(db, get_settings(), now=now)
        assert db.query(AuditEvent).filter(AuditEvent.event == PURGE_EVENT).count() == 2
    finally:
        db.close()
