"""Đồng bộ MongoDB → SQLite local cho web admin.

Chạy:
    python admin_web/sync_mongo.py

Công việc:
    1. Kết nối MongoDB, tự dò database + collection nếu .env không chỉ định.
    2. Đọc collection cây cá nhân (user_plants) → suy ra danh sách user_id.
    3. Đọc collection chat (nếu có) → ghi vào bảng chat_messages.
    4. (Tuỳ chọn) Gọi backend API /api/auth/login + /api/auth/me cho mỗi
       credentials trong .env để lấy username/email/phone/avatar đầy đủ.
    5. Ghi nhật ký vào bảng sync_log.

Có thể chạy lại nhiều lần — dữ liệu được upsert, không nhân bản.
"""

from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

import db  # noqa: E402
from config import API_BASE_URL, MONGO_DB, MONGO_URI, credentials  # noqa: E402

try:
    from pymongo import MongoClient
except ImportError:  # pragma: no cover
    print("Thiếu pymongo. Chạy: pip install -r admin_web/requirements.txt")
    raise SystemExit(1)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def log(msg: str) -> None:
    print(f"[sync] {msg}")


# ── Dò cấu trúc MongoDB ───────────────────────────────────────────────────


def pick_database(client: MongoClient) -> str:
    """Chọn database: ưu tiên .env, không thì database đầu tiên có dữ liệu."""
    names = client.list_database_names()
    names = [n for n in names if n not in ("admin", "config", "local")]
    if MONGO_DB:
        if MONGO_DB not in names:
            log(f"⚠ MONGO_DB='{MONGO_DB}' không tồn tại. Các DB có: {names}")
        return MONGO_DB
    if not names:
        raise RuntimeError("Không tìm thấy database nào trong MongoDB.")
    log(f"Tự dò database: {names}")
    return names[0]


def pick_collection(db_handle, hint: str, keywords: tuple[str, ...]) -> str | None:
    """Chọn collection theo gợi ý, không thì theo tên chứa keyword."""
    try:
        names = db_handle.list_collection_names()
    except Exception as exc:  # pragma: no cover
        log(f"Không liệt kê được collection: {exc}")
        return None
    if hint:
        if hint in names:
            return hint
        log(f"⚠ Collection '{hint}' không tồn tại. Có: {names}")
    for name in names:
        low = name.lower()
        if any(k in low for k in keywords):
            return name
    return None


# ── Lấy profile từ backend API ────────────────────────────────────────────


def fetch_profiles(creds: list[tuple[str, str]]) -> dict[str, dict[str, Any]]:
    """Đăng nhập từng tài khoản để lấy profile đầy đủ.

    Trả về: { user_id: {username, display_name, email, phone_number, avatar_url} }
    """
    if not creds:
        return {}
    try:
        import requests
    except ImportError:  # pragma: no cover
        log("Thiếu requests — bỏ qua bước lấy profile.")
        return {}

    result: dict[str, dict[str, Any]] = {}
    for username, password in creds:
        try:
            resp = requests.post(
                f"{API_BASE_URL}/api/auth/login",
                json={"username": username, "password": password},
                timeout=15,
            )
            if resp.status_code != 200:
                log(f"✗ Login '{username}' → HTTP {resp.status_code}")
                continue
            payload = resp.json()
            token = payload.get("access_token") or ""
            user = payload.get("user") or {}
            if not token:
                log(f"✗ Login '{username}' → không có access_token")
                continue

            profile = dict(user)
            if not profile:
                me = requests.get(
                    f"{API_BASE_URL}/api/auth/me",
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=15,
                )
                if me.status_code == 200:
                    profile = me.json()
            user_id = str(profile.get("id") or profile.get("user_id") or "").strip()
            if not user_id:
                log(f"✗ '{username}' → profile không có id")
                continue
            result[user_id] = {
                "username": profile.get("username") or username,
                "display_name": profile.get("name")
                or profile.get("display_name")
                or profile.get("full_name")
                or "",
                "email": profile.get("email") or "",
                "phone_number": profile.get("phone_number")
                or profile.get("phone")
                or "",
                "avatar_url": profile.get("avatar_url") or profile.get("avatar") or "",
            }
            log(f"✓ Profile '{username}' → user_id={user_id}")
        except Exception as exc:
            log(f"✗ Login '{username}' lỗi: {exc}")
    return result


# ── Đồng bộ chính ─────────────────────────────────────────────────────────


def main() -> int:
    started = now_iso()
    db.init_db()
    log(f"MONGO_URI = {MONGO_URI}")

    try:
        client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=8000)
        client.admin.command("ping")
    except Exception as exc:
        log(f"✗ Không kết nối được MongoDB: {exc}")
        log("  → kiểm tra MONGO_URI, hoặc dùng SSH tunnel:")
        log("    ssh -L 27017:127.0.0.1:27017 user@222.255.184.116")
        db.log_sync(started, now_iso(), 0, 0, 0, "error", str(exc))
        return 1

    db_name = pick_database(client)
    handle = client[db_name]
    log(f"Database: {db_name}")

    plant_col_name = pick_collection(
        handle, "", ("user_plant", "userplant", "plants", "plant")
    )
    chat_col_name = pick_collection(
        handle, "", ("chat", "conversation", "message")
    )
    log(f"Collection cây cá nhân : {plant_col_name}")
    log(f"Collection chat       : {chat_col_name}")

    # ── 1. Cây cá nhân ──
    plant_docs: list[dict[str, Any]] = []
    if plant_col_name:
        plant_docs = list(handle[plant_col_name].find({}))
    log(f"Đọc {len(plant_docs)} document cây cá nhân")

    user_ids: set[str] = set()
    for doc in plant_docs:
        uid = str(doc.get("user_id") or doc.get("userId") or "").strip()
        if uid:
            user_ids.add(uid)
        db.upsert_plant(doc)

    # ── 2. Chat ──
    chat_docs: list[dict[str, Any]] = []
    if chat_col_name:
        chat_docs = list(handle[chat_col_name].find({}))
    log(f"Đọc {len(chat_docs)} document chat")

    chat_by_user: dict[str, int] = {}
    for doc in chat_docs:
        uid = str(doc.get("user_id") or doc.get("userId") or "").strip()
        if uid:
            chat_by_user[uid] = chat_by_user.get(uid, 0) + 1
            user_ids.add(uid)
        db.upsert_chat(doc, uid)

    # ── 3. Profile từ API ──
    creds = credentials()
    profiles = fetch_profiles(creds) if creds else {}
    if not creds:
        log("Không có AUTH_CREDENTIALS → bỏ qua lấy profile đầy đủ.")

    # ── 4. Ghi bảng users ──
    plant_by_user: dict[str, int] = {}
    dates_by_user: dict[str, list[str]] = {}
    for doc in plant_docs:
        uid = str(doc.get("user_id") or doc.get("userId") or "").strip()
        if not uid:
            continue
        plant_by_user[uid] = plant_by_user.get(uid, 0) + 1
        created = str(doc.get("created_at") or doc.get("captured_at") or "")
        if created:
            dates_by_user.setdefault(uid, []).append(created)

    for uid in user_ids:
        profile = profiles.get(uid, {})
        seen = dates_by_user.get(uid) or []
        source = "mongo"
        if profile:
            source = "mongo+api"
        db.upsert_user(
            uid,
            username=profile.get("username", ""),
            display_name=profile.get("display_name", ""),
            email=profile.get("email", ""),
            phone_number=profile.get("phone_number", ""),
            avatar_url=profile.get("avatar_url", ""),
            source=source,
            plant_count=plant_by_user.get(uid, 0),
            chat_count=chat_by_user.get(uid, 0),
            first_seen=min(seen) if seen else None,
            last_seen=max(seen) if seen else None,
            updated_at=now_iso(),
        )

    db.log_sync(
        started,
        now_iso(),
        len(user_ids),
        len(plant_docs),
        len(chat_docs),
        "ok",
        f"db={db_name} plants={plant_col_name} chat={chat_col_name}",
    )

    log("─" * 50)
    log(f"✅ Hoàn tất: {len(user_ids)} user, {len(plant_docs)} cây, {len(chat_docs)} chat")
    log(f"   DB: {db.DB_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
