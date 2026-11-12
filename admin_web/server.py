"""Web server admin — Flask, serve static + REST API đọc từ SQLite local.

Chạy:
    python admin_web/server.py
    → http://localhost:8080

REST API
--------
GET /api/stats                 thống kê tổng quan
GET /api/users                 danh sách user (lọc/ sắp xếp / phân trang)
GET /api/users/<user_id>       chi tiết 1 user + cây + chat
GET /api/plants                lịch sử nhận diện (lọc theo user / có GPS / ngày)
GET /api/chats                 lịch sử chat
GET /api/sync-log              nhật ký đồng bộ
GET /api/health                kiểm tra sống
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from flask import Flask, jsonify, request, send_from_directory  # noqa: E402
from flask_cors import CORS  # noqa: E402

import db  # noqa: E402
from config import HOST, PORT, STATIC_DIR  # noqa: E402

app = Flask(__name__, static_folder=None)
CORS(app)

db.init_db()


# ── Helpers ───────────────────────────────────────────────────────────────


def _int_arg(name: str, default: int) -> int:
    try:
        return int(request.args.get(name, default))
    except (TypeError, ValueError):
        return default


# ── API ───────────────────────────────────────────────────────────────────


@app.get("/api/health")
def health():
    return jsonify({"ok": True, "db": str(db.DB_PATH)})


@app.get("/api/stats")
def api_stats():
    data = db.stats()
    data["last_sync"] = db.query_one(
        "SELECT * FROM sync_log ORDER BY id DESC LIMIT 1"
    )
    return jsonify(data)


@app.get("/api/users")
def api_users():
    q = (request.args.get("q") or "").strip()
    page = max(1, _int_arg("page", 1))
    limit = max(1, min(200, _int_arg("limit", 50)))
    sort = request.args.get("sort") or "last_seen"
    order = "DESC" if request.args.get("order", "desc").lower() != "asc" else "ASC"
    allowed_sort = {
        "last_seen",
        "first_seen",
        "plant_count",
        "chat_count",
        "username",
        "display_name",
    }
    if sort not in allowed_sort:
        sort = "last_seen"

    where = []
    params: list = []
    if q:
        where.append(
            "(user_id LIKE ? OR username LIKE ? OR display_name LIKE ? "
            "OR email LIKE ? OR phone_number LIKE ?)"
        )
        params += [f"%{q}%"] * 5
    clause = f"WHERE {' AND '.join(where)}" if where else ""

    total = db.query_one(f"SELECT COUNT(*) AS n FROM users {clause}", params)
    offset = (page - 1) * limit
    rows = db.query_all(
        f"SELECT * FROM users {clause} ORDER BY {sort} {order} LIMIT ? OFFSET ?",
        (*params, limit, offset),
    )
    return jsonify(
        {
            "total": (total or {}).get("n", 0),
            "page": page,
            "limit": limit,
            "items": rows,
        }
    )


@app.get("/api/users/<path:user_id>")
def api_user_detail(user_id: str):
    user = db.query_one("SELECT * FROM users WHERE user_id = ?", (user_id,))
    if user is None:
        return jsonify({"error": "not found"}), 404
    user["plants"] = db.query_all(
        "SELECT * FROM user_plants WHERE user_id = ? ORDER BY created_at DESC",
        (user_id,),
    )
    user["chats"] = db.query_all(
        "SELECT id, conversation_id, sender, msg_type, text_content, image_url, "
        "created_at FROM chat_messages WHERE user_id = ? ORDER BY created_at DESC",
        (user_id,),
    )
    return jsonify(user)


@app.get("/api/plants")
def api_plants():
    q = (request.args.get("q") or "").strip()
    user_id = (request.args.get("user_id") or "").strip()
    located = request.args.get("located")
    page = max(1, _int_arg("page", 1))
    limit = max(1, min(500, _int_arg("limit", 100)))

    where = []
    params: list = []
    if user_id:
        where.append("user_id = ?")
        params.append(user_id)
    if q:
        where.append("(name LIKE ? OR scientific_name LIKE ? OR notes LIKE ?)")
        params += [f"%{q}%"] * 3
    if located == "1":
        where.append(
            "latitude IS NOT NULL AND latitude != 0 "
            "AND longitude IS NOT NULL AND longitude != 0"
        )
    clause = f"WHERE {' AND '.join(where)}" if where else ""

    total = db.query_one(f"SELECT COUNT(*) AS n FROM user_plants {clause}", params)
    offset = (page - 1) * limit
    rows = db.query_all(
        f"SELECT * FROM user_plants {clause} ORDER BY created_at DESC LIMIT ? OFFSET ?",
        (*params, limit, offset),
    )
    return jsonify(
        {
            "total": (total or {}).get("n", 0),
            "page": page,
            "limit": limit,
            "items": rows,
        }
    )


@app.get("/api/chats")
def api_chats():
    user_id = (request.args.get("user_id") or "").strip()
    limit = max(1, min(500, _int_arg("limit", 100)))
    if user_id:
        rows = db.query_all(
            "SELECT * FROM chat_messages WHERE user_id = ? "
            "ORDER BY created_at DESC LIMIT ?",
            (user_id, limit),
        )
    else:
        rows = db.query_all(
            "SELECT * FROM chat_messages ORDER BY created_at DESC LIMIT ?", (limit,)
        )
    return jsonify({"total": len(rows), "items": rows})


@app.get("/api/sync-log")
def api_sync_log():
    rows = db.query_all("SELECT * FROM sync_log ORDER BY id DESC LIMIT 50")
    return jsonify({"items": rows})


# ── Static ────────────────────────────────────────────────────────────────


@app.get("/")
def index():
    return send_from_directory(STATIC_DIR, "index.html")


@app.get("/<path:filename>")
def static_files(filename: str):
    return send_from_directory(STATIC_DIR, filename)


def main() -> None:
    print(f"[admin_web] http://{HOST}:{PORT}")
    print(f"[admin_web] DB: {db.DB_PATH}")
    app.run(host=HOST, port=PORT, debug=False)


if __name__ == "__main__":
    main()
