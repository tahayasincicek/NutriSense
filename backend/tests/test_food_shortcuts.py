from datetime import datetime, timezone
import uuid

from app.models.database import SessionLocal, FoodLog, AuthAuditLog
from app.domain.food_shortcuts import EVENT
from tests.test_dietitian_report_delivery import _register, _auth


def create(client, headers, name="omlet", grams=125):
    response = client.post("/api/v1/food-log/manual", headers=headers, json={
        "capture_id": str(uuid.uuid4()), "food_name": name, "confirmed": True,
        "meal_type": "kahvalti", "portion_value": grams, "portion_unit": "gram",
    })
    assert response.status_code == 200, response.text
    return response.json()["log_id"]


def shortcuts(client, headers):
    result = client.get("/api/v1/food-shortcuts", headers=headers)
    assert result.status_code == 200, result.text
    return result.json()


def undo_request(preview):
    return {"action_id": preview["action_id"], "context_hash": preview["context_hash"], "confirmed": True}


def test_repeat_whole_meal_once_and_undo_only_new_copies(client):
    headers = _auth(_register(client, "shortcut@example.com"))
    originals = [create(client, headers), create(client, headers, "pizza", 80)]
    meal = shortcuts(client, headers)["meals"][0]
    assert len(meal["items"]) == 2
    body = {"request_id": str(uuid.uuid4()), "log_ids": meal["log_ids"],
            "context_hash": meal["context_hash"], "confirmed": True}
    for _ in range(2):
        result = client.post("/api/v1/food-shortcuts/repeat", headers=headers, json=body)
        assert result.status_code == 200, result.text
    with SessionLocal() as db:
        assert db.query(FoodLog).count() == 4
        copied = db.query(FoodLog).filter(~FoodLog.id.in_(originals)).all()
        for log in copied:
            original = db.query(FoodLog).filter(FoodLog.id.in_(originals), FoodLog.food_name == log.food_name).one()
            assert log.total_calories == original.total_calories
            assert log.estimated_portion_g == original.estimated_portion_g
            assert log.nutrition_source_id == original.nutrition_source_id
    undo = undo_request(shortcuts(client, headers)["undo"])
    for _ in range(2):
        response = client.post("/api/v1/food-shortcuts/undo", headers=headers, json=undo)
        assert response.status_code == 200, response.text
    with SessionLocal() as db:
        assert {log.id for log in db.query(FoodLog).filter(FoodLog.deleted_at.is_(None))} == set(originals)
    assert shortcuts(client, headers)["undo"] is None


def test_undo_edit_restores_portion_calories_and_name(client):
    headers = _auth(_register(client, "edit-shortcut@example.com"))
    log_id = create(client, headers)
    with SessionLocal() as db:
        original = db.get(FoodLog, log_id)
        calories = original.total_calories
        name = original.food_name_tr
    result = client.patch(f"/api/v1/food-logs/{log_id}", headers=headers,
                          json={"portion_g": 250, "food_name_tr": "Düzeltilmiş omlet"})
    assert result.status_code == 200, result.text
    undo = undo_request(shortcuts(client, headers)["undo"])
    result = client.post("/api/v1/food-shortcuts/undo", headers=headers, json=undo)
    assert result.status_code == 200, result.text
    with SessionLocal() as db:
        log = db.get(FoodLog, log_id)
        assert log.food_name_tr == name
        assert log.total_calories == calories
        assert float(log.estimated_portion_g) == 125


def test_undo_delete_and_stale_confirmation_are_safe(client):
    headers = _auth(_register(client, "delete-shortcut@example.com"))
    log_id = create(client, headers)
    stale = undo_request(shortcuts(client, headers)["undo"])
    assert client.delete(f"/api/v1/food-logs/{log_id}", headers=headers).status_code == 200
    assert client.post("/api/v1/food-shortcuts/undo", headers=headers, json=stale).status_code == 409
    undo = undo_request(shortcuts(client, headers)["undo"])
    assert client.post("/api/v1/food-shortcuts/undo", headers=headers, json=undo).status_code == 200
    with SessionLocal() as db:
        assert db.get(FoodLog, log_id).deleted_at is None


def test_ownership_changed_source_and_required_confirmation(client):
    headers = _auth(_register(client, "owner-shortcut@example.com"))
    other = _auth(_register(client, "other-shortcut@example.com"))
    log_id = create(client, headers)
    data = shortcuts(client, headers)
    meal = data["meals"][0]
    body = {"request_id": str(uuid.uuid4()), "log_ids": meal["log_ids"],
            "context_hash": meal["context_hash"], "confirmed": True}
    assert shortcuts(client, other) == {"meals": [], "undo": None}
    assert client.post("/api/v1/food-shortcuts/repeat", headers=other, json=body).status_code == 404
    assert client.post("/api/v1/food-shortcuts/undo", headers=other, json=undo_request(data["undo"])).status_code == 404
    assert client.post("/api/v1/food-shortcuts/repeat", headers=headers, json={**body, "confirmed": False}).status_code == 422
    assert client.patch(f"/api/v1/food-logs/{log_id}", headers=headers, json={"portion_g": 150}).status_code == 200
    assert client.post("/api/v1/food-shortcuts/repeat", headers=headers, json=body).status_code == 409


def test_action_sequence_is_deterministic_when_mysql_timestamps_tie(client):
    headers = _auth(_register(client, "sequence-shortcut@example.com"))
    create(client, headers)
    last_id = create(client, headers)
    with SessionLocal() as db:
        db.query(AuthAuditLog).filter(AuthAuditLog.event == EVENT).update({
            "created_at": datetime(2026, 9, 7, tzinfo=timezone.utc),
        })
        db.commit()
    undo = undo_request(shortcuts(client, headers)["undo"])
    assert client.post("/api/v1/food-shortcuts/undo", headers=headers, json=undo).status_code == 200
    with SessionLocal() as db:
        assert db.get(FoodLog, last_id).deleted_at is not None
        assert db.query(FoodLog).filter(FoodLog.deleted_at.is_(None)).count() == 1
