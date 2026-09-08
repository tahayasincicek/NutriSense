#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Yeni klon için geliştirme ortamını hazırlar.

`backend/.env.example` dosyasını kopyalar ve REPLACE ile işaretli gizli
değerleri kriptografik olarak güvenli rastgele değerlerle doldurur. Var olan
bir `.env` dosyasının üzerine yazmaz.

Kullanım (depo kökünde):
    python scripts/dev_setup.py
"""

from __future__ import annotations

import re
import secrets
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXAMPLE = ROOT / "backend" / ".env.example"
TARGET = ROOT / "backend" / ".env"


def _token(length: int = 48) -> str:
    return secrets.token_urlsafe(length)


def _password(length: int = 24) -> str:
    # Bağlantı dizesinde ayrıştırma sorunu çıkarmayacak alfasayısal parola.
    alphabet = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return "".join(secrets.choice(alphabet) for _ in range(length))


def main() -> int:
    if not EXAMPLE.is_file():
        print(f"HATA: {EXAMPLE} bulunamadı.", file=sys.stderr)
        return 1
    if TARGET.exists():
        print(f"{TARGET} zaten var; dokunulmadı.")
        print("Yeniden üretmek isterseniz önce bu dosyayı silin.")
        return 0

    shutil.copyfile(EXAMPLE, TARGET)
    text = TARGET.read_text(encoding="utf-8")

    # Veritabanı parolası hem DATABASE_URL hem DB_PASSWORD içinde aynı olmalı.
    db_password = _password()
    text = text.replace("REPLACE_DB_PASSWORD", db_password)
    text = text.replace("REPLACE_ROOT_PASSWORD", _password())

    # Kalan REPLACE_* değerleri bağımsız rastgele belirteçlerdir.
    text = re.sub(r"REPLACE[A-Z_]*", lambda _m: _token(), text)

    TARGET.write_text(text, encoding="utf-8", newline="\n")

    remaining = [
        line.split("=", 1)[0]
        for line in text.splitlines()
        if "REPLACE" in line and not line.lstrip().startswith("#")
    ]
    print(f"Oluşturuldu: {TARGET}")
    print("Gizli değerler rastgele üretildi; bu dosya Git'e girmez.")
    if remaining:
        print("Elle doldurulması gerekenler:", ", ".join(remaining))
    else:
        print("Elle doldurulması gereken zorunlu değer yok.")
    print()
    print("Sıradaki adım:")
    print("  docker compose -f backend/docker-compose.yml up -d")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
