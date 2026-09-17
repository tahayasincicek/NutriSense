# ==============================================================================
# backend/app/models/__init__.py
# ==============================================================================
from .database import (
    AuditEvent, AuthAuditLog, Base, ConsentRecord, Dietitian,
    DietitianAssignment, DietitianReport, FoodLog, NotificationDelivery,
    NutritionSource, PendingEmailChange, RateLimitBucket, RecognitionAttempt,
    RefreshToken, SurveySubmission,
    SurveyVersion, UsabilitySession, UsabilityTask, User, get_db, utc_now,
)
from .schemas import (
    FoodAnalysisResponse,
    FoodHistoryResponse, DailyLogResponse, FoodLogDeleteResponse, FoodLogItem,
    FoodLogUpdateRequest,
    SendToDietitianRequest, SendToDietitianResponse,
    LogoutRequest, RefreshTokenRequest, TokenResponse, UserCreate, UserLogin,
    ErrorResponse,
)
