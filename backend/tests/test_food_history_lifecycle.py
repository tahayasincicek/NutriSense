from datetime import date, datetime, timezone
from decimal import Decimal
from types import SimpleNamespace

import pytest

from app.main import app
from app.middleware.auth import get_current_user
from app.models.database import (
    AuditEvent,
    FoodLog,
    SessionLocal,
    User,
    istanbul_date,
)


USER_ID = "11111111-1111-4111-8111-111111111111"
OTHER_USER_ID = "22222222-2222-4222-8222-222222222222"


def _seed_user(db, user_id: str, email: str) -> None:
    db.add(User(
        id=user_id,
        email=email,
        hashed_password="test-only",
        full_name="History Fixture User",
        daily_calorie_target=1800,
    ))


def _seed_log(
    db,
    *,
    log_id: str,
    user_id: str = USER_ID,
    log_date: date = date(2026, 7, 18),
    calories: str = "78",
    confirmed: bool = True,
    deleted_at=None,
) -> None:
    db.add(FoodLog(
        id=log_id,
        user_id=user_id,
        food_name="apple",
        food_name_tr="Elma",
        canonical_food_id="food.apple",
        calories_per_100g=Decimal("52"),
        estimated_portion_g=Decimal("150"),
        portion_value=Decimal("150"),
        portion_unit="gram",
        portion_method="user_selected",
        portion_is_estimate=False,
        total_calories=Decimal(calories),
        protein=Decimal("0.4"),
        carbs=Decimal("20.7"),
        fat=Decimal("0.3"),
        fiber=Decimal("3.6"),
        macro_calories=Decimal("86.7"),
        macro_calorie_delta=Decimal("8.7"),
        nutrition_reliability="verified_provider",
        confidence=0.93,
        meal_type="atistirmalik",
        recognition_source="google_vision",
        is_user_confirmed=confirmed,
        logged_at=datetime(2026, 7, 18, 10, 30, tzinfo=timezone.utc),
        log_date=log_date,
        deleted_at=deleted_at,
    ))


def _as_user(user_id: str = USER_ID):
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(
        id=user_id,
        daily_calorie_target=1800,
    )


def test_history_uses_confirmed_active_records_and_paginates_by_local_day(client):
    db = SessionLocal()
    _seed_user(db, USER_ID, "history-owner@example.com")
    _seed_log(db, log_id="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")
    _seed_log(
        db,
        log_id="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2",
        log_date=date(2026, 7, 17),
        calories="52",
    )
    _seed_log(
        db,
        log_id="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3",
        confirmed=False,
    )
    _seed_log(
        db,
        log_id="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4",
        deleted_at=datetime(2026, 7, 18, 11, tzinfo=timezone.utc),
    )
    db.commit()
    db.close()
    _as_user()

    first = client.get(
        f"/api/v1/food-history/{USER_ID}",
        params={
            "from_date": "2026-07-17",
            "to_date": "2026-07-18",
            "page": 1,
            "page_size": 1,
        },
    )
    assert first.status_code == 200
    payload = first.json()
    assert payload["total_log_count"] == 2
    assert payload["total_date_count"] == 2
    assert payload["total_calories"] == 130
    assert payload["daily_logs"][0]["date"] == "2026-07-18"
    assert payload["has_more"] is True
    assert payload["daily_logs"][0]["foods"][0]["canonical_food_id"] == "food.apple"

    second = client.get(
        f"/api/v1/food-history/{USER_ID}",
        params={
            "from_date": "2026-07-17",
            "to_date": "2026-07-18",
            "page": 2,
            "page_size": 1,
        },
    )
    assert second.json()["daily_logs"][0]["date"] == "2026-07-17"
    assert second.json()["has_more"] is False


def test_history_rejects_invalid_date_range_and_other_user(client):
    _as_user()
    invalid = client.get(
        f"/api/v1/food-history/{USER_ID}",
        params={"from_date": "2026-07-19", "to_date": "2026-07-18"},
    )
    assert invalid.status_code == 422

    forbidden = client.get(f"/api/v1/food-history/{OTHER_USER_ID}")
    assert forbidden.status_code == 403


def test_edit_delete_restore_are_owned_recalculated_and_audited(client):
    db = SessionLocal()
    _seed_user(db, USER_ID, "edit-owner@example.com")
    _seed_user(db, OTHER_USER_ID, "edit-other@example.com")
    log_id = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
    _seed_log(db, log_id=log_id)
    db.commit()
    db.close()

    _as_user(OTHER_USER_ID)
    hidden = client.patch(
        f"/api/v1/food-logs/{log_id}", json={"portion_g": 100},
    )
    assert hidden.status_code == 404

    _as_user(USER_ID)
    updated = client.patch(
        f"/api/v1/food-logs/{log_id}",
        json={
            "food_name_tr": "Yeşil elma",
            "portion_g": 100,
            "meal_type": "ogle",
        },
    )
    assert updated.status_code == 200
    body = updated.json()
    assert body["food_name_tr"] == "Yeşil elma"
    assert body["portion_g"] == 100
    assert body["calories"] == pytest.approx(52)
    assert body["portion_is_estimate"] is False
    assert body["is_corrected"] is True

    deleted = client.delete(f"/api/v1/food-logs/{log_id}")
    assert deleted.status_code == 200
    history = client.get(
        f"/api/v1/food-history/{USER_ID}",
        params={"from_date": "2026-07-18", "to_date": "2026-07-18"},
    )
    assert history.json()["total_log_count"] == 0

    restored = client.post(f"/api/v1/food-logs/{log_id}/restore")
    assert restored.status_code == 200
    history = client.get(
        f"/api/v1/food-history/{USER_ID}",
        params={"from_date": "2026-07-18", "to_date": "2026-07-18"},
    )
    assert history.json()["daily_logs"][0]["foods"][0]["food_name_tr"] == "Yeşil elma"

    db = SessionLocal()
    try:
        log = db.query(FoodLog).filter(FoodLog.id == log_id).one()
        assert log.original_food_name_tr == "Elma"
        assert log.original_food_name == "apple"
        events = {
            event.event for event in db.query(AuditEvent).filter(
                AuditEvent.user_id == USER_ID
            )
        }
        assert {
            "food_log_updated", "food_log_deleted", "food_log_restored",
        } <= events
    finally:
        db.close()


def test_istanbul_calendar_day_handles_utc_midnight_boundary():
    assert istanbul_date(
        datetime(2026, 7, 17, 20, 59, tzinfo=timezone.utc)
    ) == date(2026, 7, 17)
    assert istanbul_date(
        datetime(2026, 7, 17, 21, 0, tzinfo=timezone.utc)
    ) == date(2026, 7, 18)
