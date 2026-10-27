# API/system_plants/router.py
#
# Endpoint: GET /api/v1/system-plants/map
# ─────────────────────────────────────────────────────────────────────────────
# Mục đích:
#   Trả về danh sách các cây hệ thống (dữ liệu dược liệu MySQL) nằm trong
#   bounding box do frontend gửi lên. Đây là dữ liệu PUBLIC — không cần auth.
#
# Yêu cầu:
#   • Query params: min_lat, max_lat, min_lng, max_lng (float)
#   • MySQL: SELECT từ bảng system_plant_locations JOIN plant_medical
#   • Giới hạn 500 records (chống tràn bộ nhớ)
#   • Không cần Authentication (cây hệ thống là dữ liệu công khai)
#
# Schema bảng system_plant_locations (MySQL):
#   CREATE TABLE system_plant_locations (
#       id          INT AUTO_INCREMENT PRIMARY KEY,
#       plant_id    INT NOT NULL,              ← FK tới plant_medical.ID
#       latitude    DECIMAL(10, 8) NOT NULL,
#       longitude   DECIMAL(11, 8) NOT NULL,
#       address_name VARCHAR(255),             ← Tên địa danh/vườn dược liệu
#       INDEX idx_lat_lng (latitude, longitude)
#   );
# ─────────────────────────────────────────────────────────────────────────────

import asyncio
import logging
from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel

try:
    import database
except ImportError:
    from API import database

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/system-plants", tags=["System Plants"])

# ── Giới hạn ─────────────────────────────────────────────────────────────────
_MAP_RESULT_LIMIT = 500   # Tối đa 500 điểm trên bản đồ / request


# ── Response schema ───────────────────────────────────────────────────────────

class SystemPlantMapItem(BaseModel):
    """
    Item cây hệ thống hiển thị trên bản đồ.
    Khớp với hợp đồng API trong map_api_contract.md để Flutter không cần sửa code.
    """
    id: str                          # ten_label (khóa định danh cây — dùng để gọi /plants/{id})
    location_id: Optional[int] = None # Khóa định danh tọa độ riêng biệt của từng cây
    name: str                        # ten_cay
    scientific_name: Optional[str] = None   # ten_quocte
    description: Optional[str] = None       # thong_tin (rút gọn 200 ký tự)
    image_url: Optional[str] = None         # URL ảnh đầy đủ
    latitude: float
    longitude: float
    address_name: Optional[str] = None      # Tên địa danh / vườn dược liệu


# ── Endpoint ──────────────────────────────────────────────────────────────────

@router.get(
    "/map",
    response_model=List[SystemPlantMapItem],
    summary="Lấy cây hệ thống trong khung bản đồ (Bounding Box)",
    description=(
        "Trả về tối đa 500 cây thuốc hệ thống (MySQL) nằm trong bounding box. "
        "Đây là dữ liệu **công khai**, không yêu cầu xác thực. "
        "Frontend phân biệt nguồn bằng `source='system'` và hiển thị marker biểu tượng Chiếc lá."
    ),
)
async def get_system_plants_map(
    min_lat: float = Query(..., description="Vĩ độ cực Nam của viewport (°)"),
    max_lat: float = Query(..., description="Vĩ độ cực Bắc của viewport (°)"),
    min_lng: float = Query(..., description="Kinh độ cực Tây của viewport (°)"),
    max_lng: float = Query(..., description="Kinh độ cực Đông của viewport (°)"),
) -> List[SystemPlantMapItem]:
    """
    GET /api/v1/system-plants/map

    Xử lý:
    1. Kiểm tra bounding box hợp lệ.
    2. Gọi database.get_system_plants_in_bounds() trong ThreadPoolExecutor.
    3. Trả về danh sách SystemPlantMapItem.

    Edge cases:
    - Bounding box ngược (min > max)  → 400 Bad Request
    - MySQL pool chưa khởi tạo        → 503 Service Unavailable
    - Vùng không có dữ liệu           → 200 với list rỗng (không phải lỗi)
    """
    # ── 1. Kiểm tra bounding box hợp lệ ──────────────────────────────────────
    if min_lat > max_lat:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="min_lat phải nhỏ hơn hoặc bằng max_lat.",
        )
    if min_lng > max_lng:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="min_lng phải nhỏ hơn hoặc bằng max_lng.",
        )
    if not (-90 <= min_lat <= 90 and -90 <= max_lat <= 90):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vĩ độ phải nằm trong khoảng [-90, 90].",
        )
    if not (-180 <= min_lng <= 180 and -180 <= max_lng <= 180):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Kinh độ phải nằm trong khoảng [-180, 180].",
        )

    # ── 2. Kiểm tra DB pool ───────────────────────────────────────────────────
    if database._DB_POOL is None:
        logger.error("[system_plants/map] MySQL pool chưa khởi tạo.")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Cơ sở dữ liệu hệ thống chưa sẵn sàng. Vui lòng thử lại sau.",
        )

    # ── 3. Query MySQL trong ThreadPool ──────────────────────────────────────
    try:
        rows = await asyncio.get_running_loop().run_in_executor(
            None,
            database.get_system_plants_in_bounds,
            min_lat, max_lat, min_lng, max_lng, _MAP_RESULT_LIMIT,
        )
    except Exception as exc:
        logger.error("[system_plants/map] MySQL query lỗi: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Lỗi truy vấn cơ sở dữ liệu. Vui lòng thử lại.",
        )

    # ── 4. Chuyển đổi rows → response ────────────────────────────────────────
    result: List[SystemPlantMapItem] = []
    image_base = "http://222.255.184.116"  # Đồng bộ với IMAGE_BASE_URL trong main_fastapi.py

    for row in rows:
        # Xây dựng image_url nếu có
        anh_minh_hoa = row.get("anh_minh_hoa")
        image_url = f"{image_base}/static/plants/{anh_minh_hoa}" if anh_minh_hoa else None

        # Rút gọn thong_tin để không trả về quá nhiều dữ liệu
        thong_tin = row.get("thong_tin") or ""
        short_desc = thong_tin[:200].rstrip() + "..." if len(thong_tin) > 200 else thong_tin or None

        result.append(SystemPlantMapItem(
            id=row["ten_label"],
            location_id=row.get("location_id"),
            name=row.get("ten_cay") or row["ten_label"],
            scientific_name=row.get("ten_quocte"),
            description=short_desc,
            image_url=image_url,
            latitude=float(row["latitude"]),
            longitude=float(row["longitude"]),
            address_name=row.get("address_name"),
        ))

    logger.info(
        "[system_plants/map] bbox=[%.4f,%.4f,%.4f,%.4f] → %d cây hệ thống",
        min_lat, max_lat, min_lng, max_lng, len(result),
    )

    return result
