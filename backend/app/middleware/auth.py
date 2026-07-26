# ==============================================================================
# backend/app/middleware/auth.py
# NutriSense — JWT Kimlik Doğrulama
#
# - Access token (kısa ömürlü) + Refresh token (uzun ömürlü)
# - Bcrypt şifre hashleme
# - FastAPI Depends() ile endpoint koruması
# ==============================================================================

import hashlib
import hmac
import uuid
from datetime import datetime, timedelta, timezone
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from jwt import InvalidTokenError
from pwdlib import PasswordHash
from pwdlib.hashers.argon2 import Argon2Hasher
from pwdlib.hashers.bcrypt import BcryptHasher
from sqlalchemy.orm import Session

from ..config import get_settings
from ..models.database import RefreshToken, User, get_db

settings = get_settings()


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


# ── Şifre ──
password_hash = PasswordHash((Argon2Hasher(), BcryptHasher()))

# ── JWT Bearer ──
security = HTTPBearer()


def hash_password(password: str) -> str:
    """Yeni parolaları bellek maliyetli Argon2id ile hashler."""
    return password_hash.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    """Argon2id ve geçiş sürecindeki eski bcrypt karmalarını doğrular."""
    return password_hash.verify(plain, hashed)


def create_access_token(user_id: str) -> str:
    """Kısa ömürlü access token oluşturur."""
    issued_at = _utcnow()
    expire = issued_at + timedelta(
        minutes=settings.jwt_access_token_expire_minutes
    )
    payload = {
        "sub": user_id,
        "exp": expire,
        "iat": issued_at,
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
        "jti": str(uuid.uuid4()),
        "type": "access",
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def create_refresh_token(user_id: str, jti: str, expires_at: datetime) -> str:
    """Kimliği veritabanında izlenen refresh JWT oluşturur."""
    issued_at = _utcnow()
    payload = {
        "sub": user_id,
        "exp": expires_at,
        "iat": issued_at,
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
        "type": "refresh",
        "jti": jti,
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_token_pair(db: Session, user: User) -> dict:
    """Access + kayıtlı refresh token üretir."""
    jti = str(uuid.uuid4())
    expires_at = _utcnow() + timedelta(
        days=settings.jwt_refresh_token_expire_days
    )
    refresh_token = create_refresh_token(user.id, jti, expires_at)
    db.add(RefreshToken(
        jti=jti,
        user_id=user.id,
        token_hash=_token_hash(refresh_token),
        expires_at=expires_at,
    ))
    db.commit()
    return {
        "access_token": create_access_token(user.id),
        "refresh_token": refresh_token,
        "expires_in": settings.jwt_access_token_expire_minutes * 60,
        "refresh_expires_in": settings.jwt_refresh_token_expire_days * 86400,
        "user_id": user.id,
        "full_name": user.full_name,
    }


def rotate_refresh_token(db: Session, token: str) -> tuple[User, dict]:
    """Refresh token'ı tek kullanımlık olarak revoke edip yenisini üretir."""
    payload = decode_token(token)
    if payload.get("type") != "refresh" or not payload.get("jti"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Geçersiz refresh token türü.",
        )

    record = db.query(RefreshToken).filter(
        RefreshToken.jti == payload["jti"]
    ).with_for_update().first()
    now = _utcnow()
    if (
        record is None
        or record.revoked_at is not None
        or record.expires_at <= now
        or not hmac.compare_digest(record.token_hash, _token_hash(token))
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token geçersiz, kullanılmış veya iptal edilmiş.",
        )

    user = db.query(User).filter(User.id == record.user_id).first()
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Aktif kullanıcı oturumu bulunamadı.",
        )

    replacement_jti = str(uuid.uuid4())
    replacement_expiry = now + timedelta(
        days=settings.jwt_refresh_token_expire_days
    )
    replacement = create_refresh_token(
        user.id, replacement_jti, replacement_expiry
    )
    record.revoked_at = now
    record.replaced_by_jti = replacement_jti
    db.add(RefreshToken(
        jti=replacement_jti,
        user_id=user.id,
        token_hash=_token_hash(replacement),
        expires_at=replacement_expiry,
    ))
    db.commit()
    return user, {
        "access_token": create_access_token(user.id),
        "refresh_token": replacement,
        "expires_in": settings.jwt_access_token_expire_minutes * 60,
        "refresh_expires_in": settings.jwt_refresh_token_expire_days * 86400,
        "user_id": user.id,
        "full_name": user.full_name,
    }


def revoke_refresh_token(db: Session, token: str) -> None:
    """Logout sırasında geçerli refresh token'ı iptal eder."""
    payload = decode_token(token)
    if payload.get("type") != "refresh" or not payload.get("jti"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Geçersiz refresh token türü.",
        )
    record = db.query(RefreshToken).filter(
        RefreshToken.jti == payload["jti"]
    ).first()
    if record and record.revoked_at is None:
        record.revoked_at = _utcnow()
        db.commit()


def decode_token(token: str) -> dict:
    """JWT token'ı decode eder ve doğrular."""
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
            audience=settings.jwt_audience,
            issuer=settings.jwt_issuer,
            options={
                "require": ["exp", "iat", "sub", "iss", "aud", "jti"],
            },
        )
        if not payload.get("jti"):
            raise InvalidTokenError("jti claim missing")
        return payload
    except InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Geçersiz veya süresi dolmuş token. Lütfen tekrar giriş yapın.",
        )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    """
    FastAPI dependency — JWT token'dan aktif kullanıcıyı döner.

    Kullanım:
        @router.get("/protected")
        async def protected_endpoint(user: User = Depends(get_current_user)):
            ...
    """
    payload = decode_token(credentials.credentials)

    user_id = payload.get("sub")
    token_type = payload.get("type")

    if not user_id or token_type != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Geçersiz token türü. Access token gerekli.",
        )

    user = db.query(User).filter(User.id == user_id).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kullanıcı bulunamadı.",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Hesabınız devre dışı bırakılmış.",
        )

    return user
