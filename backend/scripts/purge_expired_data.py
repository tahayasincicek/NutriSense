"""Süresi dolan kişisel veriyi imha eder ve imha kaydı yazar.

Günlük çalıştırılması önerilir; KVKK'da periyodik imha aralığı altı ayı
geçemez. Backend klasöründe:

    python scripts/purge_expired_data.py

Çıktı yalnız sayıları içerir; kişisel veri yazdırılmaz.
"""

import json

from app.config import get_settings
from app.domain.retention import purge_expired_personal_data
from app.models.database import SessionLocal


def main() -> None:
    settings = get_settings()
    settings.validate_security()
    db = SessionLocal()
    try:
        counts = purge_expired_personal_data(db, settings)
    finally:
        db.close()
    print(json.dumps(counts, sort_keys=True))


if __name__ == "__main__":
    main()
