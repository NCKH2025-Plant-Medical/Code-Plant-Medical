#!/usr/bin/env python3
# Scripts/create_user_plants_index.py
#
# Script tạo 2dsphere index cho collection UserPlants.
# Chạy MỘT LẦN khi deploy hoặc khi cần re-index.
#
# Chạy:
#   python Scripts/create_user_plants_index.py
#
# Yêu cầu: MONGODB_URL phải có trong .env (hoặc biến môi trường).

import asyncio
import os
import sys

# Đảm bảo in tiếng Việt / emoji trên console Windows không bị lỗi
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

# Đảm bảo import được từ project root
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from dotenv import load_dotenv
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import ASCENDING, GEOSPHERE
from pymongo.errors import PyMongoError

MONGODB_URL = os.getenv("MONGODB_URL")
if not MONGODB_URL:
    print("❌  Chưa tìm thấy biến MONGODB_URL trong .env!")
    sys.exit(1)

DB_NAME         = "plant_vision_db"
COLLECTION_NAME = "UserPlants"


async def create_indexes() -> None:
    client = AsyncIOMotorClient(MONGODB_URL, serverSelectionTimeoutMS=10_000)
    db         = client[DB_NAME]
    collection = db[COLLECTION_NAME]

    print(f"🔗  Đang kết nối tới: {MONGODB_URL[:50]}...")

    try:
        await client.admin.command("ping")
        print("✅  Kết nối MongoDB thành công.\n")
    except PyMongoError as e:
        print(f"❌  Không thể kết nối MongoDB: {e}")
        client.close()
        sys.exit(1)

    # ── 1. 2dsphere index trên field location ────────────────────────────
    #    Dữ liệu kỳ vọng: { "location": { "type": "Point", "coordinates": [lng, lat] } }
    print("📐  Tạo 2dsphere index trên  UserPlants.location ...")
    try:
        index_name = await collection.create_index(
            [("location", GEOSPHERE)],
            name="location_2dsphere",
            background=True,   # Không block đọc ghi trong lúc build
            sparse=True,       # Bỏ qua document không có field location
        )
        print(f"    ✅  Index '{index_name}' đã được tạo (hoặc đã tồn tại).")
    except PyMongoError as e:
        print(f"    ❌  Lỗi tạo 2dsphere index: {e}")

    # ── 2. Compound index (user_id + location) ────────────────────────────
    #    Tối ưu query: lọc user_id trước → thu hẹp tập hợp geo search.
    #    MongoDB sẽ dùng index này khi query có CẢ HAI điều kiện.
    print("\n📐  Tạo compound index (user_id, location_2dsphere) ...")
    try:
        compound_name = await collection.create_index(
            [("user_id", ASCENDING), ("location", GEOSPHERE)],
            name="user_id_location_2dsphere",
            background=True,
            sparse=True,
        )
        print(f"    ✅  Index '{compound_name}' đã được tạo (hoặc đã tồn tại).")
    except PyMongoError as e:
        # Atlas Free Tier không cho compound 2dsphere — dùng single index vẫn OK
        print(f"    ⚠️   Compound index không tạo được (có thể do giới hạn Atlas Free): {e}")
        print("        → Sẽ dùng single 2dsphere index, performance vẫn ổn.")

    # ── 3. Liệt kê tất cả index hiện tại ─────────────────────────────────
    print(f"\n📋  Danh sách index hiện tại của collection '{COLLECTION_NAME}':")
    async for idx in collection.list_indexes():
        print(f"    • {idx['name']}  →  keys: {dict(idx['key'])}")

    client.close()
    print("\n🎉  Hoàn tất tạo index!\n")


if __name__ == "__main__":
    asyncio.run(create_indexes())
