"""Meal reuse and optimistic, user-scoped undo for food diary mutations."""
from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal
import hashlib
import json
import uuid

from fastapi import HTTPException
from ..models.database import AuthAuditLog, FoodLog, istanbul_date, utc_now

EVENT = "food_diary_action"


def snapshot(log):
    values = {}
    for column in FoodLog.__table__.columns:
        value = getattr(log, column.name)
        if isinstance(value, (datetime, date)):
            value = value.isoformat()
        elif isinstance(value, Decimal):
            value = str(value)
        values[column.name] = value
    return values


def digest(values):
    return hashlib.sha256(json.dumps(values, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def record_action(db, user_id, logs, before, label, action_id=None):
    previous_action = latest_action(db, user_id)
    sequence = (previous_action.metadata_json.get("sequence", 0) if previous_action else 0) + 1
    db.flush()
    for log in logs:
        db.refresh(log)
    event = AuthAuditLog(
        id=action_id or str(uuid.uuid4()), user_id=str(user_id), event=EVENT,
        success=True, reason=label,
        metadata_json={"before": before, "after": [snapshot(log) for log in logs],
                       "label": label, "undone": False, "sequence": sequence},
    )
    db.add(event)
    return event


def latest_action(db, user_id):
    return db.query(AuthAuditLog).filter(
        AuthAuditLog.user_id == str(user_id), AuthAuditLog.event == EVENT,
    ).order_by(AuthAuditLog.metadata_json["sequence"].as_integer().desc(),
               AuthAuditLog.created_at.desc(), AuthAuditLog.id.desc()).first()


def undo_preview(db, user_id):
    event = latest_action(db, user_id)
    if event is None or event.metadata_json.get("undone"):
        return None
    data = event.metadata_json
    names = ", ".join(row["food_name_tr"] for row in data["after"])
    return {"action_id": event.id, "label": data["label"], "summary": names,
            "context_hash": digest(data["after"])}


def undo_action(db, user_id, action_id, context_hash):
    event = db.query(AuthAuditLog).filter(
        AuthAuditLog.id == action_id, AuthAuditLog.user_id == str(user_id),
        AuthAuditLog.event == EVENT,
    ).with_for_update().first()
    if event is None:
        raise HTTPException(404, "Geri alınacak işlem bulunamadı.")
    data = event.metadata_json
    if digest(data["after"]) != context_hash:
        raise HTTPException(409, "İşlem değişti; yeniden önizleyin.")
    if data.get("undone"):
        return
    if latest_action(db, user_id).id != event.id:
        raise HTTPException(409, "Daha yeni bir besin işlemi var. Yeniden önizleyin.")
    logs = []
    for expected in data["after"]:
        log = db.query(FoodLog).filter(
            FoodLog.id == expected["id"], FoodLog.user_id == user_id,
        ).with_for_update().one_or_none()
        if log is None or snapshot(log) != expected:
            raise HTTPException(409, "Besin kaydı değişmiş; eski işlem geri alınamaz.")
        logs.append(log)
    for log, previous in zip(logs, data["before"]):
        if previous is None:
            log.deleted_at = utc_now()
        else:
            for key, value in previous.items():
                if key in {"logged_at", "updated_at", "deleted_at"} and value is not None:
                    value = datetime.fromisoformat(value)
                elif key == "log_date":
                    value = date.fromisoformat(value)
                setattr(log, key, value)
        log.updated_at = utc_now()
    event.metadata_json = {**data, "undone": True, "undone_at": utc_now().isoformat()}


def frequent_meals(db, user_id):
    logs = db.query(FoodLog).filter(
        FoodLog.user_id == user_id, FoodLog.deleted_at.is_(None),
        FoodLog.is_user_confirmed.is_(True),
        FoodLog.log_date >= istanbul_date() - timedelta(days=90),
    ).order_by(FoodLog.logged_at.desc()).limit(1000).all()
    groups = defaultdict(list)
    for log in logs:
        groups[(log.log_date, log.meal_type)].append(log)
    candidates = {}
    for (_, meal_type), entries in groups.items():
        if len(entries) > 30:
            continue
        entries.sort(key=lambda log: (log.food_name, str(log.id)))
        signature = tuple(sorted((log.food_name, str(log.estimated_portion_g)) for log in entries))
        key = (meal_type, signature)
        if key in candidates:
            candidates[key]["frequency"] += 1
            continue
        candidates[key] = {
            "meal_type": meal_type, "frequency": 1,
            "log_ids": [log.id for log in entries],
            "context_hash": digest([snapshot(log) for log in entries]),
            "items": [{"name": log.food_name_tr, "grams": float(log.estimated_portion_g),
                       "calories": float(log.total_calories), "estimated": log.portion_is_estimate}
                      for log in entries],
        }
    return sorted(candidates.values(), key=lambda item: -item["frequency"])[:8]


def repeat_sources(db, user_id, ids, context_hash):
    logs = []
    for log_id in ids:
        log = db.query(FoodLog).filter(
            FoodLog.id == log_id, FoodLog.user_id == user_id,
            FoodLog.deleted_at.is_(None), FoodLog.is_user_confirmed.is_(True),
        ).with_for_update().first()
        if log is None:
            raise HTTPException(404, "Öğün kaydı bulunamadı.")
        logs.append(log)
    if digest([snapshot(log) for log in logs]) != context_hash:
        raise HTTPException(409, "Öğünün içeriği değişti. Yeniden önizleyin.")
    return logs


def clone_food(log):
    excluded = {"id", "recognition_attempt_id", "logged_at", "updated_at", "deleted_at", "log_date"}
    values = {c.name: getattr(log, c.name) for c in FoodLog.__table__.columns if c.name not in excluded}
    values["recognition_source"] = "manual"
    values["confidence"] = 0.0
    return FoodLog(id=str(uuid.uuid4()), **values, log_date=istanbul_date())
