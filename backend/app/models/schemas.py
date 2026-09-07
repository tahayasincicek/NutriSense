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


class NutritionProvenanceData(BaseModel):
    source: str
    source_item_id: str
    locale: str
    retrieved_at: datetime
    serving_unit: str
    serving_grams: float = Field(..., gt=0, le=2000, allow_inf_nan=False)
    license_name: str
    attribution: str


class PortionOption(BaseModel):
    unit: Literal["adet", "dilim", "kase", "ml", "litre"]
    # Hacim birimlerinde bu alan bir porsiyon ağırlığı değil, yoğunluktur:
    # bir mililitre yaklaşık bir gramdır, bir litre bin gram. Sayılabilir
    # birimlerin üst sınırı ikisini birden karşılamıyordu.
    grams_per_unit: float = Field(..., gt=0, le=2000, allow_inf_nan=False)
    source_item_id: str
    source_name: str


# Porsiyon birimi başına üst sınır.
#
# Sayılabilir birimlerde 20 tavanı yeterli; hacimde aynı sayıyı kullanmak
# 20 ml'de kesip bir bardak suyu bile kaydettirmezdi.
PORTION_LIMITS: dict[str, float] = {
    "gram": 2000,
    "adet": 20,
    "dilim": 20,
    "kase": 20,
    "ml": 3000,
    "litre": 3,
}


class FoodAnalysisResponse(BaseModel):
    """Multipart POST /api/v1/analyze-food yanıt gövdesi."""
    analysis_id: UUID = Field(..., description="Onay bekleyen analiz UUID")
    log_id: Optional[UUID] = Field(
        None,
        description="Analiz aşamasında null; yalnız karar endpointi günlük kaydı üretir",
    )
    food_name: str = Field(..., description="Dil bağımsız kanonik besin anahtarı")
    food_name_tr: str = Field(..., description="Besin adı (Türkçe)")
    canonical_food_id: str
    normalization_version: str
    confidence: float = Field(..., ge=0, le=1.0)
    portion_grams: Optional[float] = Field(None, gt=0, le=2000, allow_inf_nan=False)
    portion_value: Optional[float] = Field(None, gt=0, allow_inf_nan=False)
    portion_unit: Optional[Literal["gram", "adet", "dilim", "kase", "ml", "litre"]] = None
    portion_method: Optional[Literal["source_default", "user_selected", "user_voice"]] = None
    portion_is_estimate: bool = True
    calories_per_100g: Optional[float] = Field(None, gt=0, allow_inf_nan=False)
    total_calories: Optional[float] = Field(None, gt=0, allow_inf_nan=False)
    nutrients: Optional[NutrientData] = None
    nutrients_per_100g: Optional[NutrientData] = None
    macro_calories: Optional[float] = Field(None, ge=0, allow_inf_nan=False)
    macro_calorie_delta: Optional[float] = Field(None, allow_inf_nan=False)
    macro_calorie_delta_percent: Optional[float] = Field(None, ge=0, allow_inf_nan=False)
    meal_type: str
    recognition_source: str
    nutrition_source: str
    nutrition_status: Literal["available", "unverified", "not_found"]
    nutrition_reliability: Literal[
        "verified_provider", "verified_local", "estimated",
        "user_entered", "unverified", "not_found",
    ]
    provenance: Optional[NutritionProvenanceData] = None
    portion_options: list[PortionOption] = Field(default_factory=list)
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
    portion_value: Optional[float] = Field(None, gt=0, allow_inf_nan=False)
    portion_unit: Optional[Literal["gram", "adet", "dilim", "kase", "ml", "litre"]] = None
    portion_method: Optional[Literal["user_selected", "user_voice"]] = None

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
        portion_fields = (self.portion_value, self.portion_unit, self.portion_method)
        if any(value is not None for value in portion_fields) and not all(
            value is not None for value in portion_fields
        ):
            raise ValueError("Porsiyon değeri, birimi ve yöntemi birlikte gönderilmelidir.")
        if self.portion_value is not None and self.portion_unit is not None:
            limit = PORTION_LIMITS[self.portion_unit]
            if self.portion_value > limit:
                raise ValueError(
                    f"{self.portion_unit} porsiyonu {limit} değerini aşamaz."
                )
        return self


class FoodPortionRequest(BaseModel):
    portion_value: float = Field(..., gt=0, allow_inf_nan=False)
    portion_unit: Literal["gram", "adet", "dilim", "kase", "ml", "litre"]
    portion_method: Literal["user_selected", "user_voice"]

    @model_validator(mode="after")
    def validate_portion_limit(self):
        limit = PORTION_LIMITS[self.portion_unit]
        if self.portion_value > limit:
            raise ValueError(f"Porsiyon {limit} değerini aşamaz.")
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
    portion_value: float = Field(default=100, gt=0, allow_inf_nan=False)
    portion_unit: Literal["gram", "adet", "dilim", "kase", "ml", "litre"] = "gram"
    portion_method: Literal["user_selected", "user_voice"] = "user_selected"

    @model_validator(mode="after")
    def validate_portion_limit(self):
        limit = PORTION_LIMITS[self.portion_unit]
        if self.portion_value > limit:
            raise ValueError(f"Porsiyon {limit} değerini aşamaz.")
        return self

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
    canonical_food_id: str
    calories: float
    calories_per_100g: float
    portion_g: float
    portion_value: float
    portion_unit: str
    portion_method: str
    portion_is_estimate: bool
    meal_type: str
    confidence: float
    recognition_source: str
    nutrition_source: str
    nutrition_reliability: str
    is_corrected: bool
    is_user_confirmed: bool
    nutrients: NutrientData
    logged_at: datetime
    updated_at: datetime


class FoodLogUpdateRequest(BaseModel):
    """User-visible corrections without silently replacing nutrition identity."""

    food_name_tr: Optional[str] = Field(None, min_length=2, max_length=120)
    portion_g: Optional[float] = Field(None, gt=0, le=2000, allow_inf_nan=False)
    # Kayıt mililitre ya da adetle girildiyse düzeltme de o birimde yapılır.
    # Yalnız gram kabul etmek, 97 ml'lik bir kaydı düzenlerken sayıyı gram
    # sanıp miktarı sessizce değiştiriyordu.
    portion_value: Optional[float] = Field(None, gt=0, allow_inf_nan=False)
    portion_unit: Optional[Literal["adet", "dilim", "kase", "ml", "litre"]] = None
    meal_type: Optional[Literal[
        "kahvalti", "ogle", "aksam", "atistirmalik"
    ]] = None

    @model_validator(mode="after")
    def require_change(self):
        if (self.portion_value is None) != (self.portion_unit is None):
            raise ValueError("Porsiyon değeri ve birimi birlikte gönderilmelidir.")
        if self.portion_g is not None and self.portion_value is not None:
            raise ValueError("Porsiyon ya gram ya da birimle gönderilmelidir.")
        if (
            self.food_name_tr is None
            and self.portion_g is None
            and self.portion_value is None
            and self.meal_type is None
        ):
            raise ValueError("En az bir düzeltme alanı gönderilmelidir.")
        if self.portion_value is not None:
            limit = PORTION_LIMITS[self.portion_unit]
            if self.portion_value > limit:
                raise ValueError(f"Porsiyon {limit} değerini aşamaz.")
        if self.food_name_tr is not None:
            self.food_name_tr = self.food_name_tr.strip()
        return self


class FoodLogDeleteResponse(BaseModel):
    log_id: UUID
    status: Literal["deleted", "restored"]
    message: str


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
    total_log_count: int
    total_date_count: int
    page: int
    page_size: int
    has_more: bool
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
    channels: list[Literal["email", "sms"]] = Field(
        ..., min_length=1, max_length=2,
    )
    consent_context_hash: str = Field(..., min_length=64, max_length=64)
    consent: Literal[True] = Field(
        ...,
        description="Kullanıcının bu rapor gönderimine verdiği açık onay",
    )

    @field_validator("channels")
    @classmethod
    def unique_channels(cls, value: list[str]) -> list[str]:
        if len(value) != len(set(value)):
            raise ValueError("Aynı gönderim kanalı birden fazla seçilemez.")
        return value


class DietitianReportPreviewRequest(BaseModel):
    user_id: UUID
    report_type: str = Field(default="weekly", pattern=r"^(daily|weekly|monthly)$")
    from_date: Optional[date] = None
    to_date: Optional[date] = None
    message: Optional[str] = Field(None, max_length=500)
    channels: list[Literal["email", "sms"]] = Field(
        ..., min_length=1, max_length=2,
    )

    @field_validator("channels")
    @classmethod
    def unique_preview_channels(cls, value: list[str]) -> list[str]:
        if len(value) != len(set(value)):
            raise ValueError("Aynı gönderim kanalı birden fazla seçilemez.")
        return value


class DietitianReportPreviewResponse(BaseModel):
    report_type: str
    from_date: date
    to_date: date
    record_count: int
    total_calories: float
    average_daily_calories: float
    estimated_portion_count: int
    dietitian_name: str
    recipients: dict[str, str]
    channels: list[str]
    consent_context_hash: str
    accessibility_summary: str


class ChannelDeliveryResponse(BaseModel):
    channel: str
    status: str
    destination_masked: str
    attempt_count: int
    max_attempts: int
    provider_status: Optional[str] = None
    error_code: Optional[str] = None


class SendToDietitianResponse(BaseModel):
    """POST /api/v1/send-to-dietitian yanıt gövdesi."""
    success: bool
    report_id: UUID
    sent_via_email: bool
    sent_via_sms: bool
    dietitian_name: str
    status: str
    channels: list[ChannelDeliveryResponse]
    duplicate: bool = False
    message: str  # Türkçe durum mesajı


class DietitianReportHistoryItem(BaseModel):
    report_id: UUID
    report_type: str
    from_date: date
    to_date: date
    record_count: int
    status: str
    created_at: datetime
    completed_at: Optional[datetime] = None
    channels: list[ChannelDeliveryResponse]
    # Diyetisyen cevabı; hasta kendi rapor geçmişinde görür.
    dietitian_reply: Optional[str] = None
    dietitian_replied_at: Optional[datetime] = None


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
    phone: Optional[str] = None
    preferred_language: str = "tr-TR"
    tts_speed: float = 0.5
    high_contrast: bool = True
    account_type: Literal["patient", "dietitian"] = "patient"


class DietitianCreate(BaseModel):
    """Diyetisyen hesabı ve profilini birlikte oluşturur."""

    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    full_name: str = Field(..., min_length=2, max_length=255)
    phone: Optional[str] = Field(default=None, pattern=r"^\+?[1-9][0-9]{7,14}$")
    specialization: str = Field(default="Beslenme ve Diyet", min_length=2, max_length=255)

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, value: str) -> str:
        if not any(character.isalpha() for character in value):
            raise ValueError("Şifre en az bir harf içermelidir.")
        if not any(character.isdigit() for character in value):
            raise ValueError("Şifre en az bir rakam içermelidir.")
        return value


class DietitianDashboardPatient(BaseModel):
    user_id: UUID
    full_name: str
    email: EmailStr
    today_calories: float
    seven_day_meals: int
    last_log_at: Optional[datetime] = None
    # Hedefle karşılaştırma ve takip uyarısı istemcide hesaplanır.
    daily_calorie_target: float = 2000.0
    # Diyetisyenin bağı sonlandırabilmesi için.
    assignment_id: Optional[UUID] = None


class DietitianReceivedReport(BaseModel):
    """Diyetisyenin aldığı, danışan onaylı beslenme raporu."""
    report_id: UUID
    patient_id: UUID
    patient_name: str
    report_type: str
    from_date: date
    to_date: date
    record_count: int
    total_meals: int
    total_calories: float
    status: str
    created_at: datetime
    delivered_via_email: bool
    delivered_via_sms: bool


class DietitianReceivedReportList(BaseModel):
    reports: list[DietitianReceivedReport]


class DietitianReportRecord(BaseModel):
    """Rapor içindeki tek besin kaydı.

    Alanlar proje raporunun diyetisyene vaat ettiği kümedir: besin adı,
    miktar, tarih/saat ve kalori değeri.
    """
    food_name_tr: str
    portion_grams: float
    portion_is_estimate: bool
    total_calories: float
    protein: float
    carbs: float
    fat: float
    meal_type: str
    logged_at: datetime
    is_corrected: bool


class DietitianReportDay(BaseModel):
    date: date
    calories: float
    record_count: int


class DietitianReportDetail(BaseModel):
    report_id: UUID
    patient_name: str
    report_type: str
    from_date: date
    to_date: date
    record_count: int
    total_calories: float
    average_daily_calories: float
    estimated_portion_count: int
    status: str
    created_at: datetime
    disclaimer: str
    # Danışanın gönderim sırasında yazdığı isteğe bağlı not/soru.
    patient_note: Optional[str] = None
    # Diyetisyenin bu rapora yazdığı cevap.
    dietitian_reply: Optional[str] = None
    dietitian_replied_at: Optional[datetime] = None
    records: list[DietitianReportRecord]
    daily_breakdown: list[DietitianReportDay]


class HealthMetricUpdate(BaseModel):
    """Günlük ölçüm güncellemesi. Yalnız gönderilen alanlar değişir."""
    water_ml: Optional[int] = Field(default=None, ge=0, le=100000)
    steps: Optional[int] = Field(default=None, ge=0, le=500000)
    sleep_hours: Optional[float] = Field(default=None, ge=0, le=24)
    mood: Optional[str] = Field(default=None, max_length=32)


class HealthMetricResponse(BaseModel):
    log_date: date
    water_ml: int
    steps: int
    sleep_hours: float
    mood: Optional[str] = None


class WeightMeasurementCreate(BaseModel):
    weight_kg: float = Field(..., gt=0, le=500)


class WeightMeasurementItem(BaseModel):
    measurement_id: UUID
    weight_kg: float
    measured_at: datetime


class WeightHistoryResponse(BaseModel):
    current_weight: Optional[float] = None
    measurements: list[WeightMeasurementItem]


class ProductConsentUpdate(BaseModel):
    """Amaç bazlı ürün rızası.

    Aydınlatma metninden ayrı olarak, her amaç için tek tek alınır; KVKK
    açık rızanın belirli bir konuya ilişkin olmasını arar.
    """
    consent_type: Literal[
        "health_data_processing",
        "image_cross_border_transfer",
    ]
    granted: bool


class ProductConsentItem(BaseModel):
    consent_type: str
    granted: bool
    policy_version: str
    updated_at: datetime


class ProductConsentState(BaseModel):
    policy_version: str
    consents: list[ProductConsentItem]

    # İstemcinin akışı kurabilmesi için özet bayraklar.
    health_data_processing: bool = False
    image_cross_border_transfer: bool = False


class DietitianReplyRequest(BaseModel):
    """Diyetisyenin rapora yazdığı cevap."""
    reply: str = Field(..., min_length=2, max_length=2000)


class DietitianNoteRequest(BaseModel):
    """Diyetisyenin danışan için yazdığı not."""

    body: str = Field(min_length=1, max_length=4000)


class DietitianNoteItem(BaseModel):
    """Kayıtlı tek not."""

    id: UUID
    body: str
    created_at: datetime


class DietitianNoteList(BaseModel):
    """Danışanın notları, yeniden eskiye."""

    user_id: UUID
    items: list[DietitianNoteItem] = Field(default_factory=list)


class DietitianProfileUpdate(BaseModel):
    """Diyetisyenin kendi profilinde değiştirebildiği alanlar."""
    full_name: Optional[str] = Field(default=None, min_length=2, max_length=255)
    specialization: Optional[str] = Field(
        default=None, min_length=2, max_length=255
    )
    phone: Optional[str] = Field(default=None, pattern=r"^\+?[1-9][0-9]{7,14}$")


class DietitianPendingRequest(BaseModel):
    """Diyetisyenin kabul/ret bekleyen eşleşme isteği."""
    assignment_id: UUID
    patient_name: str
    patient_email_masked: str
    requested_at: datetime
    patient_approved: bool


class DietitianPendingRequestList(BaseModel):
    requests: list[DietitianPendingRequest]


class DietitianDashboardResponse(BaseModel):
    dietitian_id: UUID
    full_name: str
    specialization: str
    email_verified: bool
    active_patients: int
    pending_assignments: int
    reports_received: int
    patients: list[DietitianDashboardPatient]
    pending_requests: list[DietitianPendingRequest] = []
    recent_reports: list[DietitianReceivedReport] = []


class DietitianPatientLogItem(BaseModel):
    id: UUID
    food_name: str
    food_name_tr: str
    meal_type: str
    portion_grams: float
    total_calories: float
    logged_at: datetime


class DietitianPatientHistoryResponse(BaseModel):
    user_id: UUID
    full_name: str
    date_from: date
    date_to: date
    total_calories: float
    total_meals: int
    logs: list[DietitianPatientLogItem]


class UserProfileUpdate(BaseModel):
    full_name: Optional[str] = Field(default=None, min_length=2, max_length=255)
    phone: Optional[str] = Field(default=None, pattern=r"^\+?[1-9][0-9]{7,14}$")
    preferred_language: Optional[Literal["tr-TR"]] = None
    tts_speed: Optional[float] = Field(default=None, ge=0.1, le=1.0)
    high_contrast: Optional[bool] = None

    @model_validator(mode="after")
    def require_change(self):
        if not self.model_fields_set:
            raise ValueError("En az bir profil alanı gönderilmelidir.")
        return self


class AccountDeletionRequest(BaseModel):
    password: str
    confirmation: Literal["HESABIMI SIL"]


class PasswordResetRequest(BaseModel):
    """Parola sıfırlama bağlantısı talebi."""

    email: EmailStr


class PasswordResetConfirm(BaseModel):
    """Jeton ile yeni parola belirleme."""

    # 8 haneli sayısal kod: ekran okuyucuyla dinlemesi ve sesle söylemesi
    # uzun rastgele dizelerden çok daha kolay.
    token: str = Field(..., min_length=8, max_length=128)
    new_password: str = Field(..., min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def validate_password_strength(cls, value: str) -> str:
        if not any(character.isalpha() for character in value):
            raise ValueError("Şifre en az bir harf içermelidir.")
        if not any(character.isdigit() for character in value):
            raise ValueError("Şifre en az bir rakam içermelidir.")
        return value


class PasswordResetResponse(BaseModel):
    """Her iki uçta da aynı gövde döner; hesap varlığı sızdırılmaz."""

    message: str


class DietitianAssignmentRequest(BaseModel):
    dietitian_email: EmailStr


class DietitianAssignmentResponse(BaseModel):
    assignment_id: UUID
    status: str
    dietitian_id: UUID
    dietitian_name: str
    email_verified: bool
    phone_verified: bool
    email_masked: Optional[str] = None
    phone_masked: Optional[str] = None
    # Bağın hangi onayı beklediğini istemcinin doğru anlatabilmesi için.
    patient_approved: bool = False
    dietitian_accepted: bool = False
    awaiting: Optional[str] = None


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
