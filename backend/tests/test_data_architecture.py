import asyncio
import io
import os
import sqlite3
import subprocess
import sys
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path
from types import SimpleNamespace

import pytest
from PIL import Image
from sqlalchemy import create_engine, event
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from app.config import Settings
from app.main import app
from app.middleware.auth import get_current_user, hash_password
from app.models.database import (
    AuditEvent,
    Base,
    Dietitian,
    DietitianAssignment,
    DietitianReport,
    FoodLog,
    NotificationDelivery,
    NutritionSource,
    RecognitionAttempt,
    SessionLocal,
    SurveySubmission,
    SurveyVersion,
    User,
    get_db,
)
from app.routers import food_router, survey_router
from app.routers.survey_router import (
    SurveyAnswerSchema,
    SurveySubmissionSchema,
    submit_survey,
)

BACKEND_DIR = Path(__file__).parents[1]
PASSWORD = "Guvenli123"


def _jpeg_bytes() -> bytes:
    output = io.BytesIO()
    Image.new("RGB", (8, 8), color=(20, 180, 20)).save(output, "JPEG")
    return output.getvalue()


def _register(client, email: str) -> dict:
    response = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": PASSWORD, "full_name": "Synthetic Test User"},
    )
    assert response.status_code == 201
    return response.json()


def _auth(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def _migration_environment(database_url: str) -> dict[str, str]:
    environment = os.environ.copy()
    environment.update(
        {
            "APP_ENVIRONMENT": "test",
            "DATABASE_URL": database_url,
            "JWT_SECRET_KEY": "migration-test-only",
            "DEBUG": "false",
            "MIGRATION_CHECK_ENABLED": "true",
        }
    )
    return environment


def _alembic(database_url: str, *arguments: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, "-m", "alembic", "-c", "alembic.ini", *arguments],
        cwd=BACKEND_DIR,
        env=_migration_environment(database_url),
        check=True,
        capture_output=True,
        text=True,
        timeout=60,
    )


def test_alembic_empty_database_upgrade_downgrade_and_boot(tmp_path):
    database_path = tmp_path / "migration_roundtrip.db"
    database_url = f"sqlite+pysqlite:///{database_path.as_posix()}"

    _alembic(database_url, "upgrade", "head")
    with sqlite3.connect(database_path) as connection:
        tables = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        assert {"users", "food_logs", "survey_submissions", "audit_events"} <= tables
        assert connection.execute("SELECT COUNT(*) FROM survey_versions").fetchone()[0] == 1

    ready = subprocess.run(
        [sys.executable, "-c", "from app.main import database_readiness; assert database_readiness()['ready']"],
        cwd=BACKEND_DIR,
        env=_migration_environment(database_url),
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert ready.returncode == 0

    _alembic(database_url, "downgrade", "base")
    with sqlite3.connect(database_path) as connection:
        tables = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        assert "users" not in tables

    _alembic(database_url, "upgrade", "head")
    with sqlite3.connect(database_path) as connection:
        assert connection.execute("SELECT version_num FROM alembic_version").fetchone()[0]


def test_environment_safety_rejects_production_debug_and_unsafe_test_database():
    production = Settings(
        _env_file=None,
        app_environment="prod",
        debug=True,
        database_url="mysql+pymysql://app:fake-password@db/product",
        jwt_secret_key="fake-but-non-placeholder-jwt",
        secret_key="fake-but-non-placeholder-app-secret",
    )
    with pytest.raises(RuntimeError, match="DEBUG"):
        production.validate_security()

    placeholder = Settings(
        _env_file=None,
        app_environment="prod",
        debug=False,
        database_url="mysql+pymysql://app:fake-password@db/product",
        jwt_secret_key="REPLACE_WITH_LONG_RANDOM_JWT_SECRET",
        secret_key="a" * 40,
        research_export_token="b" * 40,
    )
    with pytest.raises(RuntimeError, match="JWT"):
        placeholder.validate_security()

    unsafe_test = Settings(
        _env_file=None,
        app_environment="test",
        database_url="mysql+pymysql://app:fake-password@db/product",
    )
    with pytest.raises(RuntimeError, match="_test"):
        unsafe_test.validate_security()


def test_foreign_key_rejects_orphan_food_log_and_user_delete_cascades():
    db = SessionLocal()
    try:
        db.add(
            FoodLog(
                user_id=str(uuid.uuid4()),
                food_name="orphan",
                food_name_tr="Orphan",
                calories_per_100g=1,
                estimated_portion_g=1,
                total_calories=1,
            )
        )
        with pytest.raises(IntegrityError):
            db.commit()
        db.rollback()

        user = User(
            email="cascade@example.com",
            hashed_password=hash_password(PASSWORD),
            full_name="Cascade User",
        )
        db.add(user)
        db.commit()
        attempt = RecognitionAttempt(user_id=user.id, provider="test", status="succeeded")
        source = NutritionSource(provider="test", food_name="apple", calories_per_100g=52)
        db.add_all([attempt, source])
        db.flush()
        db.add(
            FoodLog(
                user_id=user.id,
                recognition_attempt_id=attempt.id,
                nutrition_source_id=source.id,
                food_name="apple",
                food_name_tr="Elma",
                calories_per_100g=52,
                estimated_portion_g=100,
                total_calories=52,
            )
        )
        db.commit()
        user_id = user.id
        db.delete(user)
        db.commit()
        assert db.query(FoodLog).filter(FoodLog.user_id == user_id).count() == 0
        assert db.query(RecognitionAttempt).filter(RecognitionAttempt.user_id == user_id).count() == 0
        assert db.query(NutritionSource).filter(NutritionSource.id == source.id).count() == 1
    finally:
        db.close()


def test_food_analysis_commit_failure_rolls_back_all_three_records(client, monkeypatch):
    class SuccessfulVision:
        async def analyze_image(self, _image):
            return {"food_name": "elma", "confidence": 0.95}

    class SuccessfulNutrition:
        async def get_nutrition(self, _name):
            return {
                "calories_per_100g": 52.0,
                "estimated_portion_g": 100.0,
                "total_calories": 52.0,
                "nutrients": {"protein": 0.3, "carb": 14.0, "fat": 0.2, "fiber": 2.4},
                "source": "test-provider",
            }

    setup = SessionLocal()
    user = User(
        email="rollback@example.com",
        hashed_password=hash_password(PASSWORD),
        full_name="Rollback User",
    )
    setup.add(user)
    setup.commit()
    user_id = user.id
    setup.close()

    failing_session = SessionLocal()

    def override_db():
        yield failing_session

    def fail_commit():
        raise RuntimeError("synthetic commit failure")

    monkeypatch.setattr(food_router, "vision_service", SuccessfulVision())
    monkeypatch.setattr(food_router, "nutrition_service", SuccessfulNutrition())
    monkeypatch.setattr(failing_session, "commit", fail_commit)
    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=user_id)

    response = client.post(
        "/api/v1/analyze-food",
        files={"image": ("food.jpg", _jpeg_bytes(), "image/jpeg")},
    )
    assert response.status_code == 503
    failing_session.close()

    verify = SessionLocal()
    try:
        assert verify.query(RecognitionAttempt).filter(RecognitionAttempt.user_id == user_id).count() == 0
        assert verify.query(NutritionSource).filter(NutritionSource.provider == "test-provider").count() == 0
        assert verify.query(FoodLog).filter(FoodLog.user_id == user_id).count() == 0
    finally:
        verify.close()


def test_report_idempotency_prevents_duplicate_provider_delivery(client, monkeypatch):
    tokens = _register(client, "idempotency@example.com")
    db = SessionLocal()
    dietitian = Dietitian(
        email="sandbox-dietitian@example.com",
        full_name="Sandbox Dietitian",
        email_verified=True,
        is_active=True,
    )
    db.add(dietitian)
    db.flush()
    assignment = DietitianAssignment(
        user_id=tokens["user_id"], dietitian_id=dietitian.id, status="approved"
    )
    user = db.query(User).filter(User.id == tokens["user_id"]).one()
    user.dietitian_id = dietitian.id
    db.add(assignment)
    db.commit()
    db.close()

    class CountingSandboxNotification:
        calls = 0

        async def send_dietitian_report(self, **_kwargs):
            self.calls += 1
            return {"email_sent": True, "sms_sent": False}

    sandbox = CountingSandboxNotification()
    monkeypatch.setattr(food_router, "notification_service", sandbox)
    payload = {
        "user_id": tokens["user_id"],
        "report_type": "daily",
        "from_date": date.today().isoformat(),
        "to_date": date.today().isoformat(),
        "consent": True,
    }
    headers = {**_auth(tokens), "Idempotency-Key": "synthetic-idempotency-key-001"}
    first = client.post("/api/v1/send-to-dietitian", headers=headers, json=payload)
    second = client.post("/api/v1/send-to-dietitian", headers=headers, json=payload)
    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["report_id"] == second.json()["report_id"]
    assert sandbox.calls == 1

    db = SessionLocal()
    try:
        assert db.query(DietitianReport).count() == 1
        assert db.query(NotificationDelivery).count() == 1
    finally:
        db.close()


def test_concurrent_survey_writes_are_database_transactions(tmp_path):
    database_path = tmp_path / "survey_concurrency.db"
    concurrent_engine = create_engine(
        f"sqlite+pysqlite:///{database_path.as_posix()}",
        connect_args={"check_same_thread": False, "timeout": 30},
    )

    @event.listens_for(concurrent_engine, "connect")
    def enable_foreign_keys(connection, _record):
        connection.execute("PRAGMA foreign_keys=ON")

    concurrent_sessions = sessionmaker(bind=concurrent_engine, expire_on_commit=False)
    Base.metadata.create_all(concurrent_engine)
    seed = concurrent_sessions()
    seed.add(SurveyVersion(version="1.0", schema_json={"seed": "concurrency-test"}))
    seed.commit()
    seed.close()

    def write_one(index: int):
        db = concurrent_sessions()
        try:
            submission = SurveySubmissionSchema(
                participant_id=uuid.uuid4(),
                answers=[SurveyAnswerSchema(question_id="q2", answer=(index % 5) + 1)],
            )
            return asyncio.run(submit_survey(submission, db))
        finally:
            db.close()

    with ThreadPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(write_one, range(20)))
    assert all(result.success for result in results)
    verify = concurrent_sessions()
    assert verify.query(SurveySubmission).count() == 20
    verify.close()
    concurrent_engine.dispose()
    assert not hasattr(survey_router, "SURVEY_FILE")


def test_research_export_requires_token_and_is_audited(client, monkeypatch):
    export_token = "synthetic-research-export-token"
    monkeypatch.setattr(survey_router.settings, "research_export_token", export_token)
    submission = client.post(
        "/api/v1/survey",
        json={
            "participant_id": str(uuid.uuid4()),
            "answers": [{"question_id": "q2", "answer": 4}],
        },
    )
    assert submission.status_code == 200
    assert client.get("/api/v1/survey/stats").status_code == 403
    exported = client.get(
        "/api/v1/survey/stats",
        headers={"X-Research-Export-Token": export_token},
    )
    assert exported.status_code == 200
    db = SessionLocal()
    try:
        assert db.query(AuditEvent).filter(AuditEvent.event == "survey_stats_exported").count() == 1
    finally:
        db.close()
