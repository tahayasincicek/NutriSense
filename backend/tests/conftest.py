import os

os.environ.setdefault("DATABASE_URL", "sqlite+pysqlite:///:memory:")
os.environ.setdefault("JWT_SECRET_KEY", "contract-test-key-not-for-production")
os.environ.setdefault("DEBUG", "false")
os.environ.setdefault("APP_ENVIRONMENT", "test")
os.environ.setdefault("MIGRATION_CHECK_ENABLED", "false")

import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.config import get_settings
from app.models.database import Base, SessionLocal, SurveyVersion, engine
from app.routers.food_router import _analysis_requests, _login_failures


@pytest.fixture(autouse=True)
def reset_database():
    _login_failures.clear()
    _analysis_requests.clear()
    settings = get_settings()
    settings.validate_security()
    assert settings.database_url == os.environ["DATABASE_URL"]
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    db.add(SurveyVersion(version="1.0", schema_json={"seed": "test-only"}))
    db.commit()
    db.close()
    yield
    _login_failures.clear()
    _analysis_requests.clear()


@pytest.fixture()
def client():
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
