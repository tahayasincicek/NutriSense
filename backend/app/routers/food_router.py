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
import secrets
import uuid
import warnings
from datetime import date, timedelta, datetime, timezone
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
    DietitianNote, DietitianReport, FoodLog, NotificationDelivery,
    NutritionSource,
    HealthMetric, PasswordResetToken, RecognitionAttempt, RefreshToken,
    User, WeightMeasurement, get_db, istanbul_date, utc_now,
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
    DietitianCreate, DietitianDashboardResponse,
    DietitianPendingRequest, DietitianPendingRequestList,
    DietitianReceivedReport, DietitianReceivedReportList,
    DietitianReportDetail, DietitianReportRecord, DietitianReportDay,
    DietitianReplyRequest, DietitianProfileUpdate,
    DietitianNoteRequest, DietitianNoteItem, DietitianNoteList,
    HealthMetricUpdate, HealthMetricResponse,
    ProductConsentUpdate, ProductConsentItem, ProductConsentState,
    WeightMeasurementCreate, WeightMeasurementItem, WeightHistoryResponse,
    DietitianPatientHistoryResponse, DietitianPatientLogItem,
    PasswordResetRequest, PasswordResetConfirm, PasswordResetResponse,
    DietitianAssignmentResponse, LogoutRequest, RefreshTokenRequest,
    UserCreate, UserLogin, UserProfileUpdate, UserResponse, TokenResponse,
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
from ..services.gemini_vision_service import GeminiVisionService
from ..services.nutritionix_service import NutritionixService
from ..services.notification_service import (
    ChannelDeliveryError, NotificationService, build_password_reset_email,
)
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

router = APIRouter(prefix="/api/v1", tags=["NutriSense API"])


# ── Servis singleton'ları ──
def _build_vision_service():
    """VISION_PROVIDER_MODE'a göre görüntü tanıma sağlayıcısını seçer."""
    if settings.vision_provider_mode == "gemini":
        return GeminiVisionService()
    return GoogleVisionService()


def _vision_provider_name() -> str:
    """Analiz kaydına yazılacak sağlayıcı etiketi."""
    return (
        "gemini_vision"
        if settings.vision_provider_mode == "gemini"
        else "google_vision"
    )


vision_service = _build_vision_service()
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
        "yapılandırılan görüntü sağlayıcısı (Google Vision veya Gemini) ile analiz eder, "
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
    1. Multipart görüntü doğrulama/EXIF temizleme → görüntü tanıma sağlayıcısı
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
    # Görüntü yurtdışındaki bir sağlayıcıya gidiyorsa bu ayrı bir aktarımdır;
    # kullanıcı rıza vermediyse görüntü hiç işlenmez ve dışarı çıkmaz.
    # Kullanıcı manuel besin girişiyle uygulamayı kullanmaya devam edebilir.
    if settings.vision_provider_mode in _CROSS_BORDER_VISION_MODES and not _has_consent(
        db, current_user.id, "image_cross_border_transfer"
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Fotoğrafın analiz için yurt dışındaki sağlayıcıya "
                "gönderilmesine izin vermediniz. Besini elle girebilir veya "
                "ayarlardan bu izni verebilirsiniz."
            ),
        )
    image_base64 = await _sanitized_image_base64(image)

    # ── 1. Yapılandırılan sağlayıcı ile görüntü analizi ──
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
    except Exception as exc:
        logger.error("Nutritionix hatası exception_type=%s", type(exc).__name__)
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
        provider=_vision_provider_name(),
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

    # Porsiyon değeri gram olduğu varsayılamaz. Şema yalnız gram kabul
    # ederken bu doğruydu; artık mililitre ve adet de gelebiliyor ve
    # doğrudan gram diye geçirmek 250 ml sütü 250 gram olarak kaydediyordu.
    # Grama çevirmeyi, tarama akışındaki gibi doğrulanmış dönüşüm yapar.
    nutrition = await nutrition_service.get_nutrition(
        request.food_name,
        portion_grams=(
            request.portion_value if request.portion_unit == "gram" else None
        ),
        input_locale="tr-TR",
    )
    if request.portion_unit != "gram":
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
# BESİN ARAMA (MANUEL)
# ═══════════════════════════════════════════════════════════════════════════════

@router.get(
    "/food/search",
    response_model=FoodAnalysisResponse,
    summary="Besin arama",
    description="Metin tabanlı manuel besin arama ve kalori getirme (Nutritionix).",
)
async def search_food(
    query: str = Query(..., description="Aranacak besin adı"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        nutrition = await nutrition_service.get_nutrition(query, input_locale="tr-TR")
    except Exception as e:
        logger.error(f"Search error: {e}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Besin bulunamadı."
        )

    if not _nutrition_is_traceable(nutrition):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Besin bulunamadı."
        )

    food_name_tr = nutrition.get("food_name_tr", query.title())
    calories_per_100g = float(nutrition.get("calories_per_100g", 0))
    portion_value = float(nutrition.get("portion_value", 100.0))
    total_calories = float(nutrition.get("total_calories", calories_per_100g))

    nutrients = nutrition.get("nutrients", {})
    nutrients_per_100g = nutrition.get("nutrients_per_100g", {})

    applied_nutrients = NutrientData(
        protein=nutrients.get("protein", 0),
        carbs=nutrients.get("carb", 0),
        fat=nutrients.get("fat", 0),
        fiber=nutrients.get("fiber", 0),
    )

    base_nutrients = NutrientData(
        protein=nutrients_per_100g.get("protein", 0),
        carbs=nutrients_per_100g.get("carb", 0),
        fat=nutrients_per_100g.get("fat", 0),
        fiber=nutrients_per_100g.get("fiber", 0),
    )

    attempt_id = str(uuid.uuid4())
    attempt = RecognitionAttempt(
        id=attempt_id,
        user_id=current_user.id,
        provider="manual",
        status="succeeded",
        food_name=food_name_tr,
        confidence=1.0,
        expires_at=utc_now() + timedelta(minutes=30),
    )

    tts_text = (
        f"{food_name_tr} bulundu. Tahmini {portion_value:.0f} gram, "
        f"yaklaşık {total_calories:.0f} kalori. "
        "Tarif ve miktar farklı olabilir; porsiyonu kontrol edip onaylayın."
    )

    response = FoodAnalysisResponse(
        analysis_id=attempt.id,
        log_id=None,
        food_name=nutrition.get("food_name", query),
        food_name_tr=food_name_tr,
        canonical_food_id=nutrition.get("canonical_food_id", "manual"),
        normalization_version=nutrition.get("normalization_version", "1.0"),
        confidence=1.0,
        portion_grams=portion_value,
        portion_value=portion_value,
        portion_unit=nutrition.get("portion_unit", "gram"),
        portion_method=nutrition.get("portion_method", "source_default"),
        portion_is_estimate=nutrition.get("portion_is_estimate", False),
        calories_per_100g=calories_per_100g,
        total_calories=total_calories,
        nutrients=applied_nutrients,
        nutrients_per_100g=base_nutrients,
        macro_calories=nutrition.get("macro_calories"),
        macro_calorie_delta=nutrition.get("macro_calorie_delta"),
        macro_calorie_delta_percent=nutrition.get("macro_calorie_delta_percent"),
        meal_type="atistirmalik",
        recognition_source="manual",
        nutrition_source=nutrition.get("source", "nutritionix"),
        nutrition_status="available",
        nutrition_reliability=nutrition.get("nutrition_reliability", "verified_provider"),
        provenance=nutrition["provenance"],
        portion_options=nutrition.get("portion_conversions", []),
        needs_confirmation=True,
        can_confirm=True,
        tts_text=tts_text,
    )
    attempt.analysis_payload = response.model_dump(mode="json")
    db.add(attempt)
    db.commit()
    return response


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

    if request.portion_g is not None or request.portion_value is not None:
        old_grams = Decimal(str(log.estimated_portion_g))
        if old_grams <= 0:
            raise HTTPException(status_code=409, detail="Mevcut porsiyon güvenli değil.")
        if request.portion_value is not None:
            # Birim başına gram, kaydın kendi değerlerinden çıkarılır: kayıt
            # oluşurken doğrulanmış dönüşümle hesaplanmıştı, yeniden uydurma
            # yapılmıyor. Kullanıcı yalnız kaydın kendi biriminde düzeltir;
            # birim değiştirmek için elde doğrulanmış bir oran yok.
            if request.portion_unit != log.portion_unit:
                raise HTTPException(
                    status_code=422,
                    detail="Kayıt bu birimle oluşturulmadı; birim değiştirilemez.",
                )
            old_value = Decimal(str(log.portion_value))
            if old_value <= 0:
                raise HTTPException(
                    status_code=409, detail="Mevcut porsiyon güvenli değil."
                )
            grams_per_unit = old_grams / old_value
            target_grams = Decimal(str(request.portion_value)) * grams_per_unit
        else:
            target_grams = Decimal(str(request.portion_g))
        profile = NutrientsPer100g(
            calories=Decimal(str(log.calories_per_100g)),
            protein=Decimal(str(log.protein)) * 100 / old_grams,
            carbs=Decimal(str(log.carbs)) * 100 / old_grams,
            fat=Decimal(str(log.fat)) * 100 / old_grams,
            fiber=Decimal(str(log.fiber)) * 100 / old_grams,
        )
        try:
            calculation = calculate_nutrition(profile, target_grams)
        except NutritionDomainError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        log.estimated_portion_g = calculation.portion_grams
        if request.portion_value is not None:
            log.portion_value = request.portion_value
            log.portion_unit = request.portion_unit
        else:
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
    return _assignment_response(assignment, dietitian)


def _assignment_awaiting(assignment: DietitianAssignment) -> str | None:
    """Bağın hangi tarafın onayını beklediğini döndürür."""
    if assignment.status != "pending":
        return None
    if assignment.approved_at is None and assignment.dietitian_accepted_at is None:
        return "both"
    if assignment.approved_at is None:
        return "patient"
    return "dietitian"


def _settle_assignment(assignment: DietitianAssignment, user: User) -> None:
    """İki onay da tamamlandıysa bağı kurar.

    Hasta rızası ve diyetisyen kabulü ayrı ayrı zorunludur; biri eksikken
    hastanın sağlık verisi diyetisyene açılmaz.
    """
    if assignment.approved_at is not None and assignment.dietitian_accepted_at is not None:
        assignment.status = "approved"
        user.dietitian_id = assignment.dietitian_id


def _assignment_response(
    assignment: DietitianAssignment, dietitian: Dietitian
) -> DietitianAssignmentResponse:
    return DietitianAssignmentResponse(
        assignment_id=assignment.id,
        status=assignment.status,
        dietitian_id=dietitian.id,
        dietitian_name=dietitian.full_name,
        email_verified=dietitian.email_verified,
        phone_verified=dietitian.phone_verified,
        email_masked=mask_email(dietitian.email) if dietitian.email_verified else None,
        phone_masked=mask_phone(dietitian.phone) if dietitian.phone_verified else None,
        patient_approved=assignment.approved_at is not None,
        dietitian_accepted=assignment.dietitian_accepted_at is not None,
        awaiting=_assignment_awaiting(assignment),
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
    # Hasta rızası kaydedilir; bağ yalnız diyetisyen de kabul edince kurulur.
    assignment.approved_at = utc_now()
    _settle_assignment(assignment, current_user)
    db.commit()
    return _assignment_response(assignment, dietitian)


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
    sms_parts = (report.payload_json or {}).get("_sms_delivery", {}).get("parts", [])
    if any(part["status"] == "sent" for part in sms_parts) and not all(
        part["status"] == "sent" for part in sms_parts
    ):
        return "SMS raporunun bazı parçaları kabul edildi; rapor henüz tamamlanmadı. Kanal ayrıntılarını kontrol edin."
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
            sms_options = {}
            if delivery.channel == "sms":
                def checkpoint_sms(progress):
                    # Separate delivery bookkeeping from the consent-hashed record snapshot.
                    payload = dict(report.payload_json)
                    payload["_sms_delivery"] = progress
                    report.payload_json = payload
                    db.commit()

                sms_options = {
                    "sms_progress": report.payload_json.get("_sms_delivery"),
                    "sms_checkpoint": checkpoint_sms,
                }
            result = await notification_service.send_channel(
                channel=delivery.channel,
                destination=destination,
                report_data=report.payload_json,
                **sms_options,
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
    sms_part_accepted = any(
        part["status"] == "sent"
        for part in report.payload_json.get("_sms_delivery", {}).get("parts", [])
    )
    if sent_count == len(deliveries):
        report.status = "sent"
        report.sent_at = utc_now()
    elif (sent_count or sms_part_accepted) and failed_count:
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
        success=sent_count > 0 or sms_part_accepted,
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
        policy_version="report-share-v3",
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
            dietitian_reply=report.dietitian_reply,
            dietitian_replied_at=report.dietitian_replied_at,
        ))
    return result


# ═══════════════════════════════════════════════════════════════════════════════
# KİMLİK DOĞRULAMA
# ═══════════════════════════════════════════════════════════════════════════════

def _dietitian_profile_for_user(db: Session, user: User) -> Dietitian:
    """Aynı doğrulanmış kimliğe bağlı diyetisyen profilini döndürür."""
    profile = db.query(Dietitian).filter(
        func.lower(Dietitian.email) == user.email.lower(),
        Dietitian.is_active.is_(True),
    ).first()
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu hesap bir diyetisyen hesabı değil.",
        )
    return profile


@router.post(
    "/auth/register-dietitian",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Diyetisyen hesabı oluştur",
)
async def register_dietitian(
    request: DietitianCreate,
    db: Session = Depends(get_db),
):
    normalized_email = request.email.lower()
    existing_user = db.query(User).filter(
        func.lower(User.email) == normalized_email
    ).first()
    existing_profile = db.query(Dietitian).filter(
        func.lower(Dietitian.email) == normalized_email
    ).first()
    if existing_user or existing_profile:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Bu e-posta adresi zaten kayıtlı. Giriş yapmayı deneyin.",
        )

    # Yerel geliştirmede doğrulama sağlayıcısı bulunmadığından hesap doğrudan
    # etkinleşir. Staging/production ortamında gerçek doğrulama tamamlanmadan
    # hastalar bu profili eşleştiremez.
    locally_verified = settings.app_environment.lower() in {"local", "dev", "test"}
    user = User(
        id=str(uuid.uuid4()),
        email=normalized_email,
        hashed_password=hash_password(request.password),
        full_name=request.full_name,
        phone=request.phone,
    )
    profile = Dietitian(
        id=str(uuid.uuid4()),
        email=normalized_email,
        full_name=request.full_name,
        phone=request.phone,
        specialization=request.specialization,
        email_verified=locally_verified,
        phone_verified=bool(request.phone) and locally_verified,
    )
    try:
        db.add_all([user, profile])
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        logger.exception("Diyetisyen hesabı oluşturulamadı.")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Diyetisyen hesabı oluşturulamadı.",
        )
    return TokenResponse(**issue_token_pair(db, user))


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
async def get_me(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    is_dietitian = db.query(Dietitian.id).filter(
        func.lower(Dietitian.email) == current_user.email.lower(),
        Dietitian.is_active.is_(True),
    ).first() is not None
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        is_active=current_user.is_active,
        phone=current_user.phone,
        preferred_language=current_user.preferred_language,
        tts_speed=current_user.tts_speed,
        high_contrast=current_user.high_contrast,
        account_type="dietitian" if is_dietitian else "patient",
    )


# ═══════════════════════════════════════════════════════════════════════════════
# DİYETİSYEN TARAFI EŞLEŞME KABULÜ
# ═══════════════════════════════════════════════════════════════════════════════

def _pending_requests_for(db: Session, dietitian_id: str) -> list[DietitianPendingRequest]:
    """Diyetisyenin kabul/ret bekleyen isteklerini hasta kimliği maskeli döner."""
    rows = db.query(DietitianAssignment).filter(
        DietitianAssignment.dietitian_id == dietitian_id,
        DietitianAssignment.status == "pending",
        DietitianAssignment.dietitian_accepted_at.is_(None),
    ).order_by(DietitianAssignment.created_at.asc()).all()
    requests: list[DietitianPendingRequest] = []
    for row in rows:
        patient = db.query(User).filter(User.id == row.user_id).first()
        if patient is None or not patient.is_active:
            continue
        requests.append(DietitianPendingRequest(
            assignment_id=row.id,
            patient_name=patient.full_name,
            patient_email_masked=mask_email(patient.email),
            requested_at=row.created_at,
            patient_approved=row.approved_at is not None,
        ))
    return requests


@router.get(
    "/dietitian/assignments/pending",
    response_model=DietitianPendingRequestList,
    summary="Diyetisyenin bekleyen eşleşme istekleri",
)
async def list_pending_dietitian_assignments(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = _dietitian_profile_for_user(db, current_user)
    return DietitianPendingRequestList(
        requests=_pending_requests_for(db, profile.id)
    )


@router.post(
    "/dietitian/assignments/{assignment_id}/accept",
    response_model=DietitianAssignmentResponse,
    summary="Eşleşme isteğini kabul et",
)
async def accept_dietitian_assignment(
    assignment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = _dietitian_profile_for_user(db, current_user)
    assignment = db.query(DietitianAssignment).filter(
        DietitianAssignment.id == assignment_id,
        DietitianAssignment.dietitian_id == profile.id,
        DietitianAssignment.status == "pending",
    ).first()
    if assignment is None:
        raise HTTPException(status_code=404, detail="Bekleyen istek bulunamadı.")
    patient = db.query(User).filter(User.id == assignment.user_id).first()
    if patient is None or not patient.is_active:
        raise HTTPException(status_code=409, detail="Hasta hesabı aktif değil.")
    assignment.dietitian_accepted_at = utc_now()
    _settle_assignment(assignment, patient)
    db.commit()
    return _assignment_response(assignment, profile)


@router.post(
    "/dietitian/assignments/{assignment_id}/reject",
    response_model=DietitianAssignmentResponse,
    summary="Eşleşme isteğini reddet",
)
async def reject_dietitian_assignment(
    assignment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = _dietitian_profile_for_user(db, current_user)
    assignment = db.query(DietitianAssignment).filter(
        DietitianAssignment.id == assignment_id,
        DietitianAssignment.dietitian_id == profile.id,
        DietitianAssignment.status == "pending",
    ).first()
    if assignment is None:
        raise HTTPException(status_code=404, detail="Bekleyen istek bulunamadı.")
    assignment.status = "rejected"
    assignment.rejected_at = utc_now()
    patient = db.query(User).filter(User.id == assignment.user_id).first()
    if patient is not None and patient.dietitian_id == profile.id:
        patient.dietitian_id = None
    db.commit()
    return _assignment_response(assignment, profile)


def _received_reports_for(
    db: Session, dietitian_id: str, limit: int = 20
) -> list[DietitianReceivedReport]:
    """Diyetisyene ulaşmış, danışan onaylı raporları en yeniden eskiye döner."""
    rows = db.query(DietitianReport).filter(
        DietitianReport.dietitian_id == dietitian_id,
        DietitianReport.status.in_(("sent", "partial_failed")),
    ).order_by(DietitianReport.created_at.desc()).limit(limit).all()
    reports: list[DietitianReceivedReport] = []
    for row in rows:
        patient = db.query(User).filter(User.id == row.user_id).first()
        if patient is None:
            continue
        reports.append(DietitianReceivedReport(
            report_id=row.id,
            patient_id=patient.id,
            patient_name=patient.full_name,
            report_type=row.report_type,
            from_date=row.date_from,
            to_date=row.date_to,
            record_count=row.record_count,
            total_meals=row.total_meals,
            total_calories=row.total_calories,
            status=row.status,
            created_at=row.created_at,
            delivered_via_email=bool(row.sent_via_email),
            delivered_via_sms=bool(row.sent_via_sms),
        ))
    return reports


@router.get(
    "/dietitian/reports",
    response_model=DietitianReceivedReportList,
    summary="Diyetisyene ulaşan beslenme raporları",
)
async def list_received_dietitian_reports(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = _dietitian_profile_for_user(db, current_user)
    return DietitianReceivedReportList(
        reports=_received_reports_for(db, profile.id)
    )


@router.get(
    "/dietitian/reports/{report_id}",
    response_model=DietitianReportDetail,
    summary="Rapor içeriği: besin adı, miktar, tarih/saat ve kalori",
)
async def read_received_dietitian_report(
    report_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Diyetisyenin kendi raporunun ayrıntısını döndürür.

    Rapor yalnız gönderilmişse okunabilir; kuyruktaki bir rapor henüz
    danışanın onayladığı teslimat değildir.
    """
    profile = _dietitian_profile_for_user(db, current_user)
    report = db.query(DietitianReport).filter(
        DietitianReport.id == report_id,
        DietitianReport.dietitian_id == profile.id,
        DietitianReport.status.in_(("sent", "partial_failed")),
    ).first()
    if report is None:
        raise HTTPException(status_code=404, detail="Rapor bulunamadı.")
    return _report_detail_response(db, report)


def _report_detail_response(
    db: Session, report: DietitianReport
) -> DietitianReportDetail:
    """Rapor kaydını ayrıntı yanıtına dönüştürür."""
    payload = report.payload_json or {}
    records = [
        DietitianReportRecord(
            food_name_tr=item.get("food_name_tr") or "Bilinmeyen besin",
            portion_grams=float(item.get("portion_grams") or 0),
            portion_is_estimate=bool(item.get("portion_is_estimate")),
            total_calories=float(item.get("total_calories") or 0),
            protein=float(item.get("protein") or 0),
            carbs=float(item.get("carbs") or 0),
            fat=float(item.get("fat") or 0),
            meal_type=item.get("meal_type") or "atistirmalik",
            logged_at=item["logged_at"],
            is_corrected=bool(item.get("is_corrected")),
        )
        for item in payload.get("records", [])
        if item.get("logged_at")
    ]
    daily = [
        DietitianReportDay(
            date=item["date"],
            calories=float(item.get("calories") or 0),
            record_count=int(item.get("record_count") or 0),
        )
        for item in payload.get("daily_breakdown", [])
        if item.get("date")
    ]
    patient = db.query(User).filter(User.id == report.user_id).first()
    return DietitianReportDetail(
        report_id=report.id,
        patient_name=(
            payload.get("patient_name")
            or (patient.full_name if patient else "Bilinmeyen danışan")
        ),
        report_type=report.report_type,
        from_date=report.date_from,
        to_date=report.date_to,
        record_count=report.record_count,
        total_calories=report.total_calories,
        average_daily_calories=float(payload.get("average_daily_calories") or 0),
        estimated_portion_count=int(payload.get("estimated_portion_count") or 0),
        status=report.status,
        created_at=report.created_at,
        disclaimer=payload.get("disclaimer")
        or "Bu rapor tahmini beslenme bilgisi içerir; tıbbi tavsiye değildir.",
        patient_note=(payload.get("message") or "").strip() or None,
        dietitian_reply=report.dietitian_reply,
        dietitian_replied_at=report.dietitian_replied_at,
        records=records,
        daily_breakdown=daily,
    )


@router.delete(
    "/dietitian/assignments/{assignment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Diyetisyen kendi tarafından eşleşmeyi sonlandırır",
)
async def end_dietitian_assignment(
    assignment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kurulu bağı diyetisyen tarafından sonlandırır.

    Hastanın iptal hakkının simetriğidir; bağ koptuğunda hastanın verisi
    diyetisyene kapanır. Geçmiş raporlar teslim edilmiş kayıtlar olduğu için
    silinmez.
    """
    profile = _dietitian_profile_for_user(db, current_user)
    assignment = db.query(DietitianAssignment).filter(
        DietitianAssignment.id == assignment_id,
        DietitianAssignment.dietitian_id == profile.id,
        DietitianAssignment.status == "approved",
    ).first()
    if assignment is None:
        raise HTTPException(status_code=404, detail="Aktif eşleşme bulunamadı.")
    assignment.status = "cancelled"
    assignment.cancelled_at = utc_now()
    patient = db.query(User).filter(User.id == assignment.user_id).first()
    if patient is not None and patient.dietitian_id == profile.id:
        patient.dietitian_id = None
    db.commit()
    return None


@router.post(
    "/dietitian/reports/{report_id}/reply",
    response_model=DietitianReportDetail,
    summary="Rapora cevap yaz",
)
async def reply_to_dietitian_report(
    report_id: str,
    request: DietitianReplyRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Diyetisyenin kendi raporuna tek cevabını kaydeder.

    Cevap yalnız raporu gönderen hastaya görünür. Yeniden yazmak önceki
    cevabın üzerine yazar; geçmiş sürüm tutulmaz.
    """
    profile = _dietitian_profile_for_user(db, current_user)
    report = db.query(DietitianReport).filter(
        DietitianReport.id == report_id,
        DietitianReport.dietitian_id == profile.id,
        DietitianReport.status.in_(("sent", "partial_failed")),
    ).first()
    if report is None:
        raise HTTPException(status_code=404, detail="Rapor bulunamadı.")
    report.dietitian_reply = request.reply.strip()
    report.dietitian_replied_at = utc_now()
    db.commit()
    return _report_detail_response(db, report)


def _assigned_patient_or_404(db: Session, dietitian_id: str, user_id: str) -> User:
    """Diyetisyen yalnız kendisine onaylı biçimde bağlı danışanı görebilir."""
    assignment = db.query(DietitianAssignment).filter(
        DietitianAssignment.dietitian_id == dietitian_id,
        DietitianAssignment.user_id == user_id,
        DietitianAssignment.status == "approved",
    ).first()
    if assignment is None:
        raise HTTPException(status_code=404, detail="Danışan bulunamadı.")
    patient = db.query(User).filter(User.id == user_id).first()
    if patient is None:
        raise HTTPException(status_code=404, detail="Danışan bulunamadı.")
    return patient


def _note_list_response(
    db: Session, dietitian_id: str, user_id: str
) -> DietitianNoteList:
    notes = db.query(DietitianNote).filter(
        DietitianNote.dietitian_id == dietitian_id,
        DietitianNote.user_id == user_id,
    ).order_by(DietitianNote.created_at.desc()).all()
    return DietitianNoteList(
        user_id=user_id,
        items=[
            DietitianNoteItem(
                id=note.id, body=note.body, created_at=note.created_at
            )
            for note in notes
        ],
    )


@router.get(
    "/dietitian/patients/{user_id}/notes",
    response_model=DietitianNoteList,
    summary="Danışan notlarını listeler",
)
async def list_dietitian_notes(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Diyetisyenin bu danışan için yazdığı notları yeniden eskiye döner."""
    profile = _dietitian_profile_for_user(db, current_user)
    _assigned_patient_or_404(db, profile.id, user_id)
    return _note_list_response(db, profile.id, user_id)


@router.post(
    "/dietitian/patients/{user_id}/notes",
    response_model=DietitianNoteList,
    status_code=status.HTTP_201_CREATED,
    summary="Danışan için yeni not ekler",
)
async def create_dietitian_note(
    user_id: str,
    request: DietitianNoteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Yeni bir not ekler; önceki notlar korunur.

    Takip notları birikerek anlam kazanır, bu yüzden kayıt üzerine yazmak
    yerine listeye eklenir. Not sağlık verisi içerdiği için yalnız eşleşme
    onaylıyken yazılabilir.
    """
    profile = _dietitian_profile_for_user(db, current_user)
    _assigned_patient_or_404(db, profile.id, user_id)
    body = request.body.strip()
    if not body:
        raise HTTPException(status_code=422, detail="Not boş olamaz.")
    db.add(
        DietitianNote(user_id=user_id, dietitian_id=profile.id, body=body)
    )
    db.commit()
    return _note_list_response(db, profile.id, user_id)


@router.delete(
    "/dietitian/patients/{user_id}/notes/{note_id}",
    response_model=DietitianNoteList,
    summary="Danışan notunu siler",
)
async def delete_dietitian_note(
    user_id: str,
    note_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Yanlış yazılan notu kaldırır; diğer notlar etkilenmez."""
    profile = _dietitian_profile_for_user(db, current_user)
    _assigned_patient_or_404(db, profile.id, user_id)
    note = db.query(DietitianNote).filter(
        DietitianNote.id == note_id,
        DietitianNote.dietitian_id == profile.id,
        DietitianNote.user_id == user_id,
    ).first()
    if note is None:
        raise HTTPException(status_code=404, detail="Not bulunamadı.")
    db.delete(note)
    db.commit()
    return _note_list_response(db, profile.id, user_id)


@router.patch(
    "/dietitian/profile",
    response_model=DietitianDashboardResponse,
    summary="Diyetisyen kendi profilini günceller",
)
async def update_dietitian_profile(
    request: DietitianProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Uzmanlık alanı, ad ve telefon kayıttan sonra da değiştirilebilir.

    E-posta kimlik doğrulamasına bağlı olduğu için burada değiştirilemez.
    """
    profile = _dietitian_profile_for_user(db, current_user)
    if request.full_name is not None:
        profile.full_name = request.full_name.strip()
        current_user.full_name = profile.full_name
    if request.specialization is not None:
        profile.specialization = request.specialization.strip()
    if request.phone is not None:
        profile.phone = request.phone
        # Numara değişince önceki doğrulama geçersizdir.
        profile.phone_verified = False
    db.commit()
    return await dietitian_dashboard(db=db, current_user=current_user)


# ═══════════════════════════════════════════════════════════════════════════════
# SAĞLIK ÖLÇÜMLERİ (SU, ADIM, UYKU, RUH HÂLİ, KİLO)
# ═══════════════════════════════════════════════════════════════════════════════

def _health_metric_for(db: Session, user_id: str, day) -> HealthMetric:
    """Güne ait ölçüm satırını döner; yoksa oluşturur."""
    row = db.query(HealthMetric).filter(
        HealthMetric.user_id == user_id,
        HealthMetric.log_date == day,
    ).first()
    if row is None:
        row = HealthMetric(
            id=str(uuid.uuid4()),
            user_id=user_id,
            log_date=day,
        )
        db.add(row)
    return row


def _health_metric_response(row: HealthMetric) -> HealthMetricResponse:
    return HealthMetricResponse(
        log_date=row.log_date,
        water_ml=row.water_ml or 0,
        steps=row.steps or 0,
        sleep_hours=float(row.sleep_hours or 0),
        mood=row.mood,
    )


@router.get(
    "/health-metrics/today",
    response_model=HealthMetricResponse,
    summary="Bugünün su, adım, uyku ve ruh hâli ölçümleri",
)
async def read_today_health_metrics(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    row = _health_metric_for(db, current_user.id, istanbul_date())
    db.commit()
    return _health_metric_response(row)


@router.put(
    "/health-metrics/today",
    response_model=HealthMetricResponse,
    summary="Bugünün ölçümlerini günceller",
)
async def update_today_health_metrics(
    request: HealthMetricUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Yalnız gönderilen alanlar değişir; gün başına tek satır tutulur."""
    row = _health_metric_for(db, current_user.id, istanbul_date())
    if request.water_ml is not None:
        row.water_ml = request.water_ml
    if request.steps is not None:
        row.steps = request.steps
    if request.sleep_hours is not None:
        row.sleep_hours = request.sleep_hours
    if request.mood is not None:
        # Boş metin "seçim yok" demektir.
        row.mood = request.mood.strip() or None
    db.commit()
    return _health_metric_response(row)


@router.get(
    "/health-metrics/weight",
    response_model=WeightHistoryResponse,
    summary="Kilo ölçüm geçmişi",
)
async def read_weight_history(
    limit: int = Query(default=30, ge=1, le=365),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _weight_history_response(db, current_user.id, limit)


def _weight_history_response(
    db: Session, user_id: str, limit: int = 30
) -> WeightHistoryResponse:
    """Kilo serisini eskiden yeniye sıralı döner."""
    rows = db.query(WeightMeasurement).filter(
        WeightMeasurement.user_id == user_id,
    ).order_by(WeightMeasurement.measured_at.desc()).limit(limit).all()
    ordered = list(reversed(rows))
    return WeightHistoryResponse(
        current_weight=float(ordered[-1].weight_kg) if ordered else None,
        measurements=[
            WeightMeasurementItem(
                measurement_id=item.id,
                weight_kg=float(item.weight_kg),
                measured_at=item.measured_at,
            )
            for item in ordered
        ],
    )


@router.post(
    "/health-metrics/weight",
    response_model=WeightHistoryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Yeni kilo ölçümü ekler",
)
async def add_weight_measurement(
    request: WeightMeasurementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    db.add(WeightMeasurement(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        weight_kg=request.weight_kg,
        measured_at=utc_now(),
    ))
    db.commit()
    return _weight_history_response(db, current_user.id)


# ═══════════════════════════════════════════════════════════════════════════════
# ÜRÜN RIZALARI (AYDINLATMADAN AYRI, AMAÇ BAZLI)
# ═══════════════════════════════════════════════════════════════════════════════

# Görüntüyü yurt dışına aktaran sağlayıcılar; KVKK m.9 kapsamındadır.
_CROSS_BORDER_VISION_MODES = frozenset({"google", "gemini"})

PRODUCT_CONSENT_TYPES = (
    "health_data_processing",
    "image_cross_border_transfer",
)


def _latest_consent(
    db: Session, user_id: str, consent_type: str
) -> ConsentRecord | None:
    """Bir amaç için en güncel rıza kaydını döner."""
    return db.query(ConsentRecord).filter(
        ConsentRecord.user_id == user_id,
        ConsentRecord.consent_type == consent_type,
    ).order_by(ConsentRecord.granted_at.desc()).first()


def _has_consent(db: Session, user_id: str, consent_type: str) -> bool:
    """Rıza verilmiş ve geri çekilmemiş mi.

    Kayıt yoksa rıza yok sayılır; sessiz kabul edilmez.
    """
    record = _latest_consent(db, user_id, consent_type)
    return bool(record and record.granted and record.revoked_at is None)


def _consent_state(db: Session, user_id: str) -> ProductConsentState:
    items = []
    flags = {}
    for consent_type in PRODUCT_CONSENT_TYPES:
        record = _latest_consent(db, user_id, consent_type)
        granted = bool(record and record.granted and record.revoked_at is None)
        flags[consent_type] = granted
        if record is not None:
            items.append(ProductConsentItem(
                consent_type=consent_type,
                granted=granted,
                policy_version=record.policy_version,
                updated_at=record.granted_at,
            ))
    return ProductConsentState(
        policy_version=settings.privacy_notice_version,
        consents=items,
        health_data_processing=flags["health_data_processing"],
        image_cross_border_transfer=flags["image_cross_border_transfer"],
    )


@router.get(
    "/consents",
    response_model=ProductConsentState,
    summary="Kullanıcının amaç bazlı rıza durumu",
)
async def read_product_consents(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _consent_state(db, current_user.id)


@router.put(
    "/consents",
    response_model=ProductConsentState,
    summary="Bir amaç için rıza ver veya geri çek",
)
async def update_product_consent(
    request: ProductConsentUpdate,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Rızayı kaydeder.

    Geri çekme kaydı silmez; yeni bir kayıt yazılır ki rızanın ne zaman
    verilip ne zaman geri alındığı kanıtlanabilsin.
    """
    db.add(ConsentRecord(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        consent_type=request.consent_type,
        policy_version=settings.privacy_notice_version,
        granted=request.granted,
        request_id=getattr(http_request.state, "request_id", None),
        granted_at=utc_now(),
        revoked_at=None if request.granted else utc_now(),
    ))
    db.add(AuthAuditLog(
        event="product_consent_updated",
        success=True,
        user_id=current_user.id,
        ip_address=http_request.client.host if http_request.client else None,
        reason=f"{request.consent_type}:{'granted' if request.granted else 'revoked'}",
        metadata_json={"policy_version": settings.privacy_notice_version},
    ))
    db.commit()
    return _consent_state(db, current_user.id)


@router.get("/dietitian/dashboard", response_model=DietitianDashboardResponse)
async def dietitian_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = _dietitian_profile_for_user(db, current_user)
    today = istanbul_date()
    week_start = today - timedelta(days=6)
    assignments = db.query(DietitianAssignment).filter(
        DietitianAssignment.dietitian_id == profile.id,
        DietitianAssignment.status == "approved",
    ).all()

    patients = []
    for assignment in assignments:
        patient = db.query(User).filter(User.id == assignment.user_id).first()
        if patient is None or not patient.is_active:
            continue
        active_logs = db.query(FoodLog).filter(
            FoodLog.user_id == patient.id,
            FoodLog.deleted_at.is_(None),
        )
        today_calories = db.query(func.coalesce(func.sum(FoodLog.total_calories), 0.0)).filter(
            FoodLog.user_id == patient.id,
            FoodLog.log_date == today,
            FoodLog.deleted_at.is_(None),
        ).scalar()
        seven_day_meals = active_logs.filter(FoodLog.log_date >= week_start).count()
        last_log = active_logs.order_by(FoodLog.logged_at.desc()).first()
        patients.append({
            "user_id": patient.id,
            "full_name": patient.full_name,
            "email": patient.email,
            "today_calories": float(today_calories or 0),
            "seven_day_meals": seven_day_meals,
            "last_log_at": last_log.logged_at if last_log else None,
            "daily_calorie_target": float(patient.daily_calorie_target or 2000),
            "assignment_id": assignment.id,
        })

    pending = db.query(DietitianAssignment).filter(
        DietitianAssignment.dietitian_id == profile.id,
        DietitianAssignment.status == "pending",
    ).count()
    report_count = db.query(DietitianReport).filter(
        DietitianReport.dietitian_id == profile.id,
    ).count()
    return DietitianDashboardResponse(
        dietitian_id=profile.id,
        full_name=profile.full_name,
        specialization=profile.specialization,
        email_verified=profile.email_verified,
        active_patients=len(patients),
        pending_assignments=pending,
        reports_received=report_count,
        patients=patients,
        pending_requests=_pending_requests_for(db, profile.id),
        recent_reports=_received_reports_for(db, profile.id, limit=5),
    )


@router.get(
    "/dietitian/patients/{patient_id}/history",
    response_model=DietitianPatientHistoryResponse,
)
async def dietitian_patient_history(
    patient_id: str,
    days: int = Query(default=30, ge=1, le=365),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = _dietitian_profile_for_user(db, current_user)
    relationship = db.query(DietitianAssignment).filter(
        DietitianAssignment.dietitian_id == profile.id,
        DietitianAssignment.user_id == patient_id,
        DietitianAssignment.status == "approved",
    ).first()
    if relationship is None:
        raise HTTPException(status_code=404, detail="Danışan bulunamadı.")
    patient = db.query(User).filter(
        User.id == patient_id,
        User.is_active.is_(True),
    ).first()
    if patient is None:
        raise HTTPException(status_code=404, detail="Danışan bulunamadı.")

    date_to = istanbul_date()
    date_from = date_to - timedelta(days=days - 1)
    logs = db.query(FoodLog).filter(
        FoodLog.user_id == patient.id,
        FoodLog.log_date >= date_from,
        FoodLog.log_date <= date_to,
        FoodLog.deleted_at.is_(None),
    ).order_by(FoodLog.logged_at.desc()).all()
    items = [
        DietitianPatientLogItem(
            id=log.id,
            food_name=log.food_name,
            food_name_tr=log.food_name_tr,
            meal_type=log.meal_type,
            portion_grams=log.estimated_portion_g,
            total_calories=log.total_calories,
            logged_at=log.logged_at,
        )
        for log in logs
    ]
    return DietitianPatientHistoryResponse(
        user_id=patient.id,
        full_name=patient.full_name,
        date_from=date_from,
        date_to=date_to,
        total_calories=sum(item.total_calories for item in items),
        total_meals=len(items),
        logs=items,
    )


@router.patch("/users/me", response_model=UserResponse)
async def update_me(
    request: UserProfileUpdate,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Allow correction of non-credential account and accessibility data."""
    for field in request.model_fields_set:
        setattr(current_user, field, getattr(request, field))
    current_user.updated_at = utc_now()
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    _audit_auth(
        db,
        event="profile_corrected",
        success=True,
        user_id=current_user.id,
        ip_address=http_request.client.host if http_request.client else None,
        reason=",".join(sorted(request.model_fields_set)),
    )
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        is_active=current_user.is_active,
        phone=current_user.phone,
        preferred_language=current_user.preferred_language,
        tts_speed=current_user.tts_speed,
        high_contrast=current_user.high_contrast,
    )


@router.get("/users/me/export")
async def export_my_data(
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Export only the authenticated user's product data; never token hashes."""
    logs = db.query(FoodLog).filter(FoodLog.user_id == current_user.id).all()
    assignments = db.query(DietitianAssignment).filter(
        DietitianAssignment.user_id == current_user.id
    ).all()
    health_metrics = db.query(HealthMetric).filter(
        HealthMetric.user_id == current_user.id,
    ).order_by(HealthMetric.log_date.asc()).all()
    weights = db.query(WeightMeasurement).filter(
        WeightMeasurement.user_id == current_user.id,
    ).order_by(WeightMeasurement.measured_at.asc()).all()
    reports = db.query(DietitianReport).filter(
        DietitianReport.user_id == current_user.id
    ).all()
    consents = db.query(ConsentRecord).filter(
        ConsentRecord.user_id == current_user.id
    ).all()

    payload = {
        "schema_version": "1.0",
        "generated_at": utc_now().isoformat(),
        "scope": "authenticated_product_account_only",
        "research_identity_note": (
            "Araştırma pseudonymi ürün hesabına bağlanmaz; araştırma verisi "
            "yalnız geri çekilme koduyla yönetilir."
        ),
        "account": {
            "id": current_user.id,
            "email": current_user.email,
            "full_name": current_user.full_name,
            "phone": current_user.phone,
            "is_active": current_user.is_active,
            "created_at": current_user.created_at.isoformat(),
            "updated_at": current_user.updated_at.isoformat(),
            "preferred_language": current_user.preferred_language,
            "tts_speed": current_user.tts_speed,
            "high_contrast": current_user.high_contrast,
        },
        "food_logs": [
            {
                "id": item.id,
                "food_name": item.food_name,
                "food_name_tr": item.food_name_tr,
                "canonical_food_id": item.canonical_food_id,
                "portion_value": float(item.portion_value),
                "portion_unit": item.portion_unit,
                "total_calories": float(item.total_calories),
                "recognition_source": item.recognition_source,
                "confirmed": item.is_user_confirmed,
                "corrected": item.is_corrected,
                "logged_at": item.logged_at.isoformat(),
                "deleted_at": item.deleted_at.isoformat() if item.deleted_at else None,
            }
            for item in logs
        ],
        "dietitian_assignments": [
            {
                "id": item.id,
                "dietitian_id": item.dietitian_id,
                "status": item.status,
                "created_at": item.created_at.isoformat(),
                "approved_at": item.approved_at.isoformat() if item.approved_at else None,
                "cancelled_at": item.cancelled_at.isoformat() if item.cancelled_at else None,
            }
            for item in assignments
        ],
        "report_shares": [
            {
                "id": item.id,
                "status": item.status,
                "report_type": item.report_type,
                "date_from": item.date_from.isoformat(),
                "date_to": item.date_to.isoformat(),
                "record_count": item.record_count,
                "channels": item.channels_json,
                "recipients_masked": item.recipient_snapshot_json,
                "created_at": item.created_at.isoformat(),
                "completed_at": item.completed_at.isoformat() if item.completed_at else None,
            }
            for item in reports
        ],
        "consents": [
            {
                "id": item.id,
                "type": item.consent_type,
                "policy_version": item.policy_version,
                "granted": item.granted,
                "channels": item.channels_json,
                "record_count": item.record_count,
                "recipient_masked": item.recipient_masked,
                "granted_at": item.granted_at.isoformat(),
                "revoked_at": item.revoked_at.isoformat() if item.revoked_at else None,
            }
            for item in consents
        ],
        # Sağlık ölçümleri de kişisel veridir; taşınabilirlik kapsamında
        # dışa aktarıma dahil edilir.
        "health_metrics": [
            {
                "log_date": item.log_date.isoformat(),
                "water_ml": item.water_ml,
                "steps": item.steps,
                "sleep_hours": float(item.sleep_hours or 0),
                "mood": item.mood,
            }
            for item in health_metrics
        ],
        "weight_measurements": [
            {
                "weight_kg": float(item.weight_kg),
                "measured_at": item.measured_at.isoformat(),
            }
            for item in weights
        ],
    }
    db.add(AuthAuditLog(
        event="personal_data_exported",
        success=True,
        user_id=current_user.id,
        ip_address=http_request.client.host if http_request.client else None,
        reason="self_service_json",
        metadata_json={
            "food_log_count": len(logs),
            "report_count": len(reports),
            "consent_count": len(consents),
            "health_metric_count": len(health_metrics),
            "weight_measurement_count": len(weights),
        },
    ))
    db.commit()
    return payload


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


_RESET_TOKEN_TTL = timedelta(hours=1)

# Yanıt her durumda aynıdır: e-posta kayıtlı olsun ya da olmasın. Aksi hâlde
# saldırgan hangi adreslerin sistemde olduğunu öğrenebilirdi.
_RESET_GENERIC_MESSAGE = (
    "E-posta adresiniz kayıtlıysa sıfırlama kodu gönderildi. "
    "Gelen kutunuzu kontrol edin."
)


def _hash_reset_token(token: str) -> str:
    """Jetonun veritabanında saklanan SHA-256 özeti."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


@router.post(
    "/auth/password-reset",
    response_model=PasswordResetResponse,
    summary="Parola sıfırlama kodu iste",
)
async def request_password_reset(
    request: PasswordResetRequest,
    db: Session = Depends(get_db),
):
    """Kayıtlı bir e-posta için tek kullanımlık sıfırlama kodu gönderir."""
    normalized_email = request.email.lower()
    user = (
        db.query(User)
        .filter(func.lower(User.email) == normalized_email)
        .first()
    )

    if user is not None and user.is_active:
        # Bekleyen eski jetonları geçersiz kıl: aynı anda tek jeton geçerli.
        db.query(PasswordResetToken).filter(
            PasswordResetToken.user_id == user.id,
            PasswordResetToken.used_at.is_(None),
        ).update({"used_at": utc_now()}, synchronize_session=False)

        # 8 haneli sayısal kod: ekran okuyucuyla dinlemesi ve sesle
        # söylemesi uzun rastgele dizelerden çok daha kolay.
        reset_code = f"{secrets.randbelow(10**8):08d}"
        db.add(
            PasswordResetToken(
                id=str(uuid.uuid4()),
                user_id=user.id,
                token_hash=_hash_reset_token(reset_code),
                expires_at=utc_now() + _RESET_TOKEN_TTL,
            )
        )
        db.add(
            AuthAuditLog(
                user_id=user.id,
                event="password_reset_requested",
                email_hash=_hash_reset_token(normalized_email),
                success=True,
            )
        )
        db.commit()

        try:
            message = build_password_reset_email(
                reset_code=reset_code,
                destination=user.email,
                settings=get_settings(),
            )
            await notification_service.send_email_message(message, user.email)
        except ChannelDeliveryError:
            # Gönderim başarısız olsa bile aynı yanıt döner; kullanıcıya
            # hesabın varlığı sızdırılmaz. Hata yalnız log'a yazılır.
            logger.warning("Parola sıfırlama e-postası gönderilemedi.")

    return PasswordResetResponse(message=_RESET_GENERIC_MESSAGE)


@router.post(
    "/auth/password-reset/confirm",
    response_model=PasswordResetResponse,
    summary="Kod ile yeni parola belirle",
)
async def confirm_password_reset(
    request: PasswordResetConfirm,
    db: Session = Depends(get_db),
):
    """Geçerli bir kodla parolayı değiştirir ve tüm oturumları kapatır."""
    token_hash = _hash_reset_token(request.token.strip())
    record = (
        db.query(PasswordResetToken)
        .filter(PasswordResetToken.token_hash == token_hash)
        .first()
    )

    now = utc_now()
    if (
        record is None
        or record.used_at is not None
        or record.expires_at.replace(tzinfo=record.expires_at.tzinfo or timezone.utc)
        < now
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Kod geçersiz veya süresi dolmuş. Yeni bir kod isteyin.",
        )

    user = db.query(User).filter(User.id == record.user_id).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Kod geçersiz veya süresi dolmuş. Yeni bir kod isteyin.",
        )

    user.hashed_password = hash_password(request.new_password)
    user.updated_at = now
    record.used_at = now

    # Parola değişince mevcut oturumlar güvenli değildir; hepsi iptal edilir.
    db.query(RefreshToken).filter(
        RefreshToken.user_id == user.id,
        RefreshToken.revoked_at.is_(None),
    ).update({"revoked_at": now}, synchronize_session=False)

    db.add(
        AuthAuditLog(
            user_id=user.id,
            event="password_reset_completed",
            success=True,
        )
    )
    db.commit()

    return PasswordResetResponse(
        message="Parolanız güncellendi. Yeni parolanızla giriş yapabilirsiniz.",
    )
