"""Database-backed, pseudonymous research data endpoints."""

import hashlib
import hmac
import secrets
from datetime import datetime, timezone
from typing import Any, Literal, Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.orm import Session

from ..config import get_settings
from ..models.database import (
    AuditEvent,
    ResearchConsent,
    SurveySubmission,
    SurveyVersion,
    UsabilitySession,
    UsabilityTask,
    get_db,
    utc_now,
)

router = APIRouter(prefix="/api/v1", tags=["Anket"])
settings = get_settings()
DEFAULT_SURVEY_VERSION = "1.0"
MAX_FREE_TEXT_LENGTH = 1000
SYNTHETIC_PROTOCOL = "synthetic-development-only"
SYNTHETIC_APPROVAL = "NOT-AN-ETHICS-APPROVAL"
ASSISTANCE_LEVELS = {"none", "prompt", "partial", "full"}


def _hash_withdrawal_code(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _collection_context(data_origin: str, protocol_version: str = "") -> tuple[str, str]:
    """Return server-controlled protocol context or reject collection."""
    if data_origin == "synthetic":
        if settings.research_mode not in {"synthetic", "approved"}:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Sentetik araştırma veri toplama modu kapalı.",
            )
        return SYNTHETIC_PROTOCOL, SYNTHETIC_APPROVAL

    if settings.research_mode != "approved":
        raise HTTPException(
            status_code=status.HTTP_451_UNAVAILABLE_FOR_LEGAL_REASONS,
            detail="Etik kurul onayı doğrulanmadan gerçek katılımcı verisi toplanamaz.",
        )
    try:
        settings.validate_security()
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_451_UNAVAILABLE_FOR_LEGAL_REASONS,
            detail="Araştırma onay kapısı yapılandırılmamış.",
        ) from exc
    if protocol_version != settings.research_protocol_version:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="İstemci protokol sürümü etkin araştırma protokolüyle eşleşmiyor.",
        )
    return settings.research_protocol_version, settings.research_approval_reference


def _active_consent(
    db: Session,
    participant_id: UUID,
    protocol_version: str,
    data_origin: str,
) -> ResearchConsent:
    consent = db.query(ResearchConsent).filter(
        ResearchConsent.participant_pseudonym == str(participant_id),
        ResearchConsent.protocol_version == protocol_version,
        ResearchConsent.data_origin == data_origin,
        ResearchConsent.withdrawn_at.is_(None),
    ).first()
    if consent is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu protokol için etkin araştırma onamı bulunamadı.",
        )
    return consent


def require_research_export_token(
    x_research_export_token: Optional[str] = Header(default=None),
):
    expected = settings.research_export_token
    if not expected or not x_research_export_token or not hmac.compare_digest(
        expected, x_research_export_token
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Araştırma verisi dışa aktarma yetkisi gerekli.",
        )


def _aware_utc(value: Optional[datetime]) -> datetime:
    if value is None:
        return utc_now()
    if value.tzinfo is None:
        raise ValueError("Tarih/saat UTC offset bilgisi içermelidir.")
    return value.astimezone(timezone.utc)


def _validate_answer(value: Any) -> Any:
    if isinstance(value, str) and len(value) > MAX_FREE_TEXT_LENGTH:
        raise ValueError(f"Açık uçlu yanıt en fazla {MAX_FREE_TEXT_LENGTH} karakter olabilir.")
    if isinstance(value, list):
        for item in value:
            _validate_answer(item)
    return value


class SurveyAnswerSchema(BaseModel):
    question_id: str = Field(min_length=1, max_length=64)
    answer: str | int | float | bool | list | None = Field(
        default=None,
        description="Ad, e-posta, telefon veya başka doğrudan kişisel veri yazmayın.",
    )
    timestamp: Optional[datetime] = None

    @field_validator("answer")
    @classmethod
    def limit_free_text(cls, value):
        return _validate_answer(value)


class SurveySubmissionSchema(BaseModel):
    id: Optional[UUID] = None
    participant_id: UUID = Field(description="Hesap UUID'sinden bağımsız rastgele pseudonym")
    survey_version: str = Field(default=DEFAULT_SURVEY_VERSION, max_length=32)
    protocol_version: str = Field(default="", max_length=64)
    data_origin: Literal["synthetic", "participant"] = "synthetic"
    answers: list[SurveyAnswerSchema] = Field(min_length=1, max_length=100)
    completion_seconds: Optional[int] = Field(default=None, ge=0, le=86400)
    device_info: Optional[str] = Field(default=None, max_length=255)
    submitted_at: Optional[datetime] = None


class SurveyResponseSchema(BaseModel):
    success: bool
    message: str
    survey_id: UUID
    duplicate: bool = False


class UsabilityTaskSchema(BaseModel):
    id: str = Field(min_length=1, max_length=64)
    condition: Literal["nutrisense", "standardized_assistance"] = "nutrisense"
    title: str = Field(min_length=1, max_length=255)
    description: Optional[str] = Field(default=None, max_length=1000)
    status: str = Field(min_length=1, max_length=32)
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    duration_seconds: Optional[float] = Field(default=None, ge=0)
    is_success: Optional[bool] = None
    error_count: int = Field(default=0, ge=0, le=1000)
    assistance_level: Literal["none", "prompt", "partial", "full"] = "none"
    abort_reason: Optional[str] = Field(default=None, max_length=255)
    timing_source: Literal["monotonic", "manual"] = "monotonic"
    manually_edited: bool = False
    edit_reason: Optional[str] = Field(default=None, max_length=255)
    researcher_note: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Doğrudan kişisel veri yazmayın.",
    )


class UsabilitySessionSchema(BaseModel):
    id: Optional[UUID] = None
    participant_id: UUID = Field(description="Hesap UUID'sinden bağımsız rastgele pseudonym")
    schema_version: str = Field(default="1.0", max_length=32)
    counterbalance_sequence: Optional[Literal["AB", "BA"]] = None
    protocol_version: str = Field(default="", max_length=64)
    data_origin: Literal["synthetic", "participant"] = "synthetic"
    session_date: Optional[datetime] = None
    tasks: list[UsabilityTaskSchema] = Field(min_length=1, max_length=100)
    general_note: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Doğrudan kişisel veri yazmayın.",
    )
    success_rate: Optional[float] = Field(default=None, ge=0, le=100)
    avg_task_duration: Optional[float] = Field(default=None, ge=0)


class UsabilityResponseSchema(BaseModel):
    success: bool
    message: str
    session_id: UUID
    duplicate: bool = False


class ResearchConsentCreateSchema(BaseModel):
    data_origin: Literal["synthetic", "participant"] = "synthetic"
    protocol_version: str = Field(default="", max_length=64)
    consent_version: str = Field(default="", max_length=64)
    consent_method: Literal["signed", "witnessed_verbal", "recorded_verbal"]
    evidence_reference: Optional[str] = Field(default=None, max_length=255)
    witness_reference: Optional[str] = Field(default=None, max_length=255)


class ResearchConsentResponseSchema(BaseModel):
    participant_id: UUID
    protocol_version: str
    consent_version: str
    withdrawal_code: str = Field(
        description="Yalnız bu yanıtta gösterilir; araştırma sonucuna yazılmaz."
    )


class ResearchWithdrawalSchema(BaseModel):
    participant_id: UUID
    withdrawal_code: str = Field(min_length=12, max_length=128)


class ResearchWithdrawalResponseSchema(BaseModel):
    withdrawn: bool
    deleted_survey_submissions: int
    deleted_usability_sessions: int


def _survey_version(db: Session, version_name: str) -> SurveyVersion:
    version = db.query(SurveyVersion).filter(SurveyVersion.version == version_name).first()
    if version is None or not version.is_active:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Aktif anket sürümü bulunamadı.",
        )
    return version


def _audit_export(db: Session, event: str, record_count: int) -> None:
    db.add(
        AuditEvent(
            actor_type="researcher",
            event=event,
            success=True,
            metadata_json={"record_count": record_count},
        )
    )


@router.post("/research/consents", response_model=ResearchConsentResponseSchema)
async def create_research_consent(
    request: ResearchConsentCreateSchema,
    db: Session = Depends(get_db),
):
    protocol_version, approval_reference = _collection_context(
        request.data_origin, request.protocol_version
    )
    consent_version = (
        "synthetic-consent"
        if request.data_origin == "synthetic"
        else settings.research_consent_version
    )
    if request.data_origin == "participant" and request.consent_version != consent_version:
        raise HTTPException(status_code=409, detail="Onam formu sürümü etkin sürümle eşleşmiyor.")
    if request.consent_method == "witnessed_verbal" and not request.witness_reference:
        raise HTTPException(status_code=422, detail="Tanıklı sözlü onam için tanık referansı gerekir.")
    if request.consent_method == "recorded_verbal":
        if request.data_origin == "synthetic" or not settings.research_audio_consent_approved:
            raise HTTPException(
                status_code=451,
                detail="Sesli onam kaydı etik kurulda ayrıca onaylanmamıştır.",
            )
        if not request.evidence_reference:
            raise HTTPException(status_code=422, detail="Kayıt kanıt referansı gerekir.")

    participant_id = uuid4()
    withdrawal_code = secrets.token_urlsafe(18)
    consent = ResearchConsent(
        participant_pseudonym=str(participant_id),
        protocol_version=protocol_version,
        consent_version=consent_version,
        approval_reference=approval_reference,
        consent_method=request.consent_method,
        evidence_reference=request.evidence_reference,
        witness_reference=request.witness_reference,
        withdrawal_code_hash=_hash_withdrawal_code(withdrawal_code),
        data_origin=request.data_origin,
    )
    db.add(consent)
    db.add(AuditEvent(
        actor_type="researcher",
        event="research_consent_recorded",
        success=True,
        metadata_json={
            "participant_id": str(participant_id),
            "protocol_version": protocol_version,
            "data_origin": request.data_origin,
            "consent_method": request.consent_method,
        },
    ))
    db.commit()
    return ResearchConsentResponseSchema(
        participant_id=participant_id,
        protocol_version=protocol_version,
        consent_version=consent_version,
        withdrawal_code=withdrawal_code,
    )


@router.post("/research/withdraw", response_model=ResearchWithdrawalResponseSchema)
async def withdraw_research_data(
    request: ResearchWithdrawalSchema,
    db: Session = Depends(get_db),
):
    consent = db.query(ResearchConsent).filter(
        ResearchConsent.participant_pseudonym == str(request.participant_id)
    ).first()
    supplied_hash = _hash_withdrawal_code(request.withdrawal_code)
    if consent is None or not hmac.compare_digest(consent.withdrawal_code_hash, supplied_hash):
        raise HTTPException(status_code=404, detail="Geri çekilme bilgileri doğrulanamadı.")
    if consent.withdrawn_at is not None:
        return ResearchWithdrawalResponseSchema(
            withdrawn=True,
            deleted_survey_submissions=0,
            deleted_usability_sessions=0,
        )

    survey_count = db.query(SurveySubmission).filter(
        SurveySubmission.participant_pseudonym == str(request.participant_id)
    ).delete(synchronize_session=False)
    session_ids = [row[0] for row in db.query(UsabilitySession.id).filter(
        UsabilitySession.participant_pseudonym == str(request.participant_id)
    ).all()]
    if session_ids:
        db.query(UsabilityTask).filter(UsabilityTask.session_id.in_(session_ids)).delete(
            synchronize_session=False
        )
    session_count = db.query(UsabilitySession).filter(
        UsabilitySession.participant_pseudonym == str(request.participant_id)
    ).delete(synchronize_session=False)
    consent.withdrawn_at = utc_now()
    consent.evidence_reference = None
    consent.witness_reference = None
    db.add(AuditEvent(
        actor_type="participant",
        event="research_participation_withdrawn",
        success=True,
        metadata_json={
            "participant_id": str(request.participant_id),
            "survey_records_deleted": survey_count,
            "usability_sessions_deleted": session_count,
        },
    ))
    db.commit()
    return ResearchWithdrawalResponseSchema(
        withdrawn=True,
        deleted_survey_submissions=survey_count,
        deleted_usability_sessions=session_count,
    )


@router.post("/survey", response_model=SurveyResponseSchema)
async def submit_survey(
    submission: SurveySubmissionSchema,
    db: Session = Depends(get_db),
    idempotency_key: Optional[str] = Header(default=None, alias="Idempotency-Key"),
):
    survey_id = submission.id or uuid4()
    protocol_version, approval_reference = _collection_context(
        submission.data_origin, submission.protocol_version
    )
    if submission.data_origin == "participant":
        _active_consent(db, submission.participant_id, protocol_version, submission.data_origin)
    request_key = idempotency_key if isinstance(idempotency_key, str) else str(survey_id)
    existing = db.query(SurveySubmission).filter(
        SurveySubmission.participant_pseudonym == str(submission.participant_id),
        SurveySubmission.idempotency_key == request_key,
    ).first()
    if existing:
        return SurveyResponseSchema(
            success=True,
            message="Anket daha önce kaydedildi.",
            survey_id=UUID(existing.id),
            duplicate=True,
        )
    version = _survey_version(db, submission.survey_version)
    record = SurveySubmission(
        id=str(survey_id),
        participant_pseudonym=str(submission.participant_id),
        survey_version_id=version.id,
        answers_json=[answer.model_dump(mode="json") for answer in submission.answers],
        completion_seconds=submission.completion_seconds,
        device_info=submission.device_info,
        protocol_version=protocol_version,
        approval_reference=approval_reference,
        data_origin=submission.data_origin,
        idempotency_key=request_key,
        submitted_at=_aware_utc(submission.submitted_at),
    )
    try:
        db.add(record)
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Anket kaydedilemedi.")
    return SurveyResponseSchema(
        success=True,
        message="Anket yanıtlarınız başarıyla kaydedildi. Teşekkür ederiz.",
        survey_id=survey_id,
    )


@router.get("/survey/stats")
async def get_survey_stats(
    _: None = Depends(require_research_export_token),
    db: Session = Depends(get_db),
):
    submissions = db.query(SurveySubmission).filter(
        SurveySubmission.data_origin == "participant"
    ).all()
    likert_questions = ["q2", "q3", "q4", "q8"]
    averages: dict[str, dict] = {}
    for question_id in likert_questions:
        values = [
            answer["answer"]
            for submission in submissions
            for answer in submission.answers_json
            if answer.get("question_id") == question_id
            and isinstance(answer.get("answer"), (int, float))
        ]
        if values:
            averages[question_id] = {
                "average": round(sum(values) / len(values), 2),
                "count": len(values),
                "min": min(values),
                "max": max(values),
            }
    durations = [item.completion_seconds for item in submissions if item.completion_seconds]
    q5_counts = {"Evet": 0, "Hayır": 0, "Belki": 0}
    for submission in submissions:
        for answer in submission.answers_json:
            if answer.get("question_id") == "q5" and str(answer.get("answer")) in q5_counts:
                q5_counts[str(answer["answer"])] += 1

    _audit_export(db, "survey_stats_exported", len(submissions))
    db.commit()
    return {
        "total_responses": len(submissions),
        "likert_averages": averages,
        "avg_completion_seconds": round(sum(durations) / len(durations), 1) if durations else 0,
        "q5_distribution": q5_counts,
    }


@router.get("/survey/export/tidy")
async def export_survey_tidy(
    _: None = Depends(require_research_export_token),
    db: Session = Depends(get_db),
):
    """One row per answer; directly consumable by R, pandas or jamovi."""
    rows = []
    submissions = db.query(SurveySubmission).all()
    versions = {item.id: item.version for item in db.query(SurveyVersion).all()}
    for submission in submissions:
        for answer in submission.answers_json:
            rows.append({
                "submission_id": submission.id,
                "participant_id": submission.participant_pseudonym,
                "protocol_version": submission.protocol_version,
                "approval_reference": submission.approval_reference,
                "survey_version": versions.get(submission.survey_version_id),
                "data_origin": submission.data_origin,
                "question_id": answer.get("question_id"),
                "answer": answer.get("answer"),
                "answered_at": answer.get("timestamp"),
                "completion_seconds": submission.completion_seconds,
                "submitted_at": submission.submitted_at.isoformat(),
            })
    _audit_export(db, "survey_tidy_exported", len(rows))
    db.commit()
    return {"schema_version": "1.0", "row_count": len(rows), "rows": rows}


@router.post("/usability", response_model=UsabilityResponseSchema)
async def submit_usability_session(
    session: UsabilitySessionSchema,
    db: Session = Depends(get_db),
    idempotency_key: Optional[str] = Header(default=None, alias="Idempotency-Key"),
):
    session_id = session.id or uuid4()
    protocol_version, approval_reference = _collection_context(
        session.data_origin, session.protocol_version
    )
    if session.data_origin == "participant":
        _active_consent(db, session.participant_id, protocol_version, session.data_origin)
    request_key = idempotency_key if isinstance(idempotency_key, str) else str(session_id)
    existing = db.query(UsabilitySession).filter(
        UsabilitySession.participant_pseudonym == str(session.participant_id),
        UsabilitySession.idempotency_key == request_key,
    ).first()
    if existing:
        return UsabilityResponseSchema(
            success=True,
            message="Oturum daha önce kaydedildi.",
            session_id=UUID(existing.id),
            duplicate=True,
        )
    record = UsabilitySession(
        id=str(session_id),
        participant_pseudonym=str(session.participant_id),
        session_date=_aware_utc(session.session_date),
        general_note=session.general_note,
        success_rate=session.success_rate,
        avg_task_duration=session.avg_task_duration,
        schema_version=session.schema_version,
        counterbalance_sequence=session.counterbalance_sequence,
        protocol_version=protocol_version,
        approval_reference=approval_reference,
        data_origin=session.data_origin,
        idempotency_key=request_key,
    )
    try:
        db.add(record)
        db.flush()
        for task in session.tasks:
            db.add(
                UsabilityTask(
                    session_id=record.id,
                    task_key=task.id,
                    condition=task.condition,
                    title=task.title,
                    description=task.description,
                    status=task.status,
                    started_at=_aware_utc(task.start_time) if task.start_time else None,
                    ended_at=_aware_utc(task.end_time) if task.end_time else None,
                    duration_seconds=task.duration_seconds,
                    is_success=task.is_success,
                    error_count=task.error_count,
                    assistance_level=task.assistance_level,
                    abort_reason=task.abort_reason,
                    timing_source=task.timing_source,
                    manually_edited=task.manually_edited,
                    edit_reason=task.edit_reason,
                    researcher_note=task.researcher_note,
                )
            )
            if task.manually_edited:
                if not task.edit_reason:
                    raise ValueError("Manuel düzenleme için gerekçe zorunludur.")
                db.add(AuditEvent(
                    actor_type="researcher",
                    event="usability_timing_manually_edited",
                    success=True,
                    metadata_json={
                        "session_id": str(session_id),
                        "task_id": task.id,
                        "edit_reason": task.edit_reason,
                    },
                ))
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Oturum kaydedilemedi.")
    return UsabilityResponseSchema(
        success=True,
        message="Kullanılabilirlik testi oturumu kaydedildi.",
        session_id=session_id,
    )


@router.get("/usability/export")
async def export_usability_sessions(
    _: None = Depends(require_research_export_token),
    db: Session = Depends(get_db),
):
    sessions = db.query(UsabilitySession).all()
    rows = []
    successful_tasks = 0
    total_tasks = 0
    for session in sessions:
        tasks = db.query(UsabilityTask).filter(UsabilityTask.session_id == session.id).all()
        total_tasks += len(tasks)
        successful_tasks += sum(1 for task in tasks if task.is_success)
        rows.append(
            {
                "id": session.id,
                "participant_id": session.participant_pseudonym,
                "counterbalance_sequence": session.counterbalance_sequence,
                "session_date": session.session_date.isoformat(),
                "general_note": session.general_note,
                "success_rate": session.success_rate,
                "avg_task_duration": session.avg_task_duration,
                "tasks": [
                    {
                        "id": task.task_key,
                        "condition": task.condition,
                        "title": task.title,
                        "description": task.description,
                        "status": task.status,
                        "start_time": task.started_at.isoformat() if task.started_at else None,
                        "end_time": task.ended_at.isoformat() if task.ended_at else None,
                        "duration_seconds": task.duration_seconds,
                        "is_success": task.is_success,
                        "error_count": task.error_count,
                        "assistance_level": task.assistance_level,
                        "abort_reason": task.abort_reason,
                        "timing_source": task.timing_source,
                        "manually_edited": task.manually_edited,
                        "edit_reason": task.edit_reason,
                        "researcher_note": task.researcher_note,
                    }
                    for task in tasks
                ],
            }
        )
    _audit_export(db, "usability_exported", len(sessions))
    db.commit()
    return {
        "export_date": utc_now().isoformat(),
        "total_sessions": len(sessions),
        "total_tasks": total_tasks,
        "overall_success_rate": round(successful_tasks / total_tasks * 100, 1) if total_tasks else 0,
        "sessions": rows,
    }


@router.get("/usability/export/tidy")
async def export_usability_tidy(
    _: None = Depends(require_research_export_token),
    db: Session = Depends(get_db),
):
    """One row per task with explicit assistance, error and abort fields."""
    rows = []
    sessions = db.query(UsabilitySession).all()
    for session in sessions:
        tasks = db.query(UsabilityTask).filter(UsabilityTask.session_id == session.id).all()
        for task in tasks:
            rows.append({
                "session_id": session.id,
                "participant_id": session.participant_pseudonym,
                "schema_version": session.schema_version,
                "counterbalance_sequence": session.counterbalance_sequence,
                "protocol_version": session.protocol_version,
                "approval_reference": session.approval_reference,
                "data_origin": session.data_origin,
                "session_date": session.session_date.isoformat(),
                "task_id": task.task_key,
                "condition": task.condition,
                "status": task.status,
                "started_at": task.started_at.isoformat() if task.started_at else None,
                "ended_at": task.ended_at.isoformat() if task.ended_at else None,
                "duration_seconds": task.duration_seconds,
                "success": task.is_success,
                "error_count": task.error_count,
                "assistance_level": task.assistance_level,
                "abort_reason": task.abort_reason,
                "timing_source": task.timing_source,
                "manually_edited": task.manually_edited,
                "edit_reason": task.edit_reason,
                "researcher_note": task.researcher_note,
            })
    _audit_export(db, "usability_tidy_exported", len(rows))
    db.commit()
    return {"schema_version": "1.0", "row_count": len(rows), "rows": rows}
