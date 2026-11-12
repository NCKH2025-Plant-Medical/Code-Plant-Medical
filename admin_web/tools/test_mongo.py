"""Kiểm tra một MONGO_URI có dùng được không + liệt kê cấu trúc DB.

Dùng:
    python admin_web/tools/test_mongo.py
    python admin_web/tools/test_mongo.py "mongodb://user:pass@host:27017/?authSource=admin"

Nếu không truyền tham số, script đọc MONGO_URI từ admin_web/.env.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from config import MONGO_URI  # noqa: E402

try:
    from pymongo import MongoClient
except ImportError:
    print("Thiếu pymongo. Chạy: pip install -r admin_web/requirements.txt")
    raise SystemExit(1)


def main() -> int:
    uri = sys.argv[1].strip() if len(sys.argv) > 1 else MONGO_URI
    if not uri:
        print("Chưa có URI. Dùng: python test_mongo.py \"mongodb://...\"")
        return 1

    # Ẩn mật khẩu khi in ra log
    safe = uri
    if "://" in uri:
        scheme, _, rest = uri.partition("://")
        if "@" in rest:
            creds, _, host = rest.rpartition("@")
            safe = f"{scheme}://***:***@{host}"
        else:
            safe = f"{scheme}://{rest}"

    print(f"URI: {safe}")
    try:
        client = MongoClient(uri, serverSelectionTimeoutMS=8000)
        client.admin.command("ping")
    except Exception as exc:
        print(f"✗ KHÔNG kết nối được: {exc}")
        print()
        print("Nguyên nhân thường gặp:")
        print("  • Sai host/port — kiểm tra bằng: ssh -L 27017:127.0.0.1:27017 user@server")
        print("  • Sai user/password hoặc thiếu ?authSource=admin")
        print("  • MongoDB chỉ bind 127.0.0.1 trên server → cần SSH tunnel")
        return 1

    print("✓ Kết nối thành công!\n")

    for db_name in client.list_database_names():
        if db_name in ("admin", "config", "local"):
            continue
        print(f"── Database: {db_name} ──")
        handle = client[db_name]
        for coll in handle.list_collection_names():
            count = handle[coll].estimated_document_count()
            print(f"   {coll:<30} {count:>8} docs")
            doc = handle[coll].find_one()
            if doc:
                keys = ", ".join(list(doc.keys())[:12])
                print(f"      └─ fields: {keys}")
        print()

    print("→ Điền URI vào admin_web/.env (dòng MONGO_URI) rồi chạy sync_mongo.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
