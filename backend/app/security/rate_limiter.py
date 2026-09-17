"""Database-backed rate limiting shared by every API process."""

from __future__ import annotations

import hashlib
import hmac
from datetime import timedelta

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..config import get_settings
from ..models.database import RateLimitBucket, utc_now


class RateLimitExceeded(Exception):
    """Raised when a request would exceed its fixed-window budget."""


def _key_hash(action: str, identity: str) -> str:
    secret = get_settings().secret_key.encode("utf-8")
    value = f"{action}:{identity}".encode("utf-8")
    return hmac.new(secret, value, hashlib.sha256).hexdigest()


def enforce_rate_limit(
    db: Session,
    *,
    action: str,
    identity: str,
    limit: int,
    window_seconds: int,
) -> None:
    """Consume one request from a shared fixed-window counter.

    The row is locked while it is checked and incremented. A concurrent first
    insert can race on the primary key; in that case the transaction is rolled
    back and retried against the winning row.
    """

    if limit < 1 or window_seconds < 1:
        raise ValueError("Rate limit and window must be positive.")

    digest = _key_hash(action, identity)
    for attempt in range(2):
        now = utc_now()
        cutoff = now - timedelta(seconds=window_seconds)
        bucket = (
            db.query(RateLimitBucket)
            .filter(RateLimitBucket.key_hash == digest)
            .with_for_update()
            .first()
        )
        if bucket is None:
            db.add(RateLimitBucket(
                key_hash=digest,
                action=action,
                window_started_at=now,
                request_count=1,
            ))
        elif bucket.window_started_at <= cutoff:
            bucket.window_started_at = now
            bucket.request_count = 1
            bucket.updated_at = now
        elif bucket.request_count >= limit:
            db.rollback()
            raise RateLimitExceeded
        else:
            bucket.request_count += 1
            bucket.updated_at = now
        try:
            # Keep the counter in the caller's transaction.  Committing here
            # would split otherwise atomic operations (for example food
            # analysis + nutrition source + diary entry) into two commits.
            db.flush()
            return
        except IntegrityError:
            db.rollback()
            if attempt:
                raise


def reset_rate_limit(db: Session, *, action: str, identity: str) -> None:
    """Clear a bucket after a successful authentication event."""

    db.query(RateLimitBucket).filter(
        RateLimitBucket.key_hash == _key_hash(action, identity)
    ).delete(synchronize_session=False)
    db.flush()
