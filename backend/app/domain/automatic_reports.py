"""Opt-in, event-driven reports for verified notification channels."""
import hashlib
import json
import uuid

from fastapi import HTTPException

from ..models.database import ConsentRecord, DietitianReport, NotificationDelivery
from .report_delivery import build_report_payload, consent_context_hash, verified_recipients

PURPOSE = "automatic_food_share"
# Detailed email/SMS disclosure requires a fresh opt-in from every user.
POLICY = "automatic-detailed-channels-v3"


def local_delivery_only(settings):
    return (
        settings.app_environment.lower() in {"local", "dev", "development", "test"}
        and settings.notification_mode == "sandbox"
        and settings.smtp_host.lower() in {"mailpit", "localhost", "127.0.0.1"}
        and settings.sms_provider_mode == "local_outbox"
    )


def automatic_delivery_available(settings, dietitian=None):
    """Require both selected providers and sandbox recipient controls."""
    if settings.notification_mode not in {"sandbox", "production"}:
        return False
    local_email = (
        settings.app_environment.lower() in {"local", "dev", "development", "test"}
        and settings.smtp_host.lower() in {"mailpit", "localhost", "127.0.0.1"}
    )
    email_ready = bool(
        settings.smtp_from_email
        and (
            local_email
            or (
                settings.smtp_host
                and settings.smtp_user
                and settings.smtp_password
                and (settings.smtp_use_tls or settings.smtp_start_tls)
            )
        )
    )
    sms_ready = bool(
        (
            settings.sms_provider_mode == "local_outbox"
            and settings.app_environment.lower() in {"local", "dev", "development", "test"}
        )
        or (
            settings.sms_provider_mode == "twilio"
            and settings.twilio_account_sid
            and settings.twilio_auth_token
            and settings.twilio_phone_number.startswith("+")
        )
        or (
            settings.sms_provider_mode == "iletimerkezi"
            and settings.iletimerkezi_api_key
            and settings.iletimerkezi_api_hash
            and settings.iletimerkezi_sender
        )
    )
    if not (email_ready and sms_ready):
        return False
    if settings.notification_mode == "sandbox" and dietitian is not None:
        if not local_email and dietitian.email.lower() not in settings.sandbox_email_allowlist:
            return False
        local_sms = settings.sms_provider_mode == "local_outbox"
        if not local_sms and dietitian.phone not in settings.sandbox_phone_allowlist:
            return False
    return True


def recipient_digest(dietitian, assignment):
    return hashlib.sha256(json.dumps([
        str(assignment.id), dietitian.email, dietitian.phone,
    ], ensure_ascii=False).encode()).hexdigest()


def active_consent(db, user, dietitian, assignment):
    return db.query(ConsentRecord).filter(
        ConsentRecord.user_id == user.id,
        ConsentRecord.assignment_id == assignment.id,
        ConsentRecord.consent_type == PURPOSE,
        ConsentRecord.policy_version == POLICY,
        ConsentRecord.granted.is_(True),
        ConsentRecord.revoked_at.is_(None),
        ConsentRecord.context_hash == recipient_digest(dietitian, assignment),
    ).first()


def queue_automatic_report(db, user, log, dietitian, assignment, settings):
    if not automatic_delivery_available(settings, dietitian):
        return None
    consent = active_consent(db, user, dietitian, assignment)
    if consent is None:
        return None
    verified_recipients(dietitian, ["email", "sms"])
    # Flush food defaults (timestamps, confirmation flag) in the same transaction.
    db.flush()
    payload = build_report_payload(
        user=user, dietitian=dietitian, assignment=assignment,
        report_type="daily", from_date=log.log_date, to_date=log.log_date,
        channels=["email", "sms"], logs=[log],
    )
    payload["_automatic_share"] = {
        "consent_id": str(consent.id), "recipient_digest": consent.context_hash,
    }
    report = DietitianReport(
        id=str(uuid.uuid4()), user_id=user.id, dietitian_id=dietitian.id,
        idempotency_key=f"automatic-food-{log.id}",
        consent_context_hash=consent_context_hash(payload),
        channels_json=payload["channels"], recipient_snapshot_json=payload["recipients"],
        payload_json=payload, report_type="daily", date_from=log.log_date,
        date_to=log.log_date, total_calories=payload["total_calories"],
        total_meals=1, record_count=1, status="queued",
    )
    db.add(report)
    for channel in payload["channels"]:
        db.add(NotificationDelivery(
            report_id=report.id, channel=channel, status="queued",
            destination_masked=payload["recipients"][channel], attempt_count=0, max_attempts=3,
        ))
    return report


def guard_automatic_delivery(db, report, dietitian, settings):
    marker = (report.payload_json or {}).get("_automatic_share")
    if not marker:
        return
    consent = db.get(ConsentRecord, marker["consent_id"])
    from ..models.database import DietitianAssignment, User, FoodLog
    assignment = db.get(DietitianAssignment, consent.assignment_id) if consent else None
    user = db.get(User, report.user_id)
    if (
        not automatic_delivery_available(settings, dietitian) or consent is None
        or not consent.granted or consent.revoked_at is not None
        or assignment is None or assignment.status != "approved"
        or user is None or user.dietitian_id != report.dietitian_id
        or dietitian.id != report.dietitian_id
        or recipient_digest(dietitian, assignment) != marker["recipient_digest"]
    ):
        raise HTTPException(409, "Otomatik gönderim kapalı veya paylaşım izni değişmiş.")
    verified_recipients(dietitian, ["email", "sms"])
    for record in report.payload_json.get("records", []):
        log = db.get(FoodLog, record["log_id"])
        if log is None or log.deleted_at is not None:
            raise HTTPException(409, "Geri alınmış veya silinmiş besin otomatik gönderilemez.")
