# ==============================================================================
# backend/app/routers/survey_router.py
# NutriSense — Anket API Endpoint'leri
#
# POST /api/v1/survey         — Anket yanıtlarını kaydet
# GET  /api/v1/survey/stats   — Anket istatistikleri (araştırmacı)
# POST /api/v1/usability      — Kullanılabilirlik testi oturumu kaydet
# GET  /api/v1/usability/export — Tüm oturumları JSON dışa aktar
# ==============================================================================

import json
from datetime import datetime
from pathlib import Path
from typing import Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel

from ..config import get_settings

router = APIRouter(prefix="/api/v1", tags=["Anket"])
settings = get_settings()


def require_research_export_token(
    x_research_export_token: Optional[str] = Header(default=None),
):
    import hmac

    expected = settings.research_export_token
    if not expected or not x_research_export_token or not hmac.compare_digest(
        expected, x_research_export_token
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Araştırma verisi dışa aktarma yetkisi gerekli.",
        )


# ═══════════════════════════════════════════════════════════════════════════════
# ŞEMALAR (Pydantic)
# ═══════════════════════════════════════════════════════════════════════════════

class SurveyAnswerSchema(BaseModel):
    """Tek soru yanıtı"""
    question_id: str
    answer: str | int | list | None
    timestamp: Optional[datetime] = None


class SurveySubmissionSchema(BaseModel):
    """Anket gönderimi"""
    id: Optional[UUID] = None
    participant_id: UUID
    answers: list[SurveyAnswerSchema]
    completion_seconds: Optional[int] = None
    device_info: Optional[str] = None
    submitted_at: Optional[datetime] = None


class SurveyResponseSchema(BaseModel):
    """Yanıt"""
    success: bool
    message: str
    survey_id: UUID


class UsabilityTaskSchema(BaseModel):
    """Kullanılabilirlik test görevi"""
    id: str
    title: str
    description: Optional[str] = None
    status: str
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    duration_seconds: Optional[float] = None
    is_success: Optional[bool] = None
    researcher_note: Optional[str] = None


class UsabilitySessionSchema(BaseModel):
    """Kullanılabilirlik test oturumu"""
    id: Optional[UUID] = None
    participant_id: str
    session_date: Optional[datetime] = None
    tasks: list[UsabilityTaskSchema]
    general_note: Optional[str] = None
    success_rate: Optional[float] = None
    avg_task_duration: Optional[float] = None


class UsabilityResponseSchema(BaseModel):
    success: bool
    message: str
    session_id: UUID


# ═══════════════════════════════════════════════════════════════════════════════
# ANKET KAYIT VERİTABANI — basit JSON storage
# ═══════════════════════════════════════════════════════════════════════════════
# Not: Gerçek üretimde bu veriler MySQL'e kaydedilir (SurveyResponse tablosu).
# Burada basitlik için in-memory + dosya tabanlı yaklaşım kullanıyoruz.

DATA_DIR = Path(__file__).parent.parent.parent / "data"
SURVEY_FILE = DATA_DIR / "survey_responses.json"
USABILITY_FILE = DATA_DIR / "usability_sessions.json"


def _ensure_data_dir():
    """Veri dizinini oluştur"""
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def _load_json(path: Path) -> list:
    """JSON dosyasından veri yükle"""
    if not path.exists():
        return []
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return []


def _save_json(path: Path, data: list):
    """Veriyi JSON dosyasına kaydet"""
    _ensure_data_dir()
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# ENDPOINT'LER
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/survey", response_model=SurveyResponseSchema)
async def submit_survey(submission: SurveySubmissionSchema):
    """
    Anket yanıtlarını kaydeder.

    İstek gövdesi:
    ```json
    {
        "participant_id": "anonim-uuid",
        "answers": [
            {"question_id": "q1", "answer": "Birinden yardım istiyordum", "timestamp": "..."},
            {"question_id": "q2", "answer": 4, "timestamp": "..."}
        ],
        "completion_seconds": 180,
        "device_info": "Android 14 | Pixel 8"
    }
    ```
    """
    try:
        survey_id = submission.id or uuid4()

        # Yanıt verisini hazırla
        record = {
            "id": str(survey_id),
            "participant_id": str(submission.participant_id),
            "answers": [a.model_dump(mode="json") for a in submission.answers],
            "completion_seconds": submission.completion_seconds,
            "device_info": submission.device_info,
            "submitted_at": (
                submission.submitted_at or datetime.now()
            ).isoformat(),
        }

        # Dosyaya kaydet
        data = _load_json(SURVEY_FILE)
        data.append(record)
        _save_json(SURVEY_FILE, data)

        return SurveyResponseSchema(
            success=True,
            message="Anket yanıtlarınız başarıyla kaydedildi. Teşekkür ederiz.",
            survey_id=survey_id,
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Anket kaydedilemedi: {str(e)}"
        )


@router.get("/survey/stats")
async def get_survey_stats(_: None = Depends(require_research_export_token)):
    """
    Araştırmacılar için anket istatistikleri.

    Döner:
    - Toplam yanıt sayısı
    - Soru bazlı ortalamalar (Likert soruları için)
    - Ortalama tamamlama süresi
    """
    data = _load_json(SURVEY_FILE)

    if not data:
        return {
            "total_responses": 0,
            "message": "Henüz anket yanıtı yok.",
        }

    total = len(data)

    # Likert ortalamalarını hesapla
    likert_questions = ["q2", "q3", "q4", "q8"]
    averages = {}

    for qid in likert_questions:
        values = []
        for survey in data:
            for ans in survey.get("answers", []):
                if ans.get("question_id") == qid and isinstance(ans.get("answer"), (int, float)):
                    values.append(ans["answer"])
        if values:
            averages[qid] = {
                "average": round(sum(values) / len(values), 2),
                "count": len(values),
                "min": min(values),
                "max": max(values),
            }

    # Ortalama tamamlama süresi
    durations = [
        s.get("completion_seconds", 0)
        for s in data
        if s.get("completion_seconds")
    ]
    avg_duration = round(sum(durations) / len(durations), 1) if durations else 0

    # Evet/Hayır dağılımı (q5)
    q5_counts = {"Evet": 0, "Hayır": 0, "Belki": 0}
    for survey in data:
        for ans in survey.get("answers", []):
            if ans.get("question_id") == "q5":
                val = str(ans.get("answer", ""))
                if val in q5_counts:
                    q5_counts[val] += 1

    return {
        "total_responses": total,
        "likert_averages": averages,
        "avg_completion_seconds": avg_duration,
        "q5_distribution": q5_counts,
    }


@router.post("/usability", response_model=UsabilityResponseSchema)
async def submit_usability_session(session: UsabilitySessionSchema):
    """
    Kullanılabilirlik testi oturumunu kaydeder.
    """
    try:
        session_id = session.id or uuid4()

        record = {
            "id": str(session_id),
            "participant_id": session.participant_id,
            "session_date": (
                session.session_date or datetime.now()
            ).isoformat(),
            "tasks": [t.model_dump() for t in session.tasks],
            "general_note": session.general_note,
            "success_rate": session.success_rate,
            "avg_task_duration": session.avg_task_duration,
        }

        data = _load_json(USABILITY_FILE)
        data.append(record)
        _save_json(USABILITY_FILE, data)

        return {
            "success": True,
            "message": "Kullanılabilirlik testi oturumu kaydedildi.",
            "session_id": session_id,
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Oturum kaydedilemedi: {str(e)}"
        )


@router.get("/usability/export")
async def export_usability_sessions(
    _: None = Depends(require_research_export_token),
):
    """
    Tüm kullanılabilirlik testi oturumlarını JSON olarak dışa aktarır.
    """
    sessions = _load_json(USABILITY_FILE)

    if not sessions:
        return {
            "export_date": datetime.now().isoformat(),
            "total_sessions": 0,
            "sessions": [],
            "message": "Henüz kayıtlı oturum yok.",
        }

    # Genel istatistikler
    total_tasks = sum(len(s.get("tasks", [])) for s in sessions)
    successful_tasks = sum(
        1
        for s in sessions
        for t in s.get("tasks", [])
        if t.get("is_success")
    )
    overall_success = (successful_tasks / total_tasks * 100) if total_tasks > 0 else 0

    return {
        "export_date": datetime.now().isoformat(),
        "total_sessions": len(sessions),
        "total_tasks": total_tasks,
        "overall_success_rate": round(overall_success, 1),
        "sessions": sessions,
    }
