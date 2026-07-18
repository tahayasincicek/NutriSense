# ==============================================================================
# backend/app/models/schemas.py
# NutriSense — Pydantic Request/Response Şemaları
#
# Tip güvenli input validation ve JSON serialization.
# Tüm hata mesajları Türkçe (Flutter TTS ile okunacak).
# ==============================================================================

from datetime import datetime, date
from typing import Any, Literal, Optional
from uuid import UUID

from pydantic import (
    BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator,
)


# ═══════════════════════════════════════════════════════════════════════════════
# BESİN ANALİZİ
# ═══════════════════════════════════════════════════════════════════════════════

class NutrientData(BaseModel):
    """Besin değerleri."""
    protein: float = Field(0.0, ge=0, description="Protein (g)")
    carbs: float = Field(0.0, ge=0, description="Karbonhidrat (g)")
    fat: float = Field(0.0, ge=0, description="Yağ (g)")
    fiber: float = Field(0.0, ge=0, description="Lif (g)")


class FoodCandidate(BaseModel):
    """Modelin sıralı adaylarından biri; besin güveniyle kalori kaynağını karıştırmaz."""

    food_name: str
    food_name_tr: str
    confidence: float = Field(..., ge=0, le=1.0)


class FoodAnalysisResponse(BaseModel):
    """Multipart POST /api/v1/analyze-food yanıt gövdesi."""
    analysis_id: UUID = Field(..., description="Onay bekleyen analiz UUID")
    log_id: Optional[UUID] = Field(
        None,
        description="Analiz aşamasında null; yalnız karar endpointi günlük kaydı üretir",
    )
    food_name: str = Field(..., description="Dil bağımsız kanonik besin anahtarı")
    food_name_tr: str = Field(..., description="Besin adı (Türkçe)")
    confidence: float = Field(..., ge=0, le=1.0)
    portion_grams: float = Field(..., ge=0)
    calories_per_100g: float = Field(..., ge=0)
    total_calories: float = Field(..., ge=0)
    nutrients: NutrientData
    meal_type: str
    recognition_source: str
    nutrition_source: str
    nutrition_status: Literal["available", "unverified", "not_found"]
    candidates: list[FoodCandidate] = Field(default_factory=list, max_length=3)
    needs_confirmation: bool
    can_confirm: bool
    tts_text: str = Field(..., description="TTS ile okunacak metin")

    model_config = ConfigDict(
        extra="ignore",
        json_schema_extra={
            "example": {
                "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
                "log_id": None,
                "food_name": "elma",
                "food_name_tr": "Elma",
                "confidence": 0.93,
                "portion_grams": 150.0,
                "calories_per_100g": 52.0,
                "total_calories": 78.0,
                "nutrients": {
                    "protein": 0.4,
                    "carbs": 20.7,
                    "fat": 0.3,
                    "fiber": 3.6,
                },
                "meal_type": "atistirmalik",
                "recognition_source": "google_vision",
                "nutrition_source": "nutritionix",
                "nutrition_status": "available",
                "candidates": [
                    {"food_name": "elma", "food_name_tr": "Elma", "confidence": 0.93}
                ],
                "needs_confirmation": True,
                "can_confirm": True,
                "tts_text": "Elma bulundu. Kaydetmeden önce sonucu onaylayın.",
            }
        },
    )


class FoodAnalysisDecisionRequest(BaseModel):
    action: Literal["confirm", "correct", "reject"]
    corrected_food_name: Optional[str] = Field(None, min_length=2, max_length=120)
    corrected_food_name_tr: Optional[str] = Field(None, min_length=2, max_length=120)

    @field_validator("corrected_food_name")
    @classmethod
    def normalize_food_key(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        normalized = value.strip().lower().replace(" ", "_")
        if not normalized.replace("_", "").isalnum():
            raise ValueError("Düzeltilen besin adı yalnız harf, rakam ve boşluk içerebilir.")
        return normalized

    @field_validator("corrected_food_name_tr")
    @classmethod
    def strip_display_name(cls, value: Optional[str]) -> Optional[str]:
        return value.strip() if value is not None else None

    @model_validator(mode="after")
    def validate_correction_fields(self):
        if self.action == "correct" and not self.corrected_food_name:
            raise ValueError("Düzeltme için corrected_food_name zorunludur.")
        if self.action != "correct" and (
            self.corrected_food_name is not None
            or self.corrected_food_name_tr is not None
        ):
            raise ValueError("Düzeltme alanları yalnız correct işleminde gönderilebilir.")
        return self


class FoodAnalysisDecisionResponse(BaseModel):
    analysis_id: UUID
    log_id: Optional[UUID] = None
    status: Literal["confirmed", "corrected", "rejected", "already_saved"]
    message: str


class ManualFoodLogRequest(BaseModel):
    capture_id: UUID
    food_name: str = Field(..., min_length=2, max_length=120)
    food_name_tr: Optional[str] = Field(None, min_length=2, max_length=120)
    meal_type: str = Field(
        default="atistirmalik",
        pattern=r"^(kahvalti|ogle|aksam|atistirmalik)$",
    )
    confirmed: Literal[True]

    @field_validator("food_name")
    @classmethod
    def normalize_manual_food_key(cls, value: str) -> str:
        normalized = value.strip().lower().replace(" ", "_")
        if not normalized.replace("_", "").isalnum():
            raise ValueError("Besin adı yalnız harf, rakam ve boşluk içerebilir.")
        return normalized


# ═══════════════════════════════════════════════════════════════════════════════
# YEMEK GEÇMİŞİ
# ═══════════════════════════════════════════════════════════════════════════════

class FoodLogItem(BaseModel):
    """Tek besin kaydı."""
    id: UUID
    food_name: str
    food_name_tr: str
    calories: float
    portion_g: float
    meal_type: str
    confidence: float
    nutrients: NutrientData
    logged_at: datetime


class MealSummary(BaseModel):
    """Öğün bazlı özet."""
    meal_type: str
    meal_type_tr: str
    total_calories: float
    food_count: int


class DailyLogResponse(BaseModel):
    """Günlük besin özeti."""
    date: date
    total_calories: float
    calorie_target: float
    remaining_calories: float
    total_protein: float
    total_carbs: float
    total_fat: float
    meal_count: int
    meals: list[MealSummary]
    foods: list[FoodLogItem]


class FoodHistoryResponse(BaseModel):
    """GET /api/v1/food-history/{user_id} yanıt gövdesi."""
    user_id: UUID
    from_date: date
    to_date: date
    total_days: int
    average_daily_calories: float
    total_calories: float
    daily_logs: list[DailyLogResponse]


# ═══════════════════════════════════════════════════════════════════════════════
# DİYETİSYEN
# ═══════════════════════════════════════════════════════════════════════════════

class SendToDietitianRequest(BaseModel):
    """POST /api/v1/send-to-dietitian istek gövdesi."""
    user_id: UUID
    report_type: str = Field(
        default="weekly",
        pattern=r"^(daily|weekly|monthly)$",
    )
    from_date: Optional[date] = None
    to_date: Optional[date] = None
    message: Optional[str] = Field(None, max_length=500)
    consent: Literal[True] = Field(
        ...,
        description="Kullanıcının bu rapor gönderimine verdiği açık onay",
    )


class SendToDietitianResponse(BaseModel):
    """POST /api/v1/send-to-dietitian yanıt gövdesi."""
    success: bool
    report_id: UUID
    sent_via_email: bool
    sent_via_sms: bool
    dietitian_name: str
    message: str  # Türkçe durum mesajı


# ═══════════════════════════════════════════════════════════════════════════════
# KİMLİK DOĞRULAMA
# ═══════════════════════════════════════════════════════════════════════════════

class UserCreate(BaseModel):
    """Kullanıcı kayıt."""
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    full_name: str = Field(..., min_length=2, max_length=255)
    phone: Optional[str] = None
    daily_calorie_target: float = Field(default=2000.0, ge=500, le=10000)

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, value: str) -> str:
        if not any(character.isalpha() for character in value):
            raise ValueError("Şifre en az bir harf içermelidir.")
        if not any(character.isdigit() for character in value):
            raise ValueError("Şifre en az bir rakam içermelidir.")
        return value


class UserLogin(BaseModel):
    """Kullanıcı giriş."""
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: UUID
    email: EmailStr
    full_name: str
    is_active: bool


class AccountDeletionRequest(BaseModel):
    password: str
    confirmation: Literal["HESABIMI SIL"]


class DietitianAssignmentRequest(BaseModel):
    dietitian_email: EmailStr


class DietitianAssignmentResponse(BaseModel):
    assignment_id: UUID
    status: str
    dietitian_id: UUID
    dietitian_name: str
    email_verified: bool
    phone_verified: bool


class TokenResponse(BaseModel):
    """JWT token yanıtı."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    refresh_expires_in: int
    user_id: UUID
    full_name: str


class RefreshTokenRequest(BaseModel):
    """Tek kullanımlık, rotation uygulanan refresh token isteği."""

    refresh_token: str = Field(..., min_length=20)


class LogoutRequest(BaseModel):
    """Mevcut refresh token ailesindeki aktif token'ı revoke eder."""

    refresh_token: str = Field(..., min_length=20)


# ═══════════════════════════════════════════════════════════════════════════════
# HATA
# ═══════════════════════════════════════════════════════════════════════════════

class ErrorDetail(BaseModel):
    code: str = "UNKNOWN_ERROR"
    message: str
    request_id: Optional[str] = None
    details: Any = None


class ErrorResponse(BaseModel):
    """Tüm başarısız yanıtlar için kanonik, TTS'den bağımsız hata gövdesi."""

    error: ErrorDetail
