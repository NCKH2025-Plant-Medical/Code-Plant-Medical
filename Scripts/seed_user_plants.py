import asyncio
import os
import sys

# Ensure UTF-8 output on Windows
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')

from datetime import datetime, timezone
from bson import ObjectId

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)
sys.path.insert(0, PROJECT_ROOT)

from dotenv import load_dotenv
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

from motor.motor_asyncio import AsyncIOMotorClient

SAMPLE_USER_PLANTS = [
    {
        "plant_id": "dinh_lang",
        "name": "Cây Đinh lăng cá nhân",
        "scientific_name": "Polyscias fruticosa",
        "confidence": "96.50%",
        "image_url": "https://images.unsplash.com/photo-1545241047-6083a3684587?w=600",
        "thumbnail_url": "https://images.unsplash.com/photo-1545241047-6083a3684587?w=300",
        "cloudinary_public_id": "seed_dinh_lang_01",
        "offset_lat": 0.0050,
        "offset_lng": 0.0040,
        "notes": "Trồng trong chậu ở ban công, cây phát triển tốt, lá xanh đậm.",
    },
    {
        "plant_id": "ca_gai_leo",
        "name": "Cây Cà gai leo vườn nhà",
        "scientific_name": "Solanum procumbens",
        "confidence": "94.20%",
        "image_url": "https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?w=600",
        "thumbnail_url": "https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?w=300",
        "cloudinary_public_id": "seed_ca_gai_leo_01",
        "offset_lat": -0.0080,
        "offset_lng": 0.0060,
        "notes": "Thu hoạch cành và rễ để sao vàng hãm nước uống giải độc gan.",
    },
    {
        "plant_id": "xa_den",
        "name": "Xạ đen góc sân",
        "scientific_name": "Ehretia asperula",
        "confidence": "92.80%",
        "image_url": "https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?w=600",
        "thumbnail_url": "https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?w=300",
        "cloudinary_public_id": "seed_xa_den_01",
        "offset_lat": 0.0120,
        "offset_lng": -0.0090,
        "notes": "Cây leo khỏe, tưới nước 2 ngày một lần.",
    },
    {
        "plant_id": "kim_ngan_hoa",
        "name": "Kim ngân hoa rào trước",
        "scientific_name": "Lonicera japonica",
        "confidence": "98.10%",
        "image_url": "https://images.unsplash.com/photo-1463936575829-25148e1db1b8?w=600",
        "thumbnail_url": "https://images.unsplash.com/photo-1463936575829-25148e1db1b8?w=300",
        "cloudinary_public_id": "seed_kim_ngan_01",
        "offset_lat": -0.0040,
        "offset_lng": -0.0070,
        "notes": "Hoa nở vàng thơm ngát, hái phơi khô pha trà thanh nhiệt.",
    },
    {
        "plant_id": "diep_ha_chau",
        "name": "Chó đẻ răng cưa mọc bờ tường",
        "scientific_name": "Phyllanthus urinaria",
        "confidence": "91.30%",
        "image_url": "https://images.unsplash.com/photo-1530968464165-7a1861cbaf9f?w=600",
        "thumbnail_url": "https://images.unsplash.com/photo-1530968464165-7a1861cbaf9f?w=300",
        "cloudinary_public_id": "seed_diep_ha_chau_01",
        "offset_lat": 0.0150,
        "offset_lng": 0.0110,
        "notes": "Mọc hoang nhưng là thuốc quý tiêu viêm.",
    },
]

# Tọa độ cơ sở (Hà Nội: 21.0285, 105.8542)
BASE_LAT = 21.0285
BASE_LNG = 105.8542

async def seed_user_plants():
    url = os.getenv("MONGODB_URL")
    client = AsyncIOMotorClient(url)
    db = client.plant_vision_db
    users_coll = db.users
    user_plants_coll = db.UserPlants

    users = await users_coll.find({}).to_list(100)
    print(f"[*] Tìm thấy {len(users)} users trong collection 'users'.")

    try:
        await user_plants_coll.create_index([("location", "2dsphere")])
    except Exception as e:
        print(f"[*] Index location_2dsphere đã tồn tại ({e.__class__.__name__}).")

    try:
        await user_plants_coll.create_index([("user_id", 1)])
    except Exception as e:
        print(f"[*] Index user_id đã tồn tại ({e.__class__.__name__}).")

    total_inserted = 0
    for u_idx, user in enumerate(users):
        user_id_str = str(user["_id"])
        username = user.get("username") or f"user_{user_id_str[:6]}"

        # Kiểm tra xem user này đã có cây cá nhân chưa
        count = await user_plants_coll.count_documents({"user_id": user_id_str})
        if count >= 3:
            print(f"[~] User {username} ({user_id_str}) đã có {count} cây. Bỏ qua.")
            continue

        # Nạp 3-5 cây mẫu cho user
        plants_to_insert = []
        for p_idx, p_data in enumerate(SAMPLE_USER_PLANTS):
            lat = round(BASE_LAT + p_data["offset_lat"] + (u_idx * 0.0035), 7)
            lng = round(BASE_LNG + p_data["offset_lng"] + (u_idx * 0.0042), 7)
            
            doc = {
                "user_id": user_id_str,
                "plant_id": p_data["plant_id"],
                "name": f"{p_data['name']} ({username})",
                "scientific_name": p_data["scientific_name"],
                "confidence": p_data["confidence"],
                "image_url": p_data["image_url"],
                "thumbnail_url": p_data["thumbnail_url"],
                "cloudinary_public_id": f"{p_data['cloudinary_public_id']}_{user_id_str[:6]}",
                "location": {
                    "type": "Point",
                    "coordinates": [lng, lat],  # GeoJSON: [lng, lat]
                },
                "notes": p_data["notes"],
                "created_at": datetime.now(timezone.utc),
            }
            plants_to_insert.append(doc)

        result = await user_plants_coll.insert_many(plants_to_insert)
        total_inserted += len(result.inserted_ids)
        print(f"[+] Đã thêm {len(result.inserted_ids)} cây cá nhân cho user {username} ({user_id_str}).")

    print(f"\n[DONE] Tổng số cây cá nhân đã nạp vào MongoDB: {total_inserted}")

if __name__ == "__main__":
    asyncio.run(seed_user_plants())
