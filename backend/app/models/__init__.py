# ==============================================================================
# backend/app/models/__init__.py
# ==============================================================================
from .database import (
    AuthAuditLog, Base, Dietitian, DietitianAssignment, DietitianReport,
    FoodLog, RefreshToken, User, get_db, init_db,
)
from .schemas import (
    FoodAnalysisResponse,
    FoodHistoryResponse, DailyLogResponse, FoodLogItem,
    SendToDietitianRequest, SendToDietitianResponse,
    LogoutRequest, RefreshTokenRequest, TokenResponse, UserCreate, UserLogin,
    ErrorResponse,
)
