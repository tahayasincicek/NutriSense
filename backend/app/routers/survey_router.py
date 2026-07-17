"""Database-backed, pseudonymous research data endpoints."""

import hmac
from datetime import datetime, timezone
from typing import Any, Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.orm import Session

from ..config import get_settings
from ..models.database import (
    AuditEvent,
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
    answers: list[SurveyAnswerSchema] = Field(min_length=1, max_length=100)
    completion_seconds: Optional[int] = Field(default=None, ge=0, le=86400)
    device_info: Optional[str] = Field(default=None, max_length=255)
    submitted_at: Optional[datetime] = None


class SurveyResponseSchema(BaseModel):
    success: bool
    message: str
    survey_id: UUID


class UsabilityTaskSchema(BaseModel):
    id: str = Field(min_length=1, max_length=64)
    title: str = Field(min_length=1, max_length=255)
    description: Optional[str] = Field(default=None, max_length=1000)
    status: str = Field(min_length=1, max_length=32)
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    duration_seconds: Optional[float] = Field(default=None, ge=0)
    is_success: Optional[bool] = None
    researcher_note: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Doğrudan kişisel veri yazmayın.",
    )


class UsabilitySessionSchema(BaseModel):
    id: Optional[UUID] = None
    participant_id: UUID = Field(description="Hesap UUID'sinden bağımsız rastgele pseudonym")
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


@router.post("/survey", response_model=SurveyResponseSchema)
async def submit_survey(
    submission: SurveySubmissionSchema,
    db: Session = Depends(get_db),
):
    survey_id = submission.id or uuid4()
    version = _survey_version(db, submission.survey_version)
    record = SurveySubmission(
        id=str(survey_id),
        participant_pseudonym=str(submission.participant_id),
        survey_version_id=version.id,
        answers_json=[answer.model_dump(mode="json") for answer in submission.answers],
        completion_seconds=submission.completion_seconds,
        device_info=submission.device_info,
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
    submissions = db.query(SurveySubmission).all()
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


@router.post("/usability", response_model=UsabilityResponseSchema)
async def submit_usability_session(
    session: UsabilitySessionSchema,
    db: Session = Depends(get_db),
):
    session_id = session.id or uuid4()
    record = UsabilitySession(
        id=str(session_id),
        participant_pseudonym=str(session.participant_id),
        session_date=_aware_utc(session.session_date),
        general_note=session.general_note,
        success_rate=session.success_rate,
        avg_task_duration=session.avg_task_duration,
    )
    try:
        db.add(record)
        db.flush()
        for task in session.tasks:
            db.add(
                UsabilityTask(
                    session_id=record.id,
                    task_key=task.id,
                    title=task.title,
                    description=task.description,
                    status=task.status,
                    started_at=_aware_utc(task.start_time) if task.start_time else None,
                    ended_at=_aware_utc(task.end_time) if task.end_time else None,
                    duration_seconds=task.duration_seconds,
                    is_success=task.is_success,
                    researcher_note=task.researcher_note,
                )
            )
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
                "session_date": session.session_date.isoformat(),
                "general_note": session.general_note,
                "success_rate": session.success_rate,
                "avg_task_duration": session.avg_task_duration,
                "tasks": [
                    {
                        "id": task.task_key,
                        "title": task.title,
                        "description": task.description,
                        "status": task.status,
                        "start_time": task.started_at.isoformat() if task.started_at else None,
                        "end_time": task.ended_at.isoformat() if task.ended_at else None,
                        "duration_seconds": task.duration_seconds,
                        "is_success": task.is_success,
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
