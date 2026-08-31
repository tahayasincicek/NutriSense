"""Fail unless the configured database is reachable and exactly at Alembic head."""

from pathlib import Path

from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.script import ScriptDirectory

from app.models.database import engine

BACKEND_DIR = Path(__file__).resolve().parents[1]


def main() -> None:
    config = Config(str(BACKEND_DIR / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    expected_heads = set(ScriptDirectory.from_config(config).get_heads())
    with engine.connect() as connection:
        current = MigrationContext.configure(connection).get_current_revision()
    if current is None or current not in expected_heads:
        raise SystemExit("MIGRATION_CHECK=FAIL database is not at Alembic head")
    print("MIGRATION_CHECK=PASS")


if __name__ == "__main__":
    main()
