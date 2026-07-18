# ==============================================================================
# backend/app/routers/food_router.py
# NutriSense — Besin API Endpoint'leri
#
# POST /api/v1/analyze-food     — Görüntüden besin tanıma + kalori
# GET  /api/v1/food-history     — Yemek geçmişi (tarih filtreli)
# POST /api/v1/send-to-dietitian — Diyetisyene rapor gönder
# POST /api/v1/auth/register    — Kullanıcı kaydı
# POST /api/v1/auth/login       — Giriş (JWT token)
# ==============================================================================

import asyncio
import base64
import hashlib
import io
import json
import logging
import uuid
import warnings
from datetime import date, timedelta, datetime
from typing import Annotated, Optional
from collections import defaultdict

from fastapi import (
    APIRouter, Depends, File, Form, Header, HTTPException, Query, Request,
    UploadFile, status,
)
from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy.orm import Session
from sqlalchemy import func

from ..models.database import (
    AuthAuditLog, ConsentRecord, Dietitian, DietitianAssignment,
    DietitianReport, FoodLog, NotificationDelivery, NutritionSource,
    RecognitionAttempt, RefreshToken, User, get_db, utc_now, utc_today,
)
from ..models.schemas import (
    FoodAnalysisResponse, FoodCandidate, FoodAnalysisDecisionRequest,
    FoodAnalysisDecisionResponse, ManualFoodLogRequest, NutrientData,
    FoodHistoryResponse, DailyLogResponse, FoodLogItem, MealSummary,
    SendToDietitianRequest, SendToDietitianResponse,
    AccountDeletionRequest, DietitianAssignmentRequest,
    DietitianAssignmentResponse, LogoutRequest, RefreshTokenRequest,
    UserCreate, UserLogin, UserResponse, TokenResponse,
    ErrorResponse,
)
from ..middleware.auth import (
    get_current_user, hash_password, verify_password,
    issue_token_pair, revoke_refresh_token, rotate_refresh_token,
)
from ..services.google_vision_service import (
    GoogleVisionService, VisionAPIError, FoodNotFoundError,
)
from ..services.nutritionix_service import NutritionixService
from ..services.notification_service import NotificationService
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

router = APIRouter(prefix="/api/v1", tags=["NutriSense API"])

# ── Servis singleton'ları ──
vision_service = GoogleVisionService()
nutrition_service = NutritionixService()
notification_service = NotificationService()

# Öğün türü Türkçe karşılıkları
MEAL_TYPE_TR = {
    "kahvalti": "Kahvaltı",
    "ogle": "Öğle",
    "aksam": "Akşam",
    "atistirmalik": "Atıştırmalık",
}

# Besin adı Türkçe karşılıkları (Google Vision key → Türkçe)
FOOD_NAME_TR = {
    "elma": "Elma", "muz": "Muz", "portakal": "Portakal",
    "domates": "Domates", "salatalik": "Salatalık",
    "pizza": "Pizza", "hamburger": "Hamburger", "makarna": "Makarna",
    "pilav": "Pilav", "ekmek": "Ekmek", "kebap": "Kebap",
    "kofte": "Köfte", "lahmacun": "Lahmacun", "pide": "Pide",
    "baklava": "Baklava", "menemen": "Menemen", "simit": "Simit",
    "borek": "Börek", "manti": "Mantı", "corba": "Çorba",
    "ayran": "Ayran", "yogurt": "Yoğurt", "peynir": "Peynir",
    "yumurta": "Yumurta", "tavuk": "Tavuk",
}

ALLOWED_IMAGE_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
IMAGE_FORMAT_TO_MIME = {
    "JPEG": "image/jpeg",
    "PNG": "image/png",
    "WEBP": "image/webp",
}
LOGIN_WINDOW_SECONDS = 15 * 60
LOGIN_MAX_FAILURES = 5
_login_failures: dict[str, list[datetime]] = defaultdict(list)
_analysis_requests: dict[str, list[datetime]] = defaultdict(list)


def _login_key(request: Request, email: str) -> tuple[str, str]:
    email_hash = hashlib.sha256(email.lower().encode("utf-8")).hexdigest()
    ip = request.client.host if request.client else "unknown"
    return f"{ip}:{email_hash}", email_hash


def _audit_auth(
    db: Session,
    *,
    event: str,
    success: bool,
    email_hash: str | None = None,
    user_id: str | None = None,
    ip_address: str | None = None,
    reason: str | None = None,
) -> None:
    db.add(AuthAuditLog(
        event=event,
        success=success,
        email_hash=email_hash,
        user_id=user_id,
        ip_address=ip_address,
        reason=reason,
    ))
    db.commit()


async def _sanitized_image_base64(upload: UploadFile) -> str:
    """Boyut/MIME doğrular, decode eder ve EXIF içermeyen JPEG üretir."""
    if upload.content_type not in ALLOWED_IMAGE_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Yalnızca JPEG, PNG veya WebP görüntü yüklenebilir.",
        )

    raw = await upload.read(settings.max_analysis_image_bytes + 1)
    await upload.close()
    if not raw:
        raise HTTPException(
            status_code=422,
            detail="Görüntü dosyası boş.",
        )
    if len(raw) > settings.max_analysis_image_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=(
                "Görüntü en fazla "
                f"{settings.max_analysis_image_bytes // (1024 * 1024)} MB olabilir."
            ),
        )

    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(raw)) as decoded:
                detected_mime = IMAGE_FORMAT_TO_MIME.get(decoded.format or "")
                if detected_mime is None or detected_mime != upload.content_type:
                    raise HTTPException(
                        status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                        detail="Dosya içeriği bildirilen görüntü türüyle eşleşmiyor.",
                    )
                if decoded.width * decoded.height > settings.max_analysis_image_pixels:
                    raise HTTPException(
                        status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                        detail="Görüntü piksel boyutu güvenli sınırı aşıyor.",
                    )
                decoded.verify()
            with Image.open(io.BytesIO(raw)) as decoded:
                image = ImageOps.exif_transpose(decoded).convert("RGB")
            image.thumbnail((2048, 2048))
            sanitized = io.BytesIO()
            image.save(sanitized, format="JPEG", quality=90, optimize=True)
    except HTTPException:
        raise
    except (
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
        UnidentifiedImageError,
        OSError,
        ValueError,
    ):
        raise HTTPException(
            status_code=422,
            detail="Görüntü dosyası bozuk veya desteklenmeyen biçimde.",
        )

    return base64.b64encode(sanitized.getvalue()).decode("ascii")


def _enforce_analysis_rate_limit(request: Request, user_id: str) -> None:
    now = utc_now()
    cutoff = now - timedelta(minutes=1)
    ip = request.client.host if request.client else "unknown"
    key = f"{user_id}:{ip}"
    recent = [value for value in _analysis_requests[key] if value > cutoff]
    if len(recent) >= settings.analysis_rate_limit_per_minute:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Çok fazla görüntü analizi istendi. Lütfen kısa süre bekleyin.",
        )
    recent.append(now)
    _analysis_requests[key] = recent


def _nutrition_status(source: str) -> str:
    if source == "not_found":
        return "not_found"
    if source == "local_db":
        return "unverified"
    return "available"


# ═══════════════════════════════════════════════════════════════════════════════
# BESİN ANALİZİ
# ═══════════════════════════════════════════════════════════════════════════════

@router.post(
    "/analyze-food",
    response_model=FoodAnalysisResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Geçersiz istek"},
        404: {"model": ErrorResponse, "description": "Besin bulunamadı"},
        503: {"model": ErrorResponse, "description": "API hatası"},
    },
    summary="Görüntüden besin tanıma ve kalori hesaplama",
    description=(
        "Multipart görüntüyü MIME/boyut doğrulaması ve EXIF temizliği sonrası "
        "Google Vision API ile analiz eder, "
        "besin adını tanır ve Nutritionix'ten kalori bilgisini çeker. "
        "Yemek günlüğü yalnız ayrı karar endpointinde kullanıcı onayıyla oluşur."
    ),
)
async def analyze_food(
    image: Annotated[UploadFile, File(description="JPEG, PNG veya WebP; en fazla 5 MB")],
    http_request: Request,
    capture_id: Annotated[uuid.UUID, Form(description="İstemcinin tek çekim UUID'si")],
    meal_type: Annotated[
        str,
        Form(pattern=r"^(kahvalti|ogle|aksam|atistirmalik)$"),
    ] = "atistirmalik",
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Besin tanıma ve kalori hesaplama endpoint'i.

    İşlem akışı:
    1. Multipart görüntü doğrulama/EXIF temizleme → Google Vision API
    2. Etiketleri besin ismine dönüştür
    3. Nutritionix API'den kalori + besin değerlerini çek
    4. Görüntüyü saklamadan onay bekleyen analiz kaydı oluştur
    5. Yanıtı döndür; food_logs tablosuna bu aşamada yazma
    """
    capture_key = str(capture_id)
    existing = db.query(RecognitionAttempt).filter(
        RecognitionAttempt.user_id == current_user.id,
        RecognitionAttempt.capture_id == capture_key,
    ).first()
    if existing is not None and existing.analysis_payload:
        return FoodAnalysisResponse.model_validate(existing.analysis_payload)

    _enforce_analysis_rate_limit(http_request, current_user.id)
    image_base64 = await _sanitized_image_base64(image)

    # ── 1. Google Vision ile görüntü analizi ──
    try:
        vision_result = await asyncio.wait_for(
            vision_service.analyze_image(image_base64),
            timeout=settings.vision_timeout_seconds,
        )
    except FoodNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Görüntüde yiyecek tespit edilemedi. "
                   "Lütfen kamerayı yiyeceğe doğru tutun ve tekrar deneyin.",
        )
    except VisionAPIError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Görüntü analiz servisi şu an kullanılamıyor. "
                   "Lütfen birkaç dakika sonra tekrar deneyin.",
        )
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Görüntü analiz servisi zaman aşımına uğradı. Lütfen tekrar deneyin.",
        )

    food_name = vision_result["food_name"]
    confidence = vision_result["confidence"]

    # ── 2. Nutritionix'ten besin değerleri ──
    try:
        nutrition = await nutrition_service.get_nutrition(food_name)
    except Exception as e:
        logger.error(f"Nutritionix hatası: {e}")
        nutrition = nutrition_service._query_local_db(food_name, portion_grams=None)

    # ── 3. Türkçe isim ──
    food_name_tr = FOOD_NAME_TR.get(
        food_name, food_name.replace("_", " ").title()
    )

    # ── 4. Onay bekleyen analiz: görüntü ve base64 saklanmaz ──
    candidate_rows = []
    seen_candidates = set()
    raw_candidates = vision_result.get("candidates") or [
        {"food_name": food_name, "confidence": confidence}
    ]
    for candidate in raw_candidates:
        candidate_name = candidate.get("food_name")
        if not candidate_name or candidate_name in seen_candidates:
            continue
        seen_candidates.add(candidate_name)
        candidate_rows.append(FoodCandidate(
            food_name=candidate_name,
            food_name_tr=FOOD_NAME_TR.get(
                candidate_name, candidate_name.replace("_", " ").title()
            ),
            confidence=float(candidate.get("confidence", 0)),
        ))
        if len(candidate_rows) == 3:
            break

    nutrition_provider = nutrition.get("source", "unknown")
    nutrition_status = _nutrition_status(nutrition_provider)
    can_confirm = (
        nutrition_status != "not_found"
        and float(nutrition.get("total_calories", 0)) > 0
        and confidence >= 0.60
    )
    recognition_attempt = RecognitionAttempt(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        provider="google_vision",
        capture_id=capture_key,
        status="succeeded",
        food_name=food_name,
        confidence=confidence,
        request_id=getattr(http_request.state, "request_id", None),
        expires_at=utc_now() + timedelta(minutes=30),
    )
    if confidence >= 0.85 and can_confirm:
        tts_text = (
            f"{food_name_tr} bulundu. Yaklaşık "
            f"{nutrition['total_calories']:.0f} kalori. "
            "Kaydetmeden önce sonucu onaylayın."
        )
    elif confidence >= 0.60:
        names = ", ".join(item.food_name_tr for item in candidate_rows)
        tts_text = f"Sonuç kesin değil. Olası seçenekler: {names}. Lütfen seçin."
    else:
        tts_text = (
            "Yiyecek güvenilir biçimde tanınamadı. "
            "Yeniden fotoğraf çekin veya manuel aramayı kullanın."
        )

    response = FoodAnalysisResponse(
        analysis_id=recognition_attempt.id,
        log_id=None,
        food_name=food_name,
        food_name_tr=food_name_tr,
        calories_per_100g=nutrition["calories_per_100g"],
        portion_grams=nutrition["estimated_portion_g"],
        total_calories=nutrition["total_calories"],
        confidence=round(confidence, 2),
        nutrients=NutrientData(
            protein=nutrition["nutrients"]["protein"],
            carbs=nutrition["nutrients"]["carb"],
            fat=nutrition["nutrients"]["fat"],
            fiber=nutrition["nutrients"].get("fiber", 0),
        ),
        meal_type=meal_type,
        recognition_source="google_vision",
        nutrition_source=nutrition_provider,
        nutrition_status=nutrition_status,
        candidates=candidate_rows,
        needs_confirmation=True,
        can_confirm=can_confirm,
        tts_text=tts_text,
    )
    recognition_attempt.analysis_payload = response.model_dump(mode="json")
    try:
        db.add(recognition_attempt)
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("Onay bekleyen analiz kaydı oluşturulamadı.")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Besin analizi güvenli biçimde başlatılamadı.",
        )
    return response


@router.post(
    "/food-analysis/{analysis_id}/decision",
    response_model=FoodAnalysisDecisionResponse,
    summary="Analizi onayla, düzelt veya reddet",
)
async def decide_food_analysis(
    analysis_id: str,
    request: FoodAnalysisDecisionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    attempt = db.query(RecognitionAttempt).filter(
        RecognitionAttempt.id == analysis_id,
        RecognitionAttempt.user_id == current_user.id,
    ).with_for_update().first()
    if attempt is None or not attempt.analysis_payload:
        raise HTTPException(status_code=404, detail="Analiz bulunamadı.")

    existing_log = db.query(FoodLog).filter(
        FoodLog.recognition_attempt_id == attempt.id
    ).first()
    if existing_log is not None:
        return FoodAnalysisDecisionResponse(
            analysis_id=attempt.id,
            log_id=existing_log.id,
            status="already_saved",
            message="Bu çekim daha önce kaydedildi.",
        )
    if attempt.decision == "rejected":
        return FoodAnalysisDecisionResponse(
            analysis_id=attempt.id,
            status="rejected",
            message="Bu analiz daha önce reddedildi.",
        )
    if attempt.expires_at is not None and attempt.expires_at < utc_now():
        raise HTTPException(status_code=410, detail="Analiz onay süresi doldu.")
    if request.action == "reject":
        attempt.decision = "rejected"
        attempt.decided_at = utc_now()
        db.commit()
        return FoodAnalysisDecisionResponse(
            analysis_id=attempt.id,
            status="rejected",
            message="Sonuç kaydedilmedi.",
        )

    payload = dict(attempt.analysis_payload)
    recognition_source = payload["recognition_source"]
    if request.action == "correct":
        food_name = request.corrected_food_name
        food_name_tr = request.corrected_food_name_tr or FOOD_NAME_TR.get(
            food_name, food_name.replace("_", " ").title()
        )
        nutrition = await nutrition_service.get_nutrition(food_name)
        recognition_source = "manual"
    else:
        if not payload.get("can_confirm"):
            raise HTTPException(
                status_code=422,
                detail="Bu sonuç güvenli biçimde onaylanamaz; yeniden çekin veya düzeltin.",
            )
        food_name = payload["food_name"]
        food_name_tr = payload["food_name_tr"]
        nutrition = {
            "calories_per_100g": payload["calories_per_100g"],
            "estimated_portion_g": payload["portion_grams"],
            "total_calories": payload["total_calories"],
            "nutrients": {
                "protein": payload["nutrients"]["protein"],
                "carb": payload["nutrients"]["carbs"],
                "fat": payload["nutrients"]["fat"],
                "fiber": payload["nutrients"]["fiber"],
            },
            "source": payload["nutrition_source"],
        }

    if nutrition.get("source") == "not_found" or nutrition.get("total_calories", 0) <= 0:
        raise HTTPException(
            status_code=422,
            detail="Besin değeri doğrulanamadığı için kayıt oluşturulmadı.",
        )
    nutrition_source = NutritionSource(
        id=str(uuid.uuid4()),
        provider=nutrition.get("source", "unknown"),
        external_reference=nutrition.get("external_reference"),
        food_name=food_name,
        calories_per_100g=nutrition["calories_per_100g"],
        payload_checksum=hashlib.sha256(
            json.dumps(nutrition, sort_keys=True, default=str).encode("utf-8")
        ).hexdigest(),
    )
    log_entry = FoodLog(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        recognition_attempt_id=attempt.id,
        nutrition_source_id=nutrition_source.id,
        food_name=food_name,
        food_name_tr=food_name_tr,
        calories_per_100g=nutrition["calories_per_100g"],
        estimated_portion_g=nutrition["estimated_portion_g"],
        total_calories=nutrition["total_calories"],
        protein=nutrition["nutrients"]["protein"],
        carbs=nutrition["nutrients"]["carb"],
        fat=nutrition["nutrients"]["fat"],
        fiber=nutrition["nutrients"].get("fiber", 0),
        confidence=float(payload["confidence"]),
        meal_type=payload["meal_type"],
        recognition_source=recognition_source,
        log_date=utc_today(),
    )
    attempt.decision = "corrected" if request.action == "correct" else "confirmed"
    attempt.decided_at = utc_now()
    try:
        db.add_all([nutrition_source, log_entry])
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("Onaylı besin kaydı transaction'ı geri alındı.")
        raise HTTPException(
            status_code=503,
            detail="Onaylı kayıt güvenli biçimde oluşturulamadı.",
        )
    return FoodAnalysisDecisionResponse(
        analysis_id=attempt.id,
        log_id=log_entry.id,
        status="corrected" if request.action == "correct" else "confirmed",
        message="Yemek geçmişine kaydedildi.",
    )


@router.post(
    "/food-log/manual",
    response_model=FoodAnalysisDecisionResponse,
    summary="Kullanıcı onaylı manuel yemek kaydı",
)
async def create_manual_food_log(
    request: ManualFoodLogRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    capture_key = str(request.capture_id)
    existing_attempt = db.query(RecognitionAttempt).filter(
        RecognitionAttempt.user_id == current_user.id,
        RecognitionAttempt.capture_id == capture_key,
    ).first()
    if existing_attempt is not None:
        existing_log = db.query(FoodLog).filter(
            FoodLog.recognition_attempt_id == existing_attempt.id
        ).first()
        if existing_log is not None:
            return FoodAnalysisDecisionResponse(
                analysis_id=existing_attempt.id,
                log_id=existing_log.id,
                status="already_saved",
                message="Bu manuel kayıt daha önce oluşturuldu.",
            )
        raise HTTPException(status_code=409, detail="Bu çekim kimliği başka analizde kullanıldı.")

    nutrition = await nutrition_service.get_nutrition(request.food_name)
    if nutrition.get("source") == "not_found" or nutrition.get("total_calories", 0) <= 0:
        raise HTTPException(
            status_code=422,
            detail="Besin değeri bulunamadığı için manuel kayıt oluşturulmadı.",
        )
    attempt = RecognitionAttempt(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        provider="manual",
        capture_id=capture_key,
        status="succeeded",
        food_name=request.food_name,
        confidence=None,
        decision="confirmed",
        decided_at=utc_now(),
    )
    nutrition_source = NutritionSource(
        id=str(uuid.uuid4()),
        provider=nutrition.get("source", "unknown"),
        food_name=request.food_name,
        calories_per_100g=nutrition["calories_per_100g"],
        payload_checksum=hashlib.sha256(
            json.dumps(nutrition, sort_keys=True, default=str).encode("utf-8")
        ).hexdigest(),
    )
    food_name_tr = request.food_name_tr or FOOD_NAME_TR.get(
        request.food_name, request.food_name.replace("_", " ").title()
    )
    log_entry = FoodLog(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        recognition_attempt_id=attempt.id,
        nutrition_source_id=nutrition_source.id,
        food_name=request.food_name,
        food_name_tr=food_name_tr,
        calories_per_100g=nutrition["calories_per_100g"],
        estimated_portion_g=nutrition["estimated_portion_g"],
        total_calories=nutrition["total_calories"],
        protein=nutrition["nutrients"]["protein"],
        carbs=nutrition["nutrients"]["carb"],
        fat=nutrition["nutrients"]["fat"],
        fiber=nutrition["nutrients"].get("fiber", 0),
        confidence=0.0,
        meal_type=request.meal_type,
        recognition_source="manual",
        log_date=utc_today(),
    )
    try:
        db.add_all([attempt, nutrition_source, log_entry])
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("Manuel yemek kaydı transaction'ı geri alındı.")
        raise HTTPException(status_code=503, detail="Manuel kayıt oluşturulamadı.")
    return FoodAnalysisDecisionResponse(
        analysis_id=attempt.id,
        log_id=log_entry.id,
        status="confirmed",
        message="Manuel yemek geçmişine kaydedildi.",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# YEMEK GEÇMİŞİ
# ═══════════════════════════════════════════════════════════════════════════════

@router.get(
    "/food-history/{user_id}",
    response_model=FoodHistoryResponse,
    summary="Yemek geçmişi sorgulama",
    description="Belirtilen tarih aralığında kullanıcının yemek kayıtlarını döner.",
)
async def get_food_history(
    user_id: str,
    from_date: Optional[date] = Query(None, description="Başlangıç tarihi (YYYY-MM-DD)"),
    to_date: Optional[date] = Query(None, description="Bitiş tarihi (YYYY-MM-DD)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kullanıcının yemek geçmişini tarih aralığıyla döner."""
    # Yetki kontrolü
    if current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu kullanıcının verilerine erişim yetkiniz yok.",
        )

    # Varsayılan tarih aralığı: son 7 gün
    if not to_date:
        to_date = utc_today()
    if not from_date:
        from_date = to_date - timedelta(days=7)

    # Sorgu
    logs = (
        db.query(FoodLog)
        .filter(
            FoodLog.user_id == user_id,
            FoodLog.log_date >= from_date,
            FoodLog.log_date <= to_date,
        )
        .order_by(FoodLog.logged_at.desc())
        .all()
    )

    # Günlük grupla
    daily_map = defaultdict(list)
    for log in logs:
        daily_map[log.log_date].append(log)

    daily_logs = []
    total_calories = 0.0

    for log_date in sorted(daily_map.keys(), reverse=True):
        day_logs = daily_map[log_date]
        day_cal = sum(l.total_calories for l in day_logs)
        day_protein = sum(l.protein for l in day_logs)
        day_carbs = sum(l.carbs for l in day_logs)
        day_fat = sum(l.fat for l in day_logs)
        total_calories += day_cal

        # Öğün bazlı özet
        meal_groups = defaultdict(list)
        for l in day_logs:
            meal_groups[l.meal_type].append(l)

        meals = [
            MealSummary(
                meal_type=mt,
                meal_type_tr=MEAL_TYPE_TR.get(mt, mt),
                total_calories=sum(l.total_calories for l in items),
                food_count=len(items),
            )
            for mt, items in meal_groups.items()
        ]

        foods = [
            FoodLogItem(
                id=l.id,
                food_name=l.food_name,
                food_name_tr=l.food_name_tr,
                calories=l.total_calories,
                portion_g=l.estimated_portion_g,
                meal_type=l.meal_type,
                confidence=l.confidence,
                nutrients=NutrientData(
                    protein=l.protein, carbs=l.carbs, fat=l.fat, fiber=l.fiber
                ),
                logged_at=l.logged_at,
            )
            for l in day_logs
        ]

        daily_logs.append(DailyLogResponse(
            date=log_date,
            total_calories=round(day_cal, 1),
            calorie_target=current_user.daily_calorie_target,
            remaining_calories=round(
                current_user.daily_calorie_target - day_cal, 1
            ),
            total_protein=round(day_protein, 1),
            total_carbs=round(day_carbs, 1),
            total_fat=round(day_fat, 1),
            meal_count=len(day_logs),
            meals=meals,
            foods=foods,
        ))

    total_days = (to_date - from_date).days + 1
    avg_daily = total_calories / max(total_days, 1)

    return FoodHistoryResponse(
        user_id=user_id,
        from_date=from_date,
        to_date=to_date,
        total_days=total_days,
        average_daily_calories=round(avg_daily, 1),
        total_calories=round(total_calories, 1),
        daily_logs=daily_logs,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# DİYETİSYENE RAPOR GÖNDERME
# ═══════════════════════════════════════════════════════════════════════════════

@router.get(
    "/dietitians/assignment",
    response_model=Optional[DietitianAssignmentResponse],
)
async def get_dietitian_assignment(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    assignment = db.query(DietitianAssignment).filter(
        DietitianAssignment.user_id == current_user.id,
        DietitianAssignment.status != "cancelled",
    ).order_by(DietitianAssignment.created_at.desc()).first()
    if assignment is None:
        return None
    dietitian = db.query(Dietitian).filter(
        Dietitian.id == assignment.dietitian_id
    ).first()
    return DietitianAssignmentResponse(
        assignment_id=assignment.id,
        status=assignment.status,
        dietitian_id=dietitian.id,
        dietitian_name=dietitian.full_name,
        email_verified=dietitian.email_verified,
        phone_verified=dietitian.phone_verified,
    )


@router.post(
    "/dietitians/assignment",
    response_model=DietitianAssignmentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def request_dietitian_assignment(
    request: DietitianAssignmentRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    active_assignment = db.query(DietitianAssignment).filter(
        DietitianAssignment.user_id == current_user.id,
        DietitianAssignment.status != "cancelled",
    ).first()
    if active_assignment is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Önce mevcut diyetisyen atamasını iptal edin.",
        )
    dietitian = db.query(Dietitian).filter(
        func.lower(Dietitian.email) == request.dietitian_email.lower(),
        Dietitian.is_active.is_(True),
    ).first()
    if dietitian is None or not (
        dietitian.email_verified or dietitian.phone_verified
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Doğrulanmış ve aktif diyetisyen bulunamadı.",
        )
    assignment = DietitianAssignment(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        dietitian_id=dietitian.id,
        status="pending",
    )
    db.add(assignment)
    db.commit()
    return DietitianAssignmentResponse(
        assignment_id=assignment.id,
        status=assignment.status,
        dietitian_id=dietitian.id,
        dietitian_name=dietitian.full_name,
        email_verified=dietitian.email_verified,
        phone_verified=dietitian.phone_verified,
    )


@router.post(
    "/dietitians/assignment/{assignment_id}/approve",
    response_model=DietitianAssignmentResponse,
)
async def approve_dietitian_assignment(
    assignment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    assignment = db.query(DietitianAssignment).filter(
        DietitianAssignment.id == assignment_id,
        DietitianAssignment.user_id == current_user.id,
        DietitianAssignment.status == "pending",
    ).first()
    if assignment is None:
        raise HTTPException(status_code=404, detail="Bekleyen atama bulunamadı.")
    dietitian = db.query(Dietitian).filter(
        Dietitian.id == assignment.dietitian_id
    ).first()
    if dietitian is None or not (
        dietitian.email_verified or dietitian.phone_verified
    ):
        raise HTTPException(status_code=409, detail="Diyetisyen doğrulaması geçersiz.")
    assignment.status = "approved"
    assignment.approved_at = utc_now()
    current_user.dietitian_id = dietitian.id
    db.commit()
    return DietitianAssignmentResponse(
        assignment_id=assignment.id,
        status=assignment.status,
        dietitian_id=dietitian.id,
        dietitian_name=dietitian.full_name,
        email_verified=dietitian.email_verified,
        phone_verified=dietitian.phone_verified,
    )


@router.delete(
    "/dietitians/assignment/{assignment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def cancel_dietitian_assignment(
    assignment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    assignment = db.query(DietitianAssignment).filter(
        DietitianAssignment.id == assignment_id,
        DietitianAssignment.user_id == current_user.id,
        DietitianAssignment.status != "cancelled",
    ).first()
    if assignment is None:
        raise HTTPException(status_code=404, detail="Atama bulunamadı.")
    assignment.status = "cancelled"
    assignment.cancelled_at = utc_now()
    if current_user.dietitian_id == assignment.dietitian_id:
        current_user.dietitian_id = None
    db.commit()
    return None


@router.post(
    "/send-to-dietitian",
    response_model=SendToDietitianResponse,
    summary="Beslenme raporunu diyetisyene gönder",
    description="Belirlenen tarih aralığındaki besin kayıtlarını e-posta ve SMS ile diyetisyene gönderir.",
)
async def send_to_dietitian(
    request: SendToDietitianRequest,
    idempotency_key: Optional[str] = Header(
        default=None,
        alias="Idempotency-Key",
        min_length=8,
        max_length=128,
    ),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Diyetisyene beslenme raporu gönderir."""
    # Yetki kontrolü
    if str(current_user.id) != str(request.user_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu işlem için yetkiniz yok.",
        )

    # Diyetisyen kontrolü
    if not current_user.dietitian_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Henüz bir diyetisyen atanmamış. "
                   "Lütfen ayarlardan diyetisyen bilgilerinizi ekleyin.",
        )

    dietitian = db.query(Dietitian).filter(
        Dietitian.id == current_user.dietitian_id
    ).first()

    if not dietitian:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Diyetisyen kaydı bulunamadı.",
        )

    assignment = db.query(DietitianAssignment).filter(
        DietitianAssignment.user_id == current_user.id,
        DietitianAssignment.dietitian_id == dietitian.id,
        DietitianAssignment.status == "approved",
    ).first()
    if assignment is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Rapor paylaşımı için onaylı diyetisyen ataması gerekli.",
        )
    if not dietitian.email_verified and not dietitian.phone_verified:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Diyetisyen iletişim bilgileri doğrulanmamış.",
        )

    # Tarih aralığı
    to_dt = request.to_date or utc_today()
    if request.report_type == "daily":
        from_dt = request.from_date or to_dt
    elif request.report_type == "weekly":
        from_dt = request.from_date or (to_dt - timedelta(days=7))
    else:
        from_dt = request.from_date or (to_dt - timedelta(days=30))

    canonical_key = idempotency_key or hashlib.sha256(
        (
            f"{current_user.id}|{dietitian.id}|{request.report_type}|"
            f"{from_dt.isoformat()}|{to_dt.isoformat()}|{request.message or ''}"
        ).encode("utf-8")
    ).hexdigest()
    existing_report = db.query(DietitianReport).filter(
        DietitianReport.user_id == current_user.id,
        DietitianReport.idempotency_key == canonical_key,
    ).first()
    if existing_report is not None:
        return SendToDietitianResponse(
            success=existing_report.status == "sent",
            report_id=existing_report.id,
            sent_via_email=existing_report.sent_via_email,
            sent_via_sms=existing_report.sent_via_sms,
            dietitian_name=dietitian.full_name,
            message=(
                "Bu gönderim isteği daha önce işlendi."
                if existing_report.status != "pending"
                else "Bu gönderim isteği halen işleniyor."
            ),
        )

    # Kayıtları çek
    logs = (
        db.query(FoodLog)
        .filter(
            FoodLog.user_id == str(request.user_id),
            FoodLog.log_date >= from_dt,
            FoodLog.log_date <= to_dt,
        )
        .order_by(FoodLog.log_date, FoodLog.logged_at)
        .all()
    )

    # Rapor verisi hazırla
    total_cal = sum(l.total_calories for l in logs)
    total_days = max((to_dt - from_dt).days + 1, 1)

    daily_map = defaultdict(list)
    for l in logs:
        daily_map[l.log_date].append(l)

    daily_breakdown = []
    for d in sorted(daily_map.keys()):
        day_logs = daily_map[d]
        daily_breakdown.append({
            "date": d.strftime("%d.%m.%Y"),
            "calories": sum(l.total_calories for l in day_logs),
            "protein": sum(l.protein for l in day_logs),
            "carbs": sum(l.carbs for l in day_logs),
            "fat": sum(l.fat for l in day_logs),
            "meal_count": len(day_logs),
        })

    report_data = {
        "report_type": request.report_type,
        "from_date": from_dt.strftime("%d.%m.%Y"),
        "to_date": to_dt.strftime("%d.%m.%Y"),
        "total_calories": total_cal,
        "avg_daily_calories": total_cal / total_days,
        "total_meals": len(logs),
        "total_days": total_days,
        "daily_breakdown": daily_breakdown,
        "message": request.message,
    }

    # Sağlayıcı çağrısından önce idempotency kaydını kalıcılaştır. Böylece DB
    # sonucu yazılamasa dahi aynı anahtarlı retry ikinci mesajı göndermez.
    report = DietitianReport(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        dietitian_id=dietitian.id,
        idempotency_key=canonical_key,
        report_type=request.report_type,
        date_from=from_dt,
        date_to=to_dt,
        total_calories=total_cal,
        total_meals=len(logs),
        status="pending",
    )
    consent = ConsentRecord(
        user_id=current_user.id,
        assignment_id=assignment.id,
        consent_type="dietitian_report_share",
        policy_version="report-share-v1",
        granted=True,
    )
    try:
        db.add_all([report, consent])
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("Rapor gönderim isteği kaydedilemedi.")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Rapor gönderim isteği güvenli biçimde başlatılamadı.",
        )

    # E-posta + SMS gönder
    send_result = await notification_service.send_dietitian_report(
        dietitian_email=dietitian.email if dietitian.email_verified else None,
        dietitian_phone=(dietitian.phone if dietitian.phone_verified else None),
        dietitian_name=dietitian.full_name,
        patient_name=current_user.full_name,
        report_data=report_data,
    )

    report.sent_via_email = send_result["email_sent"]
    report.sent_via_sms = send_result["sms_sent"]
    report.status = "sent" if send_result["email_sent"] or send_result["sms_sent"] else "failed"
    report.sent_at = utc_now() if report.status == "sent" else None
    if dietitian.email_verified:
        db.add(
            NotificationDelivery(
                report_id=report.id,
                channel="email",
                status="sent" if send_result["email_sent"] else "failed",
            )
        )
    if dietitian.phone_verified:
        db.add(
            NotificationDelivery(
                report_id=report.id,
                channel="sms",
                status="sent" if send_result["sms_sent"] else "failed",
            )
        )
    try:
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("Sağlayıcı sonucu kaydedilemedi; idempotency kaydı pending kaldı.")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Gönderim sonucu doğrulanamadı; aynı anahtarla tekrar mesaj gönderilmeyecek.",
        )

    # Status mesajı
    channels = []
    if send_result["email_sent"]:
        channels.append("e-posta")
    if send_result["sms_sent"]:
        channels.append("SMS")

    if channels:
        msg = f"Rapor {' ve '.join(channels)} ile {dietitian.full_name}'a gönderildi."
    else:
        msg = "Rapor gönderilemedi. Lütfen daha sonra tekrar deneyin."

    return SendToDietitianResponse(
        success=bool(channels),
        report_id=report.id,
        sent_via_email=send_result["email_sent"],
        sent_via_sms=send_result["sms_sent"],
        dietitian_name=dietitian.full_name,
        message=msg,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# KİMLİK DOĞRULAMA
# ═══════════════════════════════════════════════════════════════════════════════

@router.post(
    "/auth/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Yeni kullanıcı kaydı",
)
async def register(request: UserCreate, db: Session = Depends(get_db)):
    """Yeni hesap oluşturur ve JWT token döner."""
    normalized_email = request.email.lower()
    existing = db.query(User).filter(func.lower(User.email) == normalized_email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Bu e-posta adresi zaten kayıtlı. Giriş yapmayı deneyin.",
        )

    user = User(
        id=str(uuid.uuid4()),
        email=normalized_email,
        hashed_password=hash_password(request.password),
        full_name=request.full_name,
        phone=request.phone,
        daily_calorie_target=request.daily_calorie_target,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return TokenResponse(**issue_token_pair(db, user))


@router.post(
    "/auth/login",
    response_model=TokenResponse,
    summary="Kullanıcı girişi",
)
async def login(
    credentials: UserLogin,
    http_request: Request,
    db: Session = Depends(get_db),
):
    """E-posta ve şifre ile giriş yapar, JWT token döner."""
    key, email_hash = _login_key(http_request, credentials.email)
    now = utc_now()
    cutoff = now - timedelta(seconds=LOGIN_WINDOW_SECONDS)
    _login_failures[key] = [value for value in _login_failures[key] if value > cutoff]
    if len(_login_failures[key]) >= LOGIN_MAX_FAILURES:
        _audit_auth(
            db,
            event="login_rate_limited",
            success=False,
            email_hash=email_hash,
            ip_address=http_request.client.host if http_request.client else None,
            reason="too_many_attempts",
        )
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Giriş şu anda tamamlanamıyor. Lütfen daha sonra tekrar deneyin.",
        )

    user = db.query(User).filter(
        func.lower(User.email) == credentials.email.lower()
    ).first()
    valid = bool(
        user
        and user.is_active
        and verify_password(credentials.password, user.hashed_password)
    )
    if not valid:
        _login_failures[key].append(now)
        _audit_auth(
            db,
            event="login_failed",
            success=False,
            email_hash=email_hash,
            user_id=user.id if user else None,
            ip_address=http_request.client.host if http_request.client else None,
            reason="invalid_credentials",
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Giriş bilgileri doğrulanamadı.",
        )
    _login_failures.pop(key, None)
    _audit_auth(
        db,
        event="login_success",
        success=True,
        email_hash=email_hash,
        user_id=user.id,
        ip_address=http_request.client.host if http_request.client else None,
    )
    return TokenResponse(**issue_token_pair(db, user))


@router.post(
    "/auth/refresh",
    response_model=TokenResponse,
    summary="Access token yenile ve refresh token döndür",
)
async def refresh_auth_token(
    request: RefreshTokenRequest,
    db: Session = Depends(get_db),
):
    """Refresh token rotation uygular; eski token yeniden kullanılamaz."""
    _, token_data = rotate_refresh_token(db, request.refresh_token)
    return TokenResponse(**token_data)


@router.post(
    "/auth/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Refresh token'ı iptal ederek çıkış yap",
)
async def logout(request: LogoutRequest, db: Session = Depends(get_db)):
    revoke_refresh_token(db, request.refresh_token)
    return None


@router.get("/users/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        is_active=current_user.is_active,
    )


@router.delete("/users/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    request: AccountDeletionRequest,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not verify_password(request.password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Hesap silme bilgileri doğrulanamadı.",
        )
    email_hash = hashlib.sha256(current_user.email.lower().encode("utf-8")).hexdigest()
    user_id = current_user.id
    db.query(RefreshToken).filter(RefreshToken.user_id == user_id).delete()
    db.query(DietitianAssignment).filter(
        DietitianAssignment.user_id == user_id
    ).delete()
    db.query(DietitianReport).filter(DietitianReport.user_id == user_id).delete()
    db.query(ConsentRecord).filter(ConsentRecord.user_id == user_id).delete()
    db.query(AuthAuditLog).filter(AuthAuditLog.user_id == user_id).update(
        {AuthAuditLog.user_id: None},
        synchronize_session=False,
    )
    db.delete(current_user)
    db.commit()
    _audit_auth(
        db,
        event="account_deleted",
        success=True,
        email_hash=email_hash,
        user_id=None,
        ip_address=http_request.client.host if http_request.client else None,
    )
    return None


@router.post("/auth/password-reset", status_code=status.HTTP_501_NOT_IMPLEMENTED)
async def password_reset_unavailable():
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Parola sıfırlama henüz kullanılamıyor.",
    )
