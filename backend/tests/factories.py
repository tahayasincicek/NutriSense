"""Deterministic synthetic factories shared by backend tests.

Values use reserved ``.invalid`` domains and RFC example-like identifiers.
They must never be copied into production seed data.
"""

from datetime import datetime, timezone
from uuid import UUID

FIXED_NOW = datetime(2026, 7, 26, 9, 30, tzinfo=timezone.utc)
USER_ID = UUID("9e4e5356-b491-4575-a9dd-c5abbc777fe9")


def user_payload(**overrides: object) -> dict[str, object]:
    payload: dict[str, object] = {
        "email": "fixture.user@nutrisense.invalid",
        "password": "Synthetic-Only-123!",
        "full_name": "Sentetik Kullanıcı",
    }
    payload.update(overrides)
    return payload


def consent_payload(**overrides: object) -> dict[str, object]:
    payload: dict[str, object] = {
        "protocol_version": "synthetic-protocol-v1",
        "participant_pseudonym": "SYNTH-P0001",
        "consented_at": FIXED_NOW.isoformat(),
        "synthetic": True,
    }
    payload.update(overrides)
    return payload
