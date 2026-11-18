# API/nearby/router.py
#
# Endpoint tìm kiếm cây thuốc quanh người dùng trong bán kính R (mặc định 3km)
# ─────────────────────────────────────────────────────────────────────────────
# Tách biệt toàn bộ logic tính toán khoảng cách (Haversine km/m), lọc bán kính,
# gộp nguồn dữ liệu Hệ thống + Cá nhân, và sắp xếp theo khoảng cách tăng dần về Backend.
# ─────────────────────────────────────────────────────────────────────────────

import asyncio
import logging
import math
from typing import List, Optional
from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

try:
    import database
except ImportError:
    from API import database

from API.auth.utils import get_optional_current_user
from API.user_plants.mongo import get_user_plants_collection

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/plants", tags=["Plants Nearby"])

IMAGE_BASE_URL = "http://222.255.184.116"


class NearbyPlantItem(BaseModel):
    id: str                          # Mã định danh (ten_label hoặc mongo _id)
    location_id: Optional[int] = None # Khóa định danh điểm tọa độ riêng
    name: str                        # Tên cây tiếng Việt
    scientific_name: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    latitude: float                  # Tọa độ thật hoặc tâm vùng bảo tồn
    longitude: float
    address_name: Optional[str] = None
    source: str                      # "system" hoặc "user"
    distance_km: float               # Khoảng cách số thực (km)
    distance_display: str            # Chuỗi định dạng hiển thị (vd "450 m" hoặc "2,3 km")
    is_protected: bool = False       # True nếu là cây bảo tồn
    protection_level: Optional[str] = None
    fuzzing_radius_meters: Optional[int] = None
    conservation_notes: Optional[str] = None
    is_exact_location: bool = True


def calculate_haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Tính khoảng cách hình cầu Haversine (km)."""
    r_lat1 = math.radians(lat1)
    r_lat2 = math.radians(lat2)
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)

    a = math.sin(d_lat / 2.0) ** 2 + math.cos(r_lat1) * math.cos(r_lat2) * (math.sin(d_lng / 2.0) ** 2)
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return 6371.0 * c


def format_distance(dist_km: float) -> str:
    """Định dạng khoảng cách chính xác theo km (ví dụ 2,3 km) hoặc mét (ví dụ 450 m)."""
    if dist_km < 1.0:
        meters = int(round(dist_km * 1000.0))
        return f"{meters} m"
    formatted = f"{dist_km:.1f}".replace(".", ",")
    return f"{formatted} km"


@router.get(
    "/nearby",
    response_model=List[NearbyPlantItem],
    summary="Tìm cây thuốc xung quanh người dùng trong bán kính (mặc định 3km)",
    description=(
        "Truy vấn cây hệ thống (MySQL) và cây cá nhân của user (MongoDB nếu đã đăng nhập) "
        "nằm trong bán kính `radius_km`. Tính toán khoảng cách chính xác, sắp xếp từ gần đến xa, "
        "định dạng chuỗi hiển thị theo km (2,3 km) hoặc m (450 m)."
    ),
)
async def get_nearby_plants(
    lat: float = Query(..., description="Vĩ độ hiện tại của người dùng"),
    lng: float = Query(..., description="Kinh độ hiện tại của người dùng"),
    radius_km: float = Query(3.0, ge=0.1, le=100.0, description="Bán kính tìm kiếm (km)"),
    limit: int = Query(50, ge=1, le=200, description="Số lượng kết quả tối đa"),
    current_user: Optional[dict] = Depends(get_optional_current_user),
) -> List[NearbyPlantItem]:
    if not (-90 <= lat <= 90 and -180 <= lng <= 180):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tọa độ GPS không hợp lệ.",
        )

    nearby_items: List[NearbyPlantItem] = []

    # ── 1. Cây hệ thống (MySQL) ──────────────────────────────────────────────
    try:
        sys_rows = await asyncio.get_running_loop().run_in_executor(
            None,
            database.get_system_plants_nearby,
            lat, lng, radius_km, limit,
        )
        for r in sys_rows:
            dist = float(r.get("distance_km") or 0.0)
            anh_minh_hoa = r.get("anh_minh_hoa")
            img_url = f"{IMAGE_BASE_URL}/static/plants/{anh_minh_hoa}" if anh_minh_hoa else None
            thong_tin = r.get("thong_tin") or ""
            short_desc = thong_tin[:160].rstrip() + "..." if len(thong_tin) > 160 else thong_tin or None

            is_prot = bool(r.get("is_protected"))
            orig_lat = float(r.get("latitude"))
            orig_lng = float(r.get("longitude"))
            fuzz_radius = int(r.get("fuzzing_radius_meters") or 800)

            if is_prot:
                final_lat, final_lng = orig_lat, orig_lng
                is_exact = False
                dist = calculate_haversine(lat, lng, final_lat, final_lng)
            else:
                final_lat = orig_lat
                final_lng = orig_lng
                is_exact = False

            nearby_items.append(NearbyPlantItem(
                id=str(r.get("ten_label") or r.get("plant_id") or ""),
                location_id=r.get("location_id"),
                name=r.get("ten_cay") or "Cây thuốc",
                scientific_name=r.get("ten_quocte"),
                description=None if is_prot else short_desc,
                image_url=img_url,
                thumbnail_url=img_url,
                latitude=final_lat,
                longitude=final_lng,
                address_name=r.get("address_name"),
                source="system",
                distance_km=round(dist, 2),
                distance_display=format_distance(dist),
                is_protected=is_prot,
                protection_level=r.get("protection_level"),
                fuzzing_radius_meters=fuzz_radius if is_prot else None,
                conservation_notes="Cây quý hiếm cần bảo tồn. Chỉ công bố vùng phân bố khái quát; không cung cấp điểm cây hoặc hướng dẫn tìm kiếm." if is_prot else None,
                is_exact_location=is_exact,
            ))
    except Exception as exc:
        logger.error("[nearby] Lỗi truy vấn cây hệ thống: %s", exc)

    # ── 2. Cây cá nhân của user (MongoDB) ────────────────────────────────────
    if current_user is not None:
        raw_uid = current_user.get("_id")
        if raw_uid is not None:
            user_id_str = str(raw_uid)
            user_id_filters = [user_id_str]
            try:
                user_id_filters.append(ObjectId(user_id_str))
            except Exception:
                pass

            try:
                collection = get_user_plants_collection()
                cursor = collection.find(
                    {
                        "user_id": {"$in": user_id_filters},
                        "location.coordinates": {"$exists": True, "$type": "array"},
                    },
                    projection={
                        "_id": 1,
                        "plant_id": 1,
                        "name": 1,
                        "scientific_name": 1,
                        "image_url": 1,
                        "thumbnail_url": 1,
                        "notes": 1,
                        "location.coordinates": 1,
                    }
                ).limit(limit)

                docs = await cursor.to_list(length=limit)
                for doc in docs:
                    coords = doc.get("location", {}).get("coordinates")
                    if not isinstance(coords, list) or len(coords) < 2:
                        continue
                    u_lng = float(coords[0])
                    u_lat = float(coords[1])

                    dist = calculate_haversine(lat, lng, u_lat, u_lng)
                    if dist <= radius_km:
                        nearby_items.append(NearbyPlantItem(
                            id=str(doc.get("_id")),
                            location_id=None,
                            name=doc.get("name") or "Cây cá nhân",
                            scientific_name=doc.get("scientific_name"),
                            description=doc.get("notes"),
                            image_url=doc.get("image_url"),
                            thumbnail_url=doc.get("thumbnail_url"),
                            latitude=u_lat,
                            longitude=u_lng,
                            address_name="Vườn của tôi",
                            source="user",
                            distance_km=round(dist, 2),
                            distance_display=format_distance(dist),
                        ))
            except Exception as exc:
                logger.error("[nearby] Lỗi truy vấn cây cá nhân: %s", exc)

    # ── 3. Sắp xếp theo khoảng cách tăng dần (gần nhất lên đầu) ──────────────
    nearby_items.sort(key=lambda item: item.distance_km)

    return nearby_items[:limit]
