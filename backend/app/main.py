# ==============================================================================
# backend/app/main.py
# NutriSense — FastAPI Uygulama Giriş Noktası
#
# Çalıştırma:
#   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
#
# Swagger Docs:
#   http://localhost:8000/docs
# ==============================================================================

import logging
import re
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import text

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse

from .config import get_settings
from .models.database import engine
from .security.logging import configure_secure_logging
from .routers.food_router import router as food_router
from .routers.survey_router import router as survey_router

settings = get_settings()
BACKEND_DIR = Path(__file__).resolve().parent.parent

# ── Logging ──
configure_secure_logging(debug=settings.debug)
logger = logging.getLogger("nutrisense")
REQUEST_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$")


# ═══════════════════════════════════════════════════════════════════════════════
# UYGULAMA YAŞAM DÖNGÜSÜ
# ═══════════════════════════════════════════════════════════════════════════════

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Uygulama başlangıç ve kapanış işlemleri."""
    settings.validate_security()
    # Başlangıç
    logger.info("=" * 60)
    logger.info(f"  {settings.app_name} v{settings.app_version} başlatılıyor...")
    logger.info("=" * 60)

    if settings.app_environment.lower() != "test":
        readiness = database_readiness()
        if not readiness["ready"]:
            raise RuntimeError(
                "Veritabanı migration durumu hazır değil; önce 'alembic upgrade head' çalıştırın."
            )
        logger.info("Veritabanı bağlantısı ve Alembic revision hazır")

    yield

    # Kapanış
    logger.info("NutriSense kapatılıyor...")


# ═══════════════════════════════════════════════════════════════════════════════
# FASTAPI UYGULAMASI
# ═══════════════════════════════════════════════════════════════════════════════

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description=(
        "Görme engelli bireyler için yapay zeka destekli besin tanıma "
        "ve kalori takip API'si. Google Vision + Nutritionix entegrasyonu."
    ),
    docs_url="/docs" if settings.api_docs_enabled else None,
    redoc_url="/redoc" if settings.api_docs_enabled else None,
    openapi_url="/openapi.json" if settings.api_docs_enabled else None,
    lifespan=lifespan,
)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=settings.trusted_hosts_list,
)

# ── CORS ──
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=settings.cors_allow_credentials,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=[
        "Accept",
        "Authorization",
        "Content-Type",
        "Idempotency-Key",
        "X-Request-ID",
        "X-Research-Export-Token",
    ],
)


@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    """İstemci request-id'sini korur veya yeni UUID üretir."""
    supplied_request_id = request.headers.get("X-Request-ID", "")
    request_id = (
        supplied_request_id
        if REQUEST_ID_PATTERN.fullmatch(supplied_request_id)
        else str(uuid.uuid4())
    )
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    response.headers["Cross-Origin-Resource-Policy"] = "same-site"
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
    if settings.app_environment.lower() == "prod":
        response.headers["Strict-Transport-Security"] = (
            f"max-age={settings.security_hsts_max_age_seconds}; includeSubDomains"
        )
        response.headers["Content-Security-Policy"] = (
            "default-src 'none'; frame-ancestors 'none'; base-uri 'none'"
        )
    return response


# ═══════════════════════════════════════════════════════════════════════════════
# GLOBAL HATA YÖNETİCİLERİ
# ═══════════════════════════════════════════════════════════════════════════════

def _error_body(request: Request, code: str, message: str, details=None):
    return {
        "error": {
            "code": code,
            "message": message,
            "request_id": getattr(request.state, "request_id", None),
            "details": details,
        }
    }


@app.exception_handler(HTTPException)
async def http_error_handler(request: Request, exc: HTTPException):
    code_by_status = {
        400: "BAD_REQUEST",
        401: "UNAUTHORIZED",
        403: "FORBIDDEN",
        404: "NOT_FOUND",
        409: "CONFLICT",
        413: "IMAGE_TOO_LARGE",
        415: "UNSUPPORTED_IMAGE_TYPE",
        422: "VALIDATION_ERROR",
        503: "PROVIDER_UNAVAILABLE",
    }
    message = exc.detail if isinstance(exc.detail, str) else "İstek tamamlanamadı."
    return JSONResponse(
        status_code=exc.status_code,
        headers=exc.headers,
        content=_error_body(
            request,
            code_by_status.get(exc.status_code, "HTTP_ERROR"),
            message,
            None if isinstance(exc.detail, str) else exc.detail,
        ),
    )


@app.exception_handler(RequestValidationError)
async def validation_handler(request: Request, exc: RequestValidationError):
    # Pydantic hata bağlamı ValueError nesnesi ve parola gibi ham girdiler
    # içerebilir. İstemciye yalnızca güvenli, serileştirilebilir alanları dön.
    safe_errors = [
        {
            "type": error.get("type"),
            "loc": error.get("loc"),
            "msg": error.get("msg"),
        }
        for error in exc.errors()
    ]
    return JSONResponse(
        status_code=422,
        content=_error_body(
            request,
            "VALIDATION_ERROR",
            "Gönderilen veriler geçersiz. Lütfen bilgileri kontrol edin.",
            safe_errors,
        ),
    )


@app.exception_handler(500)
async def server_error_handler(request: Request, exc):
    logger.error(
        "Beklenmeyen sunucu hatası request_id=%s exception_type=%s",
        getattr(request.state, "request_id", None),
        type(exc).__name__,
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=_error_body(
            request,
            "INTERNAL_ERROR",
            "Sunucuda beklenmeyen bir hata oluştu. Lütfen daha sonra tekrar deneyin.",
        ),
    )


# ═══════════════════════════════════════════════════════════════════════════════
# ROUTER'LAR
# ═══════════════════════════════════════════════════════════════════════════════

app.include_router(food_router)
app.include_router(survey_router)


def database_readiness() -> dict:
    """Check DB connectivity and whether Alembic is exactly at head."""
    result = {"database": False, "migration": False, "ready": False}
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
            result["database"] = True
            if settings.migration_check_enabled:
                current = MigrationContext.configure(connection).get_current_revision()
                config = Config(str(BACKEND_DIR / "alembic.ini"))
                config.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
                heads = set(ScriptDirectory.from_config(config).get_heads())
                result["migration"] = current is not None and current in heads
            else:
                result["migration"] = True
    except Exception as exc:
        logger.error("Readiness kontrolü başarısız exception_type=%s", type(exc).__name__)
    result["ready"] = result["database"] and result["migration"]
    return result


@app.get("/health/live", tags=["System"])
async def liveness_check():
    return {"status": "alive", "app": settings.app_name, "version": settings.app_version}


@app.get("/health/ready", tags=["System"])
async def readiness_check():
    readiness = database_readiness()
    return JSONResponse(
        status_code=200 if readiness["ready"] else 503,
        content={"status": "ready" if readiness["ready"] else "not_ready", **readiness},
    )


@app.get("/health", tags=["System"])
async def health_check():
    return await readiness_check()


@app.get("/", tags=["System"])
async def root():
    """Kök endpoint — API bilgisi."""
    return {
        "app": settings.app_name,
        "version": settings.app_version,
        "docs": "/docs",
        "health": "/health",
    }
