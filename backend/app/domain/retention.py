"""Süresi dolan kişisel verinin periyodik imhası.

KVKK imha yönetmeliği periyodik imha aralığının altı ayı geçmemesini ve imha
işlemlerinin kaydının tutulmasını ister. Bu modül kuralı uygular; çalıştırma
takvimi işletim tarafındadır (``scripts/purge_expired_data.py``).
"""

from datetime import timedelta

from sqlalchemy import or_

from ..models.database import (
    AuditEvent,
    FoodLog,
    PasswordResetToken,
    RecognitionAttempt,
    RefreshToken,
    utc_now,
)

PURGE_EVENT = "retention_purge"


def purge_expired_personal_data(db, settings, now=None) -> dict[str, int]:
    """Süresi dolan kayıtları siler, IP adreslerini boşaltır ve imha kaydı yazar.

    İmha kaydının kendisi kişisel veri taşımaz ve bu işlemle silinmez; imha
    kayıtları en az üç yıl saklanır.
    """
    now = now or utc_now()
    ip_cutoff = now - timedelta(days=settings.audit_ip_retention_days)
    audit_cutoff = now - timedelta(days=settings.audit_event_retention_days)
    stale_cutoff = now - timedelta(days=settings.stale_record_retention_days)

    counts = {}
    counts["audit_events_deleted"] = db.query(AuditEvent).filter(
        AuditEvent.created_at < audit_cutoff,
        AuditEvent.event != PURGE_EVENT,
    ).delete(synchronize_session=False)
    counts["audit_ip_addresses_cleared"] = db.query(AuditEvent).filter(
        AuditEvent.created_at < ip_cutoff,
        AuditEvent.ip_address.is_not(None),
    ).update({AuditEvent.ip_address: None}, synchronize_session=False)
    counts["refresh_tokens_deleted"] = db.query(RefreshToken).filter(
        or_(RefreshToken.expires_at < stale_cutoff, RefreshToken.revoked_at < stale_cutoff),
    ).delete(synchronize_session=False)
    counts["password_reset_tokens_deleted"] = db.query(PasswordResetToken).filter(
        or_(
            PasswordResetToken.expires_at < stale_cutoff,
            PasswordResetToken.used_at < stale_cutoff,
        ),
    ).delete(synchronize_session=False)
    # Karara bağlanmamış tanıma denemesi besin adı ve analiz sonucu taşır;
    # bir günlük kaydına bağlı olan deneme günlükle birlikte yaşar.
    linked_to_log = db.query(FoodLog.id).filter(
        FoodLog.recognition_attempt_id == RecognitionAttempt.id
    ).exists()
    counts["pending_recognitions_deleted"] = db.query(RecognitionAttempt).filter(
        RecognitionAttempt.decided_at.is_(None),
        RecognitionAttempt.created_at < stale_cutoff,
        ~linked_to_log,
    ).delete(synchronize_session=False)

    db.add(AuditEvent(
        actor_type="system",
        event=PURGE_EVENT,
        success=True,
        reason="periodic_retention",
        metadata_json=counts,
    ))
    db.commit()
    return counts
