"""Create explicitly synthetic development-only reference data."""

from app.config import get_settings
from app.models.database import Dietitian, SessionLocal


SYNTHETIC_DIETITIAN_EMAIL = "sandbox-dietitian@example.com"


def main() -> None:
    settings = get_settings()
    if settings.app_environment.lower() not in {"dev", "test"}:
        raise RuntimeError("Sentetik seed yalnızca dev/test ortamında çalıştırılabilir.")

    db = SessionLocal()
    try:
        existing = db.query(Dietitian).filter(
            Dietitian.email == SYNTHETIC_DIETITIAN_EMAIL
        ).first()
        if existing is None:
            db.add(
                Dietitian(
                    email=SYNTHETIC_DIETITIAN_EMAIL,
                    full_name="Synthetic Sandbox Dietitian",
                    email_verified=True,
                    phone_verified=False,
                    specialization="SYNTHETIC TEST RECORD",
                )
            )
            db.commit()
            print("Synthetic sandbox dietitian created.")
        else:
            print("Synthetic sandbox dietitian already exists.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
