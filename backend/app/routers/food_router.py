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
from decimal import Decimal
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
    RecognitionAttempt, RefreshToken, User, get_db, istanbul_date, utc_now,
)
from ..models.schemas import (
    FoodAnalysisResponse, FoodCandidate, FoodAnalysisDecisionRequest,
    FoodAnalysisDecisionResponse, FoodPortionRequest, ManualFoodLogRequest,
    NutrientData,
    FoodHistoryResponse, DailyLogResponse, FoodLogDeleteResponse, FoodLogItem,
    FoodLogUpdateRequest, MealSummary,
    SendToDietitianRequest, SendToDietitianResponse,
    ChannelDeliveryResponse, DietitianReportHistoryItem,
    DietitianReportPreviewRequest, DietitianReportPreviewResponse,
    AccountDeletionRequest, DietitianAssignmentRequest,
    DietitianAssignmentResponse, LogoutRequest, RefreshTokenRequest,
    UserCreate, UserLogin, UserResponse, TokenResponse,
    ErrorResponse,
)
from ..domain.nutrition import (
    NutritionDomainError, NutrientsPer100g, UnitConversion,
    calculate_nutrition, portion_to_grams,
)
from ..domain.report_delivery import (
    ReportDeliveryError, accessibility_summary, build_report_payload,
    consent_context_hash, mask_email, mask_phone, resolve_report_dates,
)
from ..middleware.auth import (
    get_current_user, hash_password, verify_password,
    issue_token_pair, revoke_refresh_token, rotate_refresh_token,
)
from ..services.google_vision_service import (
    GoogleVisionService, VisionAPIError, FoodNotFoundError,
)
from ..services.nutritionix_service import NutritionixService
from ..services.notification_service import (
    ChannelDeliveryError, NotificationService,
)
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


def _nutrition_status(nutrition: dict) -> str:
    source = nutrition.get("source", "not_found")
    if not nutrition.get("available", source != "not_found"):
        return "not_found"
    if nutrition.get("nutrition_reliability") == "unverified":
        return "unverified"
    return "available"


def _nutrition_is_traceable(nutrition: dict) -> bool:
    return (
        nutrition.get("available") is True
        and nutrition.get("nutrition_reliability")
        in {"verified_provider", "verified_local", "user_entered"}
        and nutrition.get("provenance") is not None
        and float(nutrition.get("total_calories") or 0) > 0
    )


def _per_100g_profile(nutrition: dict) -> NutrientsPer100g:
    per_100g = nutrition.get("nutrients_per_100g")
    if not per_100g:
        raise NutritionDomainError("100 gram başına makro besin profili eksik.")
    return NutrientsPer100g(
        calories=nutrition["calories_per_100g"],
        protein=per_100g.get("protein", 0),
        carbs=per_100g.get("carb", per_100g.get("carbs", 0)),
        fat=per_100g.get("fat", 0),
        fiber=per_100g.get("fiber", 0),
    )


def _apply_portion(
    nutrition: dict,
    *,
    portion_value: float,
    portion_unit: str,
    portion_method: str,
) -> dict:
    conversions = {}
    for row in nutrition.get("portion_conversions", []):
        conversion = UnitConversion(
            canonical_food_id=nutrition["canonical_food_id"],
            unit=row["unit"],
            grams_per_unit=Decimal(str(row["grams_per_unit"])),
            source_item_id=row["source_item_id"],
            source_name=row["source_name"],
        )
        conversions[(conversion.canonical_food_id, conversion.unit)] = conversion
    grams = portion_to_grams(
        value=portion_value,
        unit=portion_unit,
        canonical_food_id=nutrition["canonical_food_id"],
        conversions=conversions,
    )
    result = calculate_nutrition(_per_100g_profile(nutrition), grams)
    updated = dict(nutrition)
    updated.update({
        "estimated_portion_g": float(result.portion_grams),
        "portion_value": portion_value,
        "portion_unit": portion_unit,
        "portion_method": portion_method,
        "portion_is_estimate": False,
        "total_calories": float(result.calories),
        "nutrients": {
            "protein": float(result.protein),
            "carb": float(result.carbs),
            "fat": float(result.fat),
            "fiber": float(result.fiber),
        },
        "macro_calories": float(result.macro_calories),
        "macro_calorie_delta": float(result.macro_calorie_delta),
        "macro_calorie_delta_percent": float(result.macro_calorie_delta_percent),
    })
    return updated


def _nutrition_from_analysis_payload(payload: dict) -> dict:
    nutrients = payload.get("nutrients") or {}
    per_100g = payload.get("nutrients_per_100g") or {}
    return {
        "available": payload.get("can_confirm", False),
        "canonical_food_id": payload["canonical_food_id"],
        "food_name": payload["food_name"],
        "food_name_tr": payload["food_name_tr"],
        "normalization_version": payload["normalization_version"],
        "calories_per_100g": payload.get("calories_per_100g"),
        "default_portion_g": payload.get("portion_grams"),
        "estimated_portion_g": payload.get("portion_grams"),
        "portion_value": payload.get("portion_value"),
        "portion_unit": payload.get("portion_unit"),
        "portion_method": payload.get("portion_method"),
        "portion_is_estimate": payload.get("portion_is_estimate", True),
        "total_calories": payload.get("total_calories"),
        "nutrients": {
            "protein": nutrients.get("protein", 0),
            "carb": nutrients.get("carbs", 0),
            "fat": nutrients.get("fat", 0),
            "fiber": nutrients.get("fiber", 0),
        },
        "nutrients_per_100g": {
            "protein": per_100g.get("protein", 0),
            "carb": per_100g.get("carbs", 0),
            "fat": per_100g.get("fat", 0),
            "fiber": per_100g.get("fiber", 0),
        },
        "macro_calories": payload.get("macro_calories"),
        "macro_calorie_delta": payload.get("macro_calorie_delta"),
        "macro_calorie_delta_percent": payload.get("macro_calorie_delta_percent"),
        "source": payload["nutrition_source"],
        "nutrition_reliability": payload["nutrition_reliability"],
        "provenance": payload.get("provenance"),
        "portion_conversions": payload.get("portion_options", []),
    }


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
        nutrition = nutrition_service._query_local_db(
            food_name, portion_grams=None, input_locale="en-US"
        )

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

    nutrition_provider = nutrition.get("source", "not_found")
    nutrition_status = _nutrition_status(nutrition)
    traceable = _nutrition_is_traceable(nutrition)
    can_confirm = traceable and confidence >= 0.60
    food_name = nutrition.get("food_name", food_name)
    food_name_tr = nutrition.get("food_name_tr", food_name_tr)
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
            f"Tahmini {nutrition['estimated_portion_g']:.0f} gram; "
            "değiştirmek ister misiniz? Kaydetmeden önce sonucu onaylayın."
        )
    elif not traceable:
        tts_text = (
            "Besin değeri doğrulanamadı; sıfır kalorili kayıt oluşturulmadı. "
            "Manuel arama veya düzeltme kullanın."
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
        canonical_food_id=nutrition["canonical_food_id"],
        normalization_version=nutrition["normalization_version"],
        calories_per_100g=nutrition.get("calories_per_100g"),
        portion_grams=nutrition.get("estimated_portion_g"),
        portion_value=nutrition.get("portion_value"),
        portion_unit=nutrition.get("portion_unit"),
        portion_method=nutrition.get("portion_method"),
        portion_is_estimate=nutrition.get("portion_is_estimate", True),
        total_calories=nutrition.get("total_calories"),
        confidence=round(confidence, 2),
        nutrients=NutrientData(
            protein=nutrition["nutrients"]["protein"],
            carbs=nutrition["nutrients"]["carb"],
            fat=nutrition["nutrients"]["fat"],
            fiber=nutrition["nutrients"].get("fiber", 0),
        ) if traceable else None,
        nutrients_per_100g=NutrientData(
            protein=nutrition["nutrients_per_100g"]["protein"],
            carbs=nutrition["nutrients_per_100g"]["carb"],
            fat=nutrition["nutrients_per_100g"]["fat"],
            fiber=nutrition["nutrients_per_100g"].get("fiber", 0),
        ) if traceable else None,
        macro_calories=nutrition.get("macro_calories"),
        macro_calorie_delta=nutrition.get("macro_calorie_delta"),
        macro_calorie_delta_percent=nutrition.get("macro_calorie_delta_percent"),
        meal_type=meal_type,
        recognition_source="google_vision",
        nutrition_source=nutrition_provider,
        nutrition_status=nutrition_status,
        nutrition_reliability=nutrition.get("nutrition_reliability", "not_found"),
        provenance=nutrition.get("provenance"),
        portion_options=nutrition.get("portion_conversions", []),
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
    "/food-analysis/{analysis_id}/portion",
    response_model=FoodAnalysisResponse,
    summary="Onay bekleyen analiz porsiyonunu yeniden hesapla",
)
async def update_food_analysis_portion(
    analysis_id: str,
    request: FoodPortionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    attempt = db.query(RecognitionAttempt).filter(
        RecognitionAttempt.id == analysis_id,
        RecognitionAttempt.user_id == current_user.id,
    ).with_for_update().first()
    if attempt is None or not attempt.analysis_payload:
        raise HTTPException(status_code=404, detail="Analiz bulunamadı.")
    if attempt.decision is not None:
        raise HTTPException(status_code=409, detail="Karar verilmiş analiz değiştirilemez.")
    if attempt.expires_at is not None and attempt.expires_at < utc_now():
        raise HTTPException(status_code=410, detail="Analiz onay süresi doldu.")

    payload = dict(attempt.analysis_payload)
    nutrition = _nutrition_from_analysis_payload(payload)
    if not _nutrition_is_traceable(nutrition):
        raise HTTPException(
            status_code=422,
            detail="Besin kaynağı doğrulanmadığı için porsiyon hesaplanamaz.",
        )
    try:
        nutrition = _apply_portion(
            nutrition,
            portion_value=request.portion_value,
            portion_unit=request.portion_unit,
            portion_method=request.portion_method,
        )
    except NutritionDomainError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    payload.update({
        "portion_grams": nutrition["estimated_portion_g"],
        "portion_value": nutrition["portion_value"],
        "portion_unit": nutrition["portion_unit"],
        "portion_method": nutrition["portion_method"],
        "portion_is_estimate": False,
        "total_calories": nutrition["total_calories"],
        "nutrients": {
            "protein": nutrition["nutrients"]["protein"],
            "carbs": nutrition["nutrients"]["carb"],
            "fat": nutrition["nutrients"]["fat"],
            "fiber": nutrition["nutrients"]["fiber"],
        },
        "macro_calories": nutrition["macro_calories"],
        "macro_calorie_delta": nutrition["macro_calorie_delta"],
        "macro_calorie_delta_percent": nutrition["macro_calorie_delta_percent"],
        "tts_text": (
            f"{payload['food_name_tr']}, {nutrition['estimated_portion_g']:.0f} gram, "
            f"yaklaşık {nutrition['total_calories']:.0f} kalori. Onaylıyor musunuz?"
        ),
    })
    attempt.analysis_payload = payload
    db.commit()
    return FoodAnalysisResponse.model_validate(payload)


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
        queried_name = request.corrected_food_name
        nutrition = await nutrition_service.get_nutrition(
            queried_name, input_locale="tr-TR"
        )
        food_name = nutrition.get("food_name", queried_name)
        food_name_tr = request.corrected_food_name_tr or nutrition.get(
            "food_name_tr", queried_name.replace("_", " ").title()
        )
        recognition_source = "manual"
    else:
        if not payload.get("can_confirm"):
            raise HTTPException(
                status_code=422,
                detail="Bu sonuç güvenli biçimde onaylanamaz; yeniden çekin veya düzeltin.",
            )
        food_name = payload["food_name"]
        food_name_tr = payload["food_name_tr"]
        nutrition = _nutrition_from_analysis_payload(payload)

    if request.portion_value is not None:
        try:
            nutrition = _apply_portion(
                nutrition,
                portion_value=request.portion_value,
                portion_unit=request.portion_unit,
                portion_method=request.portion_method,
            )
        except NutritionDomainError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    if not _nutrition_is_traceable(nutrition):
        raise HTTPException(
            status_code=422,
            detail="Besin değeri doğrulanamadığı için kayıt oluşturulmadı.",
        )
    provenance = nutrition["provenance"]
    nutrition_source = NutritionSource(
        id=str(uuid.uuid4()),
        provider=nutrition["source"],
        external_reference=provenance["source_item_id"],
        canonical_food_id=nutrition["canonical_food_id"],
        source_item_id=provenance["source_item_id"],
        locale=provenance["locale"],
        serving_unit=provenance["serving_unit"],
        serving_grams=provenance["serving_grams"],
        license_name=provenance["license_name"],
        attribution=provenance["attribution"],
        normalization_version=nutrition["normalization_version"],
        retrieved_at=datetime.fromisoformat(
            provenance["retrieved_at"].replace("Z", "+00:00")
        ),
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
        canonical_food_id=nutrition["canonical_food_id"],
        calories_per_100g=nutrition["calories_per_100g"],
        estimated_portion_g=nutrition["estimated_portion_g"],
        portion_value=nutrition["portion_value"],
        portion_unit=nutrition["portion_unit"],
        portion_method=nutrition["portion_method"],
        portion_is_estimate=nutrition["portion_is_estimate"],
        total_calories=nutrition["total_calories"],
        protein=nutrition["nutrients"]["protein"],
        carbs=nutrition["nutrients"]["carb"],
        fat=nutrition["nutrients"]["fat"],
        fiber=nutrition["nutrients"].get("fiber", 0),
        macro_calories=nutrition["macro_calories"],
        macro_calorie_delta=nutrition["macro_calorie_delta"],
        nutrition_reliability=nutrition["nutrition_reliability"],
        confidence=float(payload["confidence"]),
        meal_type=payload["meal_type"],
        recognition_source=recognition_source,
        log_date=istanbul_date(),
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

    nutrition = await nutrition_service.get_nutrition(
        request.food_name,
        portion_grams=request.portion_value,
        input_locale="tr-TR",
    )
    if not _nutrition_is_traceable(nutrition):
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
        food_name=nutrition.get("food_name", request.food_name),
        confidence=None,
        decision="confirmed",
        decided_at=utc_now(),
    )
    nutrition_source = NutritionSource(
        id=str(uuid.uuid4()),
        provider=nutrition["source"],
        external_reference=nutrition["provenance"]["source_item_id"],
        canonical_food_id=nutrition["canonical_food_id"],
        source_item_id=nutrition["provenance"]["source_item_id"],
        locale=nutrition["provenance"]["locale"],
        serving_unit=nutrition["provenance"]["serving_unit"],
        serving_grams=nutrition["provenance"]["serving_grams"],
        license_name=nutrition["provenance"]["license_name"],
        attribution=nutrition["provenance"]["attribution"],
        normalization_version=nutrition["normalization_version"],
        retrieved_at=datetime.fromisoformat(
            nutrition["provenance"]["retrieved_at"].replace("Z", "+00:00")
        ),
        food_name=nutrition.get("food_name", request.food_name),
        calories_per_100g=nutrition["calories_per_100g"],
        payload_checksum=hashlib.sha256(
            json.dumps(nutrition, sort_keys=True, default=str).encode("utf-8")
        ).hexdigest(),
    )
    food_name_tr = request.food_name_tr or nutrition.get(
        "food_name_tr", request.food_name.replace("_", " ").title()
    )
    log_entry = FoodLog(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        recognition_attempt_id=attempt.id,
        nutrition_source_id=nutrition_source.id,
        food_name=nutrition.get("food_name", request.food_name),
        food_name_tr=food_name_tr,
        canonical_food_id=nutrition["canonical_food_id"],
        calories_per_100g=nutrition["calories_per_100g"],
        estimated_portion_g=nutrition["estimated_portion_g"],
        portion_value=nutrition["portion_value"],
        portion_unit=nutrition["portion_unit"],
        portion_method=nutrition["portion_method"],
        portion_is_estimate=nutrition["portion_is_estimate"],
        total_calories=nutrition["total_calories"],
        protein=nutrition["nutrients"]["protein"],
        carbs=nutrition["nutrients"]["carb"],
        fat=nutrition["nutrients"]["fat"],
        fiber=nutrition["nutrients"].get("fiber", 0),
        macro_calories=nutrition["macro_calories"],
        macro_calorie_delta=nutrition["macro_calorie_delta"],
        nutrition_reliability=nutrition["nutrition_reliability"],
        confidence=0.0,
        meal_type=request.meal_type,
        recognition_source="manual",
        log_date=istanbul_date(),
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
    page: int = Query(1, ge=1),
    page_size: int = Query(7, ge=1, le=31, description="Sayfa başına yerel gün"),
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
        to_date = istanbul_date()
    if not from_date:
        from_date = to_date - timedelta(days=7)
    if from_date > to_date:
        raise HTTPException(
            status_code=422,
            detail="Başlangıç tarihi bitiş tarihinden sonra olamaz.",
        )
    if (to_date - from_date).days > 366:
        raise HTTPException(status_code=422, detail="Tarih aralığı en fazla 366 gün olabilir.")

    # Sorgu
    logs = (
        db.query(FoodLog)
        .filter(
            FoodLog.user_id == user_id,
            FoodLog.log_date >= from_date,
            FoodLog.log_date <= to_date,
            FoodLog.deleted_at.is_(None),
            FoodLog.is_user_confirmed.is_(True),
        )
        .order_by(FoodLog.logged_at.desc())
        .all()
    )

    # Günlük grupla
    all_logs = logs
    all_dates = sorted({log.log_date for log in all_logs}, reverse=True)
    page_start = (page - 1) * page_size
    page_dates = set(all_dates[page_start:page_start + page_size])
    logs = [log for log in all_logs if log.log_date in page_dates]

    daily_map = defaultdict(list)
    for log in logs:
        daily_map[log.log_date].append(log)

    daily_logs = []
    total_calories = sum(
        (log.total_calories for log in all_logs), start=Decimal("0")
    )

    for log_date in sorted(daily_map.keys(), reverse=True):
        day_logs = daily_map[log_date]
        day_cal = sum(l.total_calories for l in day_logs)
        day_protein = sum(l.protein for l in day_logs)
        day_carbs = sum(l.carbs for l in day_logs)
        day_fat = sum(l.fat for l in day_logs)
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

        foods = [_food_log_item(log) for log in day_logs]

        daily_logs.append(DailyLogResponse(
            date=log_date,
            total_calories=round(day_cal, 1),
            calorie_target=current_user.daily_calorie_target,
            remaining_calories=round(
                Decimal(str(current_user.daily_calorie_target)) - day_cal, 1
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
        total_log_count=len(all_logs),
        total_date_count=len(all_dates),
        page=page,
        page_size=page_size,
        has_more=page_start + page_size < len(all_dates),
        daily_logs=daily_logs,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# DİYETİSYENE RAPOR GÖNDERME
# ═══════════════════════════════════════════════════════════════════════════════

def _food_log_item(log: FoodLog) -> FoodLogItem:
    source = log.nutrition_source
    return FoodLogItem(
        id=log.id,
        food_name=log.food_name,
        food_name_tr=log.food_name_tr,
        canonical_food_id=log.canonical_food_id,
        calories=log.total_calories,
        calories_per_100g=log.calories_per_100g,
        portion_g=log.estimated_portion_g,
        portion_value=log.portion_value,
        portion_unit=log.portion_unit,
        portion_method=log.portion_method,
        portion_is_estimate=log.portion_is_estimate,
        meal_type=log.meal_type,
        confidence=log.confidence,
        recognition_source=log.recognition_source,
        nutrition_source=source.provider if source is not None else "unavailable",
        nutrition_reliability=log.nutrition_reliability,
        is_corrected=log.is_corrected,
        is_user_confirmed=log.is_user_confirmed,
        nutrients=NutrientData(
            protein=log.protein, carbs=log.carbs, fat=log.fat, fiber=log.fiber,
        ),
        logged_at=log.logged_at,
        updated_at=log.updated_at,
    )


def _owned_food_log(
    db: Session,
    *,
    current_user: User,
    log_id: str,
    include_deleted: bool = False,
) -> FoodLog:
    query = db.query(FoodLog).filter(
        FoodLog.id == log_id,
        FoodLog.user_id == str(current_user.id),
    )
    if not include_deleted:
        query = query.filter(FoodLog.deleted_at.is_(None))
    log = query.first()
    if log is None:
        # Do not reveal whether a record belongs to another user.
        raise HTTPException(status_code=404, detail="Besin kaydı bulunamadı.")
    return log


@router.patch(
    "/food-logs/{log_id}",
    response_model=FoodLogItem,
    summary="Besin günlüğü kaydını düzelt",
)
async def update_food_log(
    log_id: str,
    request: FoodLogUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    log = _owned_food_log(db, current_user=current_user, log_id=log_id)
    changed_fields: list[str] = []

    if request.food_name_tr is not None and request.food_name_tr != log.food_name_tr:
        if log.original_food_name is None:
            log.original_food_name = log.food_name
            log.original_food_name_tr = log.food_name_tr
        log.food_name_tr = request.food_name_tr
        log.is_corrected = True
        changed_fields.append("food_name_tr")

    if request.meal_type is not None and request.meal_type != log.meal_type:
        log.meal_type = request.meal_type
        log.is_corrected = True
        changed_fields.append("meal_type")

    if request.portion_g is not None:
        old_grams = Decimal(str(log.estimated_portion_g))
        if old_grams <= 0:
            raise HTTPException(status_code=409, detail="Mevcut porsiyon güvenli değil.")
        profile = NutrientsPer100g(
            calories=Decimal(str(log.calories_per_100g)),
            protein=Decimal(str(log.protein)) * 100 / old_grams,
            carbs=Decimal(str(log.carbs)) * 100 / old_grams,
            fat=Decimal(str(log.fat)) * 100 / old_grams,
            fiber=Decimal(str(log.fiber)) * 100 / old_grams,
        )
        try:
            calculation = calculate_nutrition(profile, request.portion_g)
        except NutritionDomainError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        log.estimated_portion_g = calculation.portion_grams
        log.portion_value = calculation.portion_grams
        log.portion_unit = "gram"
        log.portion_method = "user_selected"
        log.portion_is_estimate = False
        log.total_calories = calculation.calories
        log.protein = calculation.protein
        log.carbs = calculation.carbs
        log.fat = calculation.fat
        log.fiber = calculation.fiber
        log.macro_calories = calculation.macro_calories
        log.macro_calorie_delta = calculation.macro_calorie_delta
        log.is_corrected = True
        changed_fields.append("portion_g")

    log.updated_at = utc_now()
    db.add(AuthAuditLog(
        user_id=str(current_user.id),
        event="food_log_updated",
        success=True,
        reason="user_correction",
        metadata_json={"log_id": str(log.id), "changed_fields": changed_fields},
    ))
    try:
        db.commit()
        db.refresh(log)
    except Exception:
        db.rollback()
        logger.exception("Besin günlüğü düzeltmesi geri alındı.")
        raise HTTPException(status_code=503, detail="Düzeltme kaydedilemedi.")
    return _food_log_item(log)


@router.delete(
    "/food-logs/{log_id}",
    response_model=FoodLogDeleteResponse,
    summary="Besin günlüğü kaydını geri alınabilir biçimde sil",
)
async def delete_food_log(
    log_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    log = _owned_food_log(
        db, current_user=current_user, log_id=log_id, include_deleted=True,
    )
    if log.deleted_at is None:
        log.deleted_at = utc_now()
        log.updated_at = log.deleted_at
        db.add(AuthAuditLog(
            user_id=str(current_user.id),
            event="food_log_deleted",
            success=True,
            reason="user_request",
            metadata_json={"log_id": str(log.id)},
        ))
        db.commit()
    return FoodLogDeleteResponse(
        log_id=log.id,
        status="deleted",
        message="Kayıt silindi. Geri alma işlemi kullanılabilir.",
    )


@router.post(
    "/food-logs/{log_id}/restore",
    response_model=FoodLogDeleteResponse,
    summary="Silinen besin günlüğü kaydını geri al",
)
async def restore_food_log(
    log_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    log = _owned_food_log(
        db, current_user=current_user, log_id=log_id, include_deleted=True,
    )
    if log.deleted_at is not None:
        log.deleted_at = None
        log.updated_at = utc_now()
        db.add(AuthAuditLog(
            user_id=str(current_user.id),
            event="food_log_restored",
            success=True,
            reason="user_undo",
            metadata_json={"log_id": str(log.id)},
        ))
        db.commit()
    return FoodLogDeleteResponse(
        log_id=log.id,
        status="restored",
        message="Kayıt geri alındı.",
    )


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
        email_masked=mask_email(dietitian.email) if dietitian.email_verified else None,
        phone_masked=mask_phone(dietitian.phone) if dietitian.phone_verified else None,
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
        email_masked=mask_email(dietitian.email) if dietitian.email_verified else None,
        phone_masked=mask_phone(dietitian.phone) if dietitian.phone_verified else None,
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
        email_masked=mask_email(dietitian.email) if dietitian.email_verified else None,
        phone_masked=mask_phone(dietitian.phone) if dietitian.phone_verified else None,
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


def _approved_report_relationship(db: Session, current_user: User):
    if not current_user.dietitian_id:
        raise HTTPException(404, "Henüz onaylı bir diyetisyen atanmamış.")
    dietitian = db.query(Dietitian).filter(
        Dietitian.id == current_user.dietitian_id,
        Dietitian.is_active.is_(True),
    ).first()
    assignment = db.query(DietitianAssignment).filter(
        DietitianAssignment.user_id == current_user.id,
        DietitianAssignment.dietitian_id == current_user.dietitian_id,
        DietitianAssignment.status == "approved",
    ).first()
    if dietitian is None or assignment is None:
        raise HTTPException(403, "Rapor paylaşımı için onaylı diyetisyen ilişkisi gerekli.")
    return dietitian, assignment


def _report_payload(db, current_user, request):
    if str(current_user.id) != str(request.user_id):
        raise HTTPException(403, "Bu işlem için yetkiniz yok.")
    dietitian, assignment = _approved_report_relationship(db, current_user)
    try:
        from_dt, to_dt = resolve_report_dates(
            request.report_type, request.from_date, request.to_date,
            today=istanbul_date(),
        )
        logs = db.query(FoodLog).filter(
            FoodLog.user_id == current_user.id,
            FoodLog.log_date >= from_dt,
            FoodLog.log_date <= to_dt,
            FoodLog.deleted_at.is_(None),
            FoodLog.is_user_confirmed.is_(True),
        ).order_by(FoodLog.log_date, FoodLog.logged_at).all()
        payload = build_report_payload(
            user=current_user,
            dietitian=dietitian,
            assignment=assignment,
            report_type=request.report_type,
            from_date=from_dt,
            to_date=to_dt,
            channels=request.channels,
            logs=logs,
            message=getattr(request, "message", None),
        )
    except ReportDeliveryError as error:
        raise HTTPException(422, str(error)) from error
    return dietitian, assignment, payload


def _delivery_response(delivery: NotificationDelivery) -> ChannelDeliveryResponse:
    return ChannelDeliveryResponse(
        channel=delivery.channel,
        status=delivery.status,
        destination_masked=delivery.destination_masked,
        attempt_count=delivery.attempt_count,
        max_attempts=delivery.max_attempts,
        provider_status=delivery.provider_status,
        error_code=delivery.error_code,
    )


def _report_message(report: DietitianReport) -> str:
    if report.status == "sent":
        return "Seçilen kanallar sağlayıcı tarafından kabul edildi; nihai teslim ayrıca doğrulanmalıdır."
    if report.status == "partial_failed":
        return "Bazı kanallar kabul edildi, bazıları başarısız oldu. Kanal ayrıntılarını kontrol edin."
    if report.status in {"queued", "sending"}:
        return "Gönderim güvenli kuyruğa alındı ve işleniyor."
    return "Hiçbir kanal gönderilemedi. Uygun kanallar güvenli biçimde yeniden denenebilir."


def _report_response(
    db: Session,
    report: DietitianReport,
    dietitian: Dietitian,
    *,
    duplicate: bool = False,
) -> SendToDietitianResponse:
    deliveries = db.query(NotificationDelivery).filter(
        NotificationDelivery.report_id == report.id,
    ).order_by(NotificationDelivery.channel).all()
    return SendToDietitianResponse(
        success=report.status == "sent",
        report_id=report.id,
        sent_via_email=any(
            item.channel == "email" and item.status == "sent" for item in deliveries
        ),
        sent_via_sms=any(
            item.channel == "sms" and item.status == "sent" for item in deliveries
        ),
        dietitian_name=dietitian.full_name,
        status=report.status,
        channels=[_delivery_response(item) for item in deliveries],
        duplicate=duplicate,
        message=_report_message(report),
    )


async def _process_report_outbox(
    db: Session,
    report: DietitianReport,
    dietitian: Dietitian,
) -> None:
    deliveries = db.query(NotificationDelivery).filter(
        NotificationDelivery.report_id == report.id,
        NotificationDelivery.status.in_(["queued", "failed"]),
        NotificationDelivery.attempt_count < NotificationDelivery.max_attempts,
    ).all()
    if not deliveries:
        return
    report.status = "sending"
    db.commit()
    destinations = {"email": dietitian.email, "sms": dietitian.phone}
    for delivery in deliveries:
        destination = destinations.get(delivery.channel)
        expected_mask = (
            mask_email(destination) if delivery.channel == "email" and destination
            else mask_phone(destination) if destination else None
        )
        if destination is None or expected_mask != delivery.destination_masked:
            delivery.status = "failed"
            delivery.error_code = "RECIPIENT_CHANGED"
            delivery.error_message = "Doğrulanmış alıcı önizlemeden sonra değişti."
            delivery.attempt_count = delivery.max_attempts
            continue
        delivery.status = "sending"
        delivery.attempt_count += 1
        delivery.attempted_at = utc_now()
        delivery.error_code = None
        delivery.error_message = None
        db.commit()
        try:
            result = await notification_service.send_channel(
                channel=delivery.channel,
                destination=destination,
                report_data=report.payload_json,
            )
        except ChannelDeliveryError as error:
            delivery.status = "failed"
            delivery.error_code = error.code
            delivery.error_message = "Sağlayıcı kanalı kabul etmedi."
            if error.retryable and delivery.attempt_count < delivery.max_attempts:
                delivery.next_attempt_at = utc_now() + timedelta(
                    seconds=30 * (2 ** (delivery.attempt_count - 1)),
                )
            else:
                delivery.next_attempt_at = None
        else:
            delivery.status = "sent"
            delivery.provider_message_id = result["provider_message_id"]
            delivery.provider_status = result["provider_status"]
            delivery.sent_at = utc_now()
            delivery.next_attempt_at = None
        db.commit()
    deliveries = db.query(NotificationDelivery).filter(
        NotificationDelivery.report_id == report.id,
    ).all()
    sent_count = sum(item.status == "sent" for item in deliveries)
    failed_count = sum(item.status == "failed" for item in deliveries)
    if sent_count == len(deliveries):
        report.status = "sent"
        report.sent_at = utc_now()
    elif sent_count and failed_count:
        report.status = "partial_failed"
    elif failed_count == len(deliveries):
        report.status = "failed"
    else:
        report.status = "queued"
    report.sent_via_email = any(
        item.channel == "email" and item.status == "sent" for item in deliveries
    )
    report.sent_via_sms = any(
        item.channel == "sms" and item.status == "sent" for item in deliveries
    )
    report.completed_at = utc_now() if report.status in {
        "sent", "partial_failed", "failed",
    } else None
    db.add(AuthAuditLog(
        user_id=report.user_id,
        event="dietitian_report_delivery_processed",
        success=sent_count > 0,
        reason=report.status,
        metadata_json={
            "report_id": str(report.id),
            "channels": [item.channel for item in deliveries],
            "channel_statuses": {
                item.channel: item.status for item in deliveries
            },
        },
    ))
    db.commit()


@router.post(
    "/dietitian-reports/preview",
    response_model=DietitianReportPreviewResponse,
)
async def preview_dietitian_report(
    request: DietitianReportPreviewRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    dietitian, _assignment, payload = _report_payload(db, current_user, request)
    digest = consent_context_hash(payload)
    return DietitianReportPreviewResponse(
        report_type=payload["report_type"],
        from_date=payload["from_date"],
        to_date=payload["to_date"],
        record_count=payload["record_count"],
        total_calories=payload["total_calories"],
        average_daily_calories=payload["average_daily_calories"],
        estimated_portion_count=payload["estimated_portion_count"],
        dietitian_name=dietitian.full_name,
        recipients=payload["recipients"],
        channels=payload["channels"],
        consent_context_hash=digest,
        accessibility_summary=accessibility_summary(payload),
    )


@router.post(
    "/send-to-dietitian",
    response_model=SendToDietitianResponse,
    summary="Onaylanmış rapor gönderimini güvenli outbox üzerinden başlat",
)
async def send_to_dietitian(
    request: SendToDietitianRequest,
    http_request: Request,
    idempotency_key: str = Header(
        ..., alias="Idempotency-Key", min_length=16, max_length=128,
    ),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    dietitian, assignment, payload = _report_payload(db, current_user, request)
    digest = consent_context_hash(payload)
    if digest != request.consent_context_hash:
        raise HTTPException(
            409,
            "Rapor önizlemeden sonra değişti. Lütfen yeni önizlemeyi onaylayın.",
        )
    existing = db.query(DietitianReport).filter(
        DietitianReport.user_id == current_user.id,
        DietitianReport.idempotency_key == idempotency_key,
    ).first()
    if existing is not None:
        if existing.consent_context_hash != digest:
            raise HTTPException(409, "Idempotency anahtarı farklı bir raporda kullanılmış.")
        return _report_response(db, existing, dietitian, duplicate=True)
    request_id = getattr(http_request.state, "request_id", None)
    report = DietitianReport(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        dietitian_id=dietitian.id,
        idempotency_key=idempotency_key,
        request_id=request_id,
        consent_context_hash=digest,
        channels_json=payload["channels"],
        recipient_snapshot_json=payload["recipients"],
        payload_json=payload,
        report_type=payload["report_type"],
        date_from=date.fromisoformat(payload["from_date"]),
        date_to=date.fromisoformat(payload["to_date"]),
        total_calories=payload["total_calories"],
        total_meals=payload["record_count"],
        record_count=payload["record_count"],
        status="queued",
    )
    consent = ConsentRecord(
        user_id=current_user.id,
        assignment_id=assignment.id,
        consent_type="dietitian_report_share",
        policy_version="report-share-v2",
        granted=True,
        context_hash=digest,
        channels_json=payload["channels"],
        record_count=payload["record_count"],
        date_from=date.fromisoformat(payload["from_date"]),
        date_to=date.fromisoformat(payload["to_date"]),
        recipient_masked=payload["recipients"],
        request_id=request_id,
    )
    deliveries = [
        NotificationDelivery(
            report_id=report.id,
            channel=channel,
            status="queued",
            destination_masked=payload["recipients"][channel],
            attempt_count=0,
            max_attempts=3,
        )
        for channel in payload["channels"]
    ]
    db.add_all([report, consent, *deliveries, AuthAuditLog(
        user_id=current_user.id,
        event="dietitian_report_consent_granted",
        success=True,
        reason="explicit_per_send_consent",
        metadata_json={
            "report_id": str(report.id), "context_hash": digest,
            "record_count": payload["record_count"],
            "channels": payload["channels"],
            "recipients": payload["recipients"],
        },
    )])
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(503, "Gönderim isteği güvenli kuyruğa alınamadı.")
    await _process_report_outbox(db, report, dietitian)
    return _report_response(db, report, dietitian)


@router.post(
    "/dietitian-reports/{report_id}/retry",
    response_model=SendToDietitianResponse,
)
async def retry_dietitian_report(
    report_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    report = db.query(DietitianReport).filter(
        DietitianReport.id == report_id,
        DietitianReport.user_id == current_user.id,
    ).first()
    if report is None:
        raise HTTPException(404, "Rapor bulunamadı.")
    dietitian, _assignment = _approved_report_relationship(db, current_user)
    deliveries = db.query(NotificationDelivery).filter(
        NotificationDelivery.report_id == report.id,
        NotificationDelivery.status == "failed",
        NotificationDelivery.attempt_count < NotificationDelivery.max_attempts,
    ).all()
    if not deliveries:
        raise HTTPException(409, "Yeniden denenebilir başarısız kanal yok.")
    now = utc_now()
    if any(item.next_attempt_at and item.next_attempt_at > now for item in deliveries):
        raise HTTPException(409, "Güvenli yeniden deneme süresi henüz dolmadı.")
    await _process_report_outbox(db, report, dietitian)
    return _report_response(db, report, dietitian)


@router.get(
    "/dietitian-reports",
    response_model=list[DietitianReportHistoryItem],
)
async def dietitian_report_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    reports = db.query(DietitianReport).filter(
        DietitianReport.user_id == current_user.id,
    ).order_by(DietitianReport.created_at.desc()).limit(50).all()
    result = []
    for report in reports:
        deliveries = db.query(NotificationDelivery).filter(
            NotificationDelivery.report_id == report.id,
        ).order_by(NotificationDelivery.channel).all()
        result.append(DietitianReportHistoryItem(
            report_id=report.id,
            report_type=report.report_type,
            from_date=report.date_from,
            to_date=report.date_to,
            record_count=report.record_count,
            status=report.status,
            created_at=report.created_at,
            completed_at=report.completed_at,
            channels=[_delivery_response(item) for item in deliveries],
        ))
    return result


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
