import os

os.environ["DATABASE_URL"] = "sqlite+pysqlite:///:memory:"
os.environ["JWT_SECRET_KEY"] = "contract-test-key-not-for-production"
os.environ["DEBUG"] = "false"

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.database import Base, engine
from app.routers.food_router import _login_failures


@pytest.fixture(autouse=True)
def reset_database():
    _login_failures.clear()
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    _login_failures.clear()


@pytest.fixture()
def client():
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
