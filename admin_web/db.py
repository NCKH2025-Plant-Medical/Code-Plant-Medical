"""Lớp truy cập SQLite local — 'cơ sở dữ liệu' cho web admin.

CSDL được tạo bởi sync_mongo.py (đồng bộ từ MongoDB) và bổ sung profile
đầy đủ lấy từ backend API (username/email/phone/avatar).

Schema
------
users       : 1 dòng / user_id — profile + thống kê tổng hợp
user_plants : lịch sử nhận diện / cây cá nhân (có GPS)
chat_messages: lịch sử chat (nếu tìm thấy collection chat trong MongoDB)
sync_log    : nhật ký các lần đồng bộ
"""

from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

from config import DATA_DIR, DB_PATH

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    user_id       TEXT PRIMARY KEY,
    username      TEXT,
    display_name  TEXT,
    email         TEXT,
    phone_number  TEXT,
    avatar_url    TEXT,
    source        TEXT,              -- 'mongo' | 'api' | 'mongo+api'
    plant_count   INTEGER DEFAULT 0,
    chat_count    INTEGER DEFAULT 0,
    first_seen    TEXT,
    last_seen     TEXT,
    updated_at    TEXT
);

CREATE TABLE IF NOT EXISTS user_plants (
    id              TEXT PRIMARY KEY,
    user_id         TEXT,
    plant_id        TEXT,
    name            TEXT,
    scientific_name TEXT,
    image_url       TEXT,
    thumbnail_url   TEXT,
    notes           TEXT,
    confidence      REAL,
    latitude        REAL,
    longitude       REAL,
    created_at      TEXT,
    raw_json        TEXT
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id           TEXT PRIMARY KEY,
    user_id      TEXT,
    conversation_id TEXT,
    sender       TEXT,
    msg_type     TEXT,
    text_content TEXT,
    image_url    TEXT,
    created_at   TEXT,
    raw_json     TEXT
);

CREATE TABLE IF NOT EXISTS sync_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at TEXT,
    ended_at   TEXT,
    users      INTEGER DEFAULT 0,
    plants     INTEGER DEFAULT 0,
    chats      INTEGER DEFAULT 0,
    status     TEXT,
    message    TEXT
);

CREATE INDEX IF NOT EXISTS idx_plants_user  ON user_plants(user_id);
CREATE INDEX IF NOT EXISTS idx_plants_date  ON user_plants(created_at);
CREATE INDEX IF NOT EXISTS idx_chat_user    ON chat_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_conv    ON chat_messages(conversation_id);
"""


def _connect() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


@contextmanager
def cursor() -> Iterator[sqlite3.Cursor]:
    conn = _connect()
    try:
        cur = conn.cursor()
        yield cur
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db() -> None:
    """Tạo bảng nếu chưa có."""
    conn = _connect()
    try:
        conn.executescript(SCHEMA)
        conn.commit()
    finally:
        conn.close()


def row_to_dict(row: sqlite3.Row | None) -> dict[str, Any] | None:
    if row is None:
        return None
    return {k: row[k] for k in row.keys()}


def query_all(sql: str, params: tuple | dict = ()) -> list[dict[str, Any]]:
    with cursor() as cur:
        cur.execute(sql, params)
        return [dict(r) for r in cur.fetchall()]


def query_one(sql: str, params: tuple | dict = ()) -> dict[str, Any] | None:
    with cursor() as cur:
        cur.execute(sql, params)
        return row_to_dict(cur.fetchone())


def execute(sql: str, params: tuple | dict = ()) -> int:
    with cursor() as cur:
        cur.execute(sql, params)
        return cur.rowcount


def upsert_user(user_id: str, **fields: Any) -> None:
    """Insert hoặc update 1 user (không ghi đè field đang có nếu value mới rỗng)."""
    if not user_id:
        return
    existing = query_one("SELECT * FROM users WHERE user_id = ?", (user_id,))
    payload: dict[str, Any] = {}
    for key in (
        "username",
        "display_name",
        "email",
        "phone_number",
        "avatar_url",
        "source",
    ):
        value = fields.get(key)
        if value not in (None, ""):
            payload[key] = value
    for key in ("plant_count", "chat_count"):
        if fields.get(key) is not None:
            payload[key] = int(fields[key])
    for key in ("first_seen", "last_seen", "updated_at"):
        if fields.get(key):
            payload[key] = fields[key]

    if existing is None:
        columns = ["user_id", *payload.keys()]
        placeholders = ", ".join("?" for _ in columns)
        execute(
            f"INSERT INTO users ({', '.join(columns)}) VALUES ({placeholders})",
            (user_id, *payload.values()),
        )
    elif payload:
        assignments = ", ".join(f"{k} = ?" for k in payload)
        execute(
            f"UPDATE users SET {assignments} WHERE user_id = ?",
            (*payload.values(), user_id),
        )


def upsert_plant(doc: dict[str, Any]) -> None:
    pid = str(doc.get("id") or doc.get("_id") or "").strip()
    if not pid:
        return
    execute(
        """
        INSERT OR REPLACE INTO user_plants
            (id, user_id, plant_id, name, scientific_name, image_url,
             thumbnail_url, notes, confidence, latitude, longitude, created_at, raw_json)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        (
            pid,
            doc.get("user_id") or "",
            doc.get("plant_id") or "",
            doc.get("name") or doc.get("common_name") or "",
            doc.get("scientific_name") or doc.get("scientificName") or "",
            doc.get("image_url") or "",
            doc.get("thumbnail_url") or "",
            doc.get("notes") or doc.get("description") or "",
            doc.get("confidence"),
            doc.get("latitude", doc.get("lat")),
            doc.get("longitude", doc.get("lng", doc.get("lon"))),
            doc.get("created_at") or doc.get("captured_at") or "",
            json.dumps(doc, ensure_ascii=False, default=str),
        ),
    )


def upsert_chat(doc: dict[str, Any], user_id: str = "") -> None:
    cid = str(doc.get("id") or doc.get("_id") or "").strip()
    if not cid:
        return
    execute(
        """
        INSERT OR REPLACE INTO chat_messages
            (id, user_id, conversation_id, sender, msg_type, text_content,
             image_url, created_at, raw_json)
        VALUES (?,?,?,?,?,?,?,?,?)
        """,
        (
            cid,
            doc.get("user_id") or user_id,
            doc.get("conversation_id") or doc.get("conversationId") or "",
            doc.get("sender") or "",
            doc.get("msg_type") or doc.get("msgType") or "",
            doc.get("text_content") or doc.get("textContent") or "",
            doc.get("image_url") or doc.get("imageUrl") or "",
            doc.get("created_at") or doc.get("createdAt") or "",
            json.dumps(doc, ensure_ascii=False, default=str),
        ),
    )


def log_sync(
    started_at: str,
    ended_at: str,
    users: int,
    plants: int,
    chats: int,
    status: str,
    message: str = "",
) -> None:
    execute(
        """
        INSERT INTO sync_log
            (started_at, ended_at, users, plants, chats, status, message)
        VALUES (?,?,?,?,?,?,?)
        """,
        (started_at, ended_at, users, plants, chats, status, message),
    )


def stats() -> dict[str, Any]:
    """Thống kê tổng quan cho dashboard."""
    with cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM users")
        users = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM user_plants")
        plants = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM chat_messages")
        chats = cur.fetchone()[0]
        cur.execute(
            "SELECT COUNT(*) FROM user_plants WHERE latitude IS NOT NULL "
            "AND latitude != 0 AND longitude IS NOT NULL AND longitude != 0"
        )
        located = cur.fetchone()[0]
        cur.execute(
            "SELECT COUNT(DISTINCT user_id) FROM user_plants WHERE user_id != ''"
        )
        active_users = cur.fetchone()[0]
    return {
        "users": users,
        "plants": plants,
        "chats": chats,
        "located_plants": located,
        "active_users": active_users,
    }
