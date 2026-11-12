"""Cấu hình chung cho admin_web (đọc .env, có giá trị mặc định).

Dùng bởi: sync_mongo.py, server.py
"""

from __future__ import annotations

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
DB_PATH = DATA_DIR / "plant_medical.db"
STATIC_DIR = BASE_DIR / "static"


def _load_dotenv() -> None:
    """Đọc file .env đơn giản (không cần phụ thuộc python-dotenv)."""
    env_path = BASE_DIR / ".env"
    if not env_path.exists():
        return
    for raw in env_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


_load_dotenv()


def env(key: str, default: str = "") -> str:
    return os.environ.get(key, default).strip()


# ── MongoDB ───────────────────────────────────────────────────────────────
MONGO_URI = env("MONGO_URI", "mongodb://127.0.0.1:27017")
MONGO_DB = env("MONGO_DB")

# ── Backend API ───────────────────────────────────────────────────────────
API_BASE_URL = env("API_BASE_URL", "http://222.255.184.116").rstrip("/")
AUTH_CREDENTIALS = env("AUTH_CREDENTIALS")

# ── Web server ────────────────────────────────────────────────────────────
HOST = env("HOST", "127.0.0.1")
PORT = int(env("PORT", "8080") or "8080")


def credentials() -> list[tuple[str, str]]:
    """Parse AUTH_CREDENTIALS thành danh sách (username, password)."""
    result: list[tuple[str, str]] = []
    for chunk in AUTH_CREDENTIALS.replace(";", ",").split(","):
        chunk = chunk.strip()
        if not chunk or ":" not in chunk:
            continue
        username, _, password = chunk.partition(":")
        username = username.strip()
        password = password.strip()
        if username:
            result.append((username, password))
    return result
