# API/user_plants/router.py
#
# Các endpoint quản lý Cây Cá Nhân (user_plants):
#
# ── Bản đồ ──────────────────────────────────────────────────────────────────
#   GET  /api/v1/user-plants/map          → Cây trong Bounding Box (có GeoJSON)
#
# ── Lịch sử nhận diện ────────────────────────────────────────────────────────
#   POST   /api/v1/user-plants            → Lưu kết quả nhận diện + ảnh + tọa độ
#   GET    /api/v1/user-plants/history    → Danh sách lịch sử nhận diện
#   DELETE /api/v1/user-plants/{id}       → Xóa một bản ghi (kèm ảnh Cloudinary)
#
# Thiết kế bảo mật:
#   • user_id luôn trích từ Bearer JWT đã xác thực — KHÔNG nhận từ client.
#   • Mọi query MongoDB đều filter user_id trước địa lý.
#   • Tuyệt đối không để lộ dữ liệu cây của người dùng khác.
#
# Document schema (UserPlants collection):
#   {
#     "_id":            ObjectId,
#     "user_id":        str,            ← ObjectId của user (lưu dạng string)
#     "plant_id":       str,            ← ten_label trong MySQL (khớp cây hệ thống)
#     "name":           str,
#     "scientific_name":str | None,
#     "confidence":     str | None,     ← "94.20%"
#     "image_url":      str,            ← Cloudinary secure_url
#     "thumbnail_url":  str,            ← Cloudinary thumbnail URL (300x300)
#     "cloudinary_public_id": str,      ← Dùng để xóa ảnh khi người dùng xóa bản ghi
#     "location": {                     ← GeoJSON Point (nullable)
#       "type": "Point",
#       "coordinates": [lng, lat]       ← GeoJSON: [longitude, latitude]
#     },
#     "notes":          str | None,
#     "created_at":     datetime (UTC)
#   }
# ─────────────────────────────────────────────────────────────────────────────

import asyncio
import logging
from datetime import datetime, timezone
from typing import List, Optional

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from pymongo.errors import PyMongoError
from pydantic import BaseModel

from API.auth.utils import get_current_user
from API.user_plants.mongo import get_user_plants_collection
from API.user_plants.cloudinary_utils import upload_plant_image, delete_plant_image

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/user-plants", tags=["User Plants"])

# ── Giới hạn ─────────────────────────────────────────────────────────────────
_MAP_RESULT_LIMIT   = 500   # Tối đa 500 điểm trên bản đồ / request
_HISTORY_MAX_LIMIT  = 50    # Tối đa 50 bản ghi lịch sử / trang
_HISTORY_DEFAULT_LIMIT = 20
_ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
_MAX_IMAGE_BYTES     = 10 * 1024 * 1024  # 10 MB


# ── Response schemas ──────────────────────────────────────────────────────────

class UserPlantMapItem(BaseModel):
    """Item hiển thị trên bản đồ."""
    id: str
    name: str
    thumbnail_url: Optional[str] = None
    lat: float
    lng: float
    source: str = "mongodb"


class UserPlantHistoryItem(BaseModel):
    """Item trong danh sách lịch sử nhận diện."""
    id: str
    plant_id: Optional[str] = None
    name: str
    scientific_name: Optional[str] = None
    confidence: Optional[str] = None
    image_url: str
    thumbnail_url: Optional[str] = None
    has_location: bool            # True nếu có tọa độ GPS
    lat: Optional[float] = None
    lng: Optional[float] = None
    notes: Optional[str] = None
    created_at: str               # ISO 8601 string


class SavePlantResponse(BaseModel):
    """Response sau khi lưu thành công."""
    id: str
    name: str
    image_url: str
    thumbnail_url: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    created_at: str


class PaginatedHistoryResponse(BaseModel):
    """Response danh sách lịch sử có phân trang."""
    total: int
    page: int
    limit: int
    items: List[UserPlantHistoryItem]


# ═══════════════════════════════════════════════════════════════════════════════
# 1. GET /api/v1/user-plants/map
#    Lấy cây cá nhân trong Bounding Box để hiển thị trên bản đồ.
# ═══════════════════════════════════════════════════════════════════════════════

@router.get(
    "/map",
    response_model=List[UserPlantMapItem],
    summary="Lấy cây cá nhân trong khung bản đồ (Bounding Box)",
    description=(
        "Trả về tối đa 500 cây cá nhân của **chính user đang đăng nhập** "
        "nằm trong bounding box. Yêu cầu Bearer Token hợp lệ."
    ),
)
async def get_user_plants_map(
    min_lat: float = Query(..., description="Vĩ độ cực Nam của viewport (°)"),
    max_lat: float = Query(..., description="Vĩ độ cực Bắc của viewport (°)"),
    min_lng: float = Query(..., description="Kinh độ cực Tây của viewport (°)"),
    max_lng: float = Query(..., description="Kinh độ cực Đông của viewport (°)"),
    current_user: dict = Depends(get_current_user),
) -> List[UserPlantMapItem]:
    """
    GET /api/v1/user-plants/map

    Edge cases handled:
    - 401 Unauthorized : token hết hạn / không hợp lệ (do get_current_user)
    - 400 Bad Request  : query param sai định dạng (FastAPI tự parse float)
    - 500 Internal     : PyMongoError (timeout, network …)
    - Data hỏng        : document thiếu field coordinates → bị bỏ qua
    - Cross-data       : luôn filter user_id → không bao giờ lộ dữ liệu chéo
    """
    # ── 1. Trích user_id từ token đã xác thực ────────────────────────────────
    raw_uid = current_user.get("_id")
    if raw_uid is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Không thể xác định user từ token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id_str = str(raw_uid)
    user_id_filters = [user_id_str]
    try:
        user_id_filters.append(ObjectId(user_id_str))
    except (InvalidId, Exception):
        pass  # Nếu không convert được ObjectId thì chỉ dùng string

    # ── 2. Xây dựng Geo query $geoWithin + $geometry (Polygon) ───────────────
    bbox_polygon = {
        "type": "Polygon",
        "coordinates": [[
            [min_lng, min_lat],
            [max_lng, min_lat],
            [max_lng, max_lat],
            [min_lng, max_lat],
            [min_lng, min_lat],   # đóng vòng polygon
        ]]
    }

    mongo_filter = {
        # SECURITY: Filter user_id trước — hàng rào bảo mật chính
        "user_id": {"$in": user_id_filters},
        # GEO: Lọc theo vị trí trong bounding box
        "location": {
            "$geoWithin": {
                "$geometry": bbox_polygon
            }
        },
        # DATA QUALITY: Chỉ lấy document có field location hợp lệ
        "location.coordinates": {"$exists": True, "$type": "array"},
    }

    # ── 3. Query MongoDB ──────────────────────────────────────────────────────
    collection = get_user_plants_collection()

    try:
        cursor = collection.find(
            mongo_filter,
            projection={
                "_id": 1,
                "name": 1,
                "thumbnail_url": 1,
                "location.coordinates": 1,
            }
        ).limit(_MAP_RESULT_LIMIT)

        raw_docs = await cursor.to_list(length=_MAP_RESULT_LIMIT)

    except PyMongoError as exc:
        logger.error("[user_plants/map] PyMongoError: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Không thể kết nối cơ sở dữ liệu. Vui lòng thử lại sau.",
        )

    # ── 4. Chuyển đổi document → response ────────────────────────────────────
    result: List[UserPlantMapItem] = []

    for doc in raw_docs:
        try:
            coords = doc["location"]["coordinates"]
            if not isinstance(coords, list) or len(coords) < 2:
                continue
            lng_val = float(coords[0])
            lat_val = float(coords[1])
        except (KeyError, TypeError, ValueError, IndexError):
            logger.warning(
                "[user_plants/map] Bỏ qua doc %s — coordinates không hợp lệ",
                doc.get("_id"),
            )
            continue

        result.append(UserPlantMapItem(
            id=str(doc["_id"]),
            name=doc.get("name") or "Cây cá nhân",
            thumbnail_url=doc.get("thumbnail_url"),
            lat=lat_val,
            lng=lng_val,
            source="mongodb",
        ))

    logger.info(
        "[user_plants/map] user=%s bbox=[%.4f,%.4f,%.4f,%.4f] → %d cây",
        user_id_str, min_lat, max_lat, min_lng, max_lng, len(result),
    )

    return result


# ═══════════════════════════════════════════════════════════════════════════════
# 2. POST /api/v1/user-plants
#    Lưu kết quả nhận diện + ảnh (upload Cloudinary) + tọa độ GPS.
#    Người dùng bấm nút "Lưu vào Lịch sử & Bản đồ" trên ResultScreen.
# ═══════════════════════════════════════════════════════════════════════════════

@router.post(
    "",
    response_model=SavePlantResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Lưu cây vào Lịch sử & Bản đồ cá nhân",
    description=(
        "Nhận ảnh từ client, upload lên Cloudinary, "
        "lưu metadata + tọa độ GPS vào MongoDB. "
        "Chỉ lưu URL ảnh trong DB — file vật lý do Cloudinary quản lý."
    ),
)
async def save_user_plant(
    # ── File ảnh ──
    image: UploadFile = File(..., description="Ảnh cây (JPEG/PNG/WebP, tối đa 10 MB)"),
    # ── Thông tin cây (từ kết quả AI) ──
    name: str = Form(..., description="Tên cây đã xác nhận"),
    plant_id: Optional[str] = Form(None, description="Mã label cây (khớp MySQL)"),
    scientific_name: Optional[str] = Form(None, description="Tên khoa học"),
    confidence: Optional[str] = Form(None, description="Độ tin cậy AI (VD: '94.20%')"),
    # ── Tọa độ GPS (tùy chọn) ──
    latitude: Optional[float] = Form(None, description="Vĩ độ (nullable nếu GPS tắt)"),
    longitude: Optional[float] = Form(None, description="Kinh độ (nullable nếu GPS tắt)"),
    # ── Ghi chú cá nhân ──
    notes: Optional[str] = Form(None, description="Ghi chú của người dùng"),
    # ── Auth ──
    current_user: dict = Depends(get_current_user),
) -> SavePlantResponse:
    """
    POST /api/v1/user-plants

    Luồng xử lý:
    1. Xác thực Bearer JWT → trích user_id an toàn.
    2. Kiểm tra Content-Type và kích thước ảnh.
    3. Chạy upload Cloudinary trong ThreadPoolExecutor (không block Event Loop).
    4. Xây dựng document MongoDB với GeoJSON Point (nếu có tọa độ).
    5. Insert vào collection UserPlants.
    6. Trả về 201 Created với URL ảnh và metadata.

    Edge cases:
    - Ảnh sai loại      → 400 Bad Request
    - Ảnh quá lớn       → 400 Bad Request
    - Cloudinary lỗi    → 502 Bad Gateway
    - MongoDB lỗi       → 500 Internal Server Error
    - Không có GPS      → Lưu bình thường, không có location (sẽ không xuất hiện trên bản đồ)
    """
    # ── 1. Trích user_id từ JWT (KHÔNG bao giờ nhận từ client) ───────────────
    raw_uid = current_user.get("_id")
    if raw_uid is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Không thể xác định user từ token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user_id_str = str(raw_uid)

    # ── 2. Kiểm tra ảnh ──────────────────────────────────────────────────────
    if image.content_type not in _ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Loại file '{image.content_type}' không được hỗ trợ. "
                "Vui lòng gửi ảnh JPEG, PNG hoặc WebP."
            ),
        )

    image_bytes = await image.read()

    if len(image_bytes) > _MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ảnh quá lớn. Giới hạn tối đa {_MAX_IMAGE_BYTES // 1024 // 1024} MB.",
        )

    if len(image_bytes) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File ảnh rỗng. Vui lòng kiểm tra lại.",
        )

    # ── 3. Upload Cloudinary (chạy trong ThreadPool để không block Event Loop) ─
    try:
        cloudinary_result = await asyncio.get_running_loop().run_in_executor(
            None,
            lambda: upload_plant_image(
                file_bytes=image_bytes,
                user_id=user_id_str,
                filename=image.filename,
            )
        )
    except Exception as exc:
        logger.error("[user_plants/save] Cloudinary upload lỗi: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Không thể lưu ảnh lúc này. Vui lòng thử lại. ({exc})",
        )

    # ── 4. Xây dựng document MongoDB ─────────────────────────────────────────
    now_utc = datetime.now(tz=timezone.utc)

    document: dict = {
        "user_id": user_id_str,
        "plant_id": (plant_id or "").strip() or None,
        "name": name.strip(),
        "scientific_name": (scientific_name or "").strip() or None,
        "confidence": (confidence or "").strip() or None,
        "image_url": cloudinary_result["image_url"],
        "thumbnail_url": cloudinary_result["thumbnail_url"],
        "cloudinary_public_id": cloudinary_result["public_id"],
        "notes": (notes or "").strip() or None,
        "created_at": now_utc,
    }

    # Chỉ thêm GeoJSON location khi có cả latitude VÀ longitude hợp lệ
    if latitude is not None and longitude is not None:
        # Kiểm tra khoảng hợp lệ của tọa độ
        if -90 <= latitude <= 90 and -180 <= longitude <= 180:
            document["location"] = {
                "type": "Point",
                "coordinates": [longitude, latitude],  # GeoJSON: [lng, lat]
            }
        else:
            logger.warning(
                "[user_plants/save] Tọa độ không hợp lệ lat=%s lng=%s — bỏ qua",
                latitude, longitude,
            )

    # ── 5. Insert vào MongoDB ─────────────────────────────────────────────────
    collection = get_user_plants_collection()
    try:
        insert_result = await collection.insert_one(document)
    except PyMongoError as exc:
        logger.error("[user_plants/save] MongoDB insert lỗi: %s", exc)
        # Nếu MongoDB lỗi sau khi đã upload Cloudinary → cố gắng xóa ảnh đã upload
        # để tránh ảnh rác trên Cloudinary
        try:
            await asyncio.get_running_loop().run_in_executor(
                None,
                lambda: delete_plant_image(cloudinary_result["public_id"])
            )
        except Exception:
            pass
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Không thể lưu vào cơ sở dữ liệu. Vui lòng thử lại.",
        )

    # ── 6. Trả về response ────────────────────────────────────────────────────
    loc = document.get("location")
    has_location = loc is not None

    logger.info(
        "[user_plants/save] Đã lưu cây '%s' cho user %s (id=%s, has_location=%s)",
        name, user_id_str, insert_result.inserted_id, has_location,
    )

    return SavePlantResponse(
        id=str(insert_result.inserted_id),
        name=document["name"],
        image_url=document["image_url"],
        thumbnail_url=document["thumbnail_url"],
        lat=latitude if has_location else None,
        lng=longitude if has_location else None,
        created_at=now_utc.isoformat(),
    )


# ═══════════════════════════════════════════════════════════════════════════════
# 3. GET /api/v1/user-plants/history
#    Danh sách lịch sử nhận diện của người dùng hiện tại (có phân trang).
# ═══════════════════════════════════════════════════════════════════════════════

@router.get(
    "/history",
    response_model=PaginatedHistoryResponse,
    summary="Lịch sử nhận diện cây cá nhân",
    description="Trả về danh sách kết quả nhận diện đã lưu, sắp xếp mới nhất trước.",
)
async def get_user_plants_history(
    page: int = Query(1, ge=1, description="Trang (bắt đầu từ 1)"),
    limit: int = Query(
        _HISTORY_DEFAULT_LIMIT, ge=1, le=_HISTORY_MAX_LIMIT,
        description=f"Số bản ghi / trang (tối đa {_HISTORY_MAX_LIMIT})",
    ),
    current_user: dict = Depends(get_current_user),
) -> PaginatedHistoryResponse:
    """
    GET /api/v1/user-plants/history?page=1&limit=20

    Sắp xếp: created_at DESC (mới nhất trước).
    Mỗi item bao gồm URL ảnh (Cloudinary), thông tin cây và tọa độ GPS (nếu có).
    """
    raw_uid = current_user.get("_id")
    if raw_uid is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Không thể xác định user từ token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user_id_str = str(raw_uid)

    collection = get_user_plants_collection()
    skip = (page - 1) * limit

    try:
        # Đếm tổng (chạy song song với query)
        total, raw_docs = await asyncio.gather(
            collection.count_documents({"user_id": user_id_str}),
            collection.find(
                {"user_id": user_id_str},
                projection={
                    "_id": 1,
                    "plant_id": 1,
                    "name": 1,
                    "scientific_name": 1,
                    "confidence": 1,
                    "image_url": 1,
                    "thumbnail_url": 1,
                    "location": 1,
                    "notes": 1,
                    "created_at": 1,
                }
            )
            .sort("created_at", -1)
            .skip(skip)
            .limit(limit)
            .to_list(length=limit)
        )
    except PyMongoError as exc:
        logger.error("[user_plants/history] PyMongoError: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Không thể tải lịch sử. Vui lòng thử lại sau.",
        )

    items: List[UserPlantHistoryItem] = []
    for doc in raw_docs:
        loc = doc.get("location")
        has_location = False
        lat_val: Optional[float] = None
        lng_val: Optional[float] = None

        if loc and isinstance(loc.get("coordinates"), list):
            coords = loc["coordinates"]
            if len(coords) >= 2:
                try:
                    lng_val = float(coords[0])
                    lat_val = float(coords[1])
                    has_location = True
                except (TypeError, ValueError):
                    pass

        created_raw = doc.get("created_at")
        if isinstance(created_raw, datetime):
            created_str = created_raw.isoformat()
        else:
            created_str = str(created_raw) if created_raw else ""

        items.append(UserPlantHistoryItem(
            id=str(doc["_id"]),
            plant_id=doc.get("plant_id"),
            name=doc.get("name") or "Cây cá nhân",
            scientific_name=doc.get("scientific_name"),
            confidence=doc.get("confidence"),
            image_url=doc.get("image_url", ""),
            thumbnail_url=doc.get("thumbnail_url"),
            has_location=has_location,
            lat=lat_val,
            lng=lng_val,
            notes=doc.get("notes"),
            created_at=created_str,
        ))

    logger.info(
        "[user_plants/history] user=%s page=%d limit=%d → %d items / total=%d",
        user_id_str, page, limit, len(items), total,
    )

    return PaginatedHistoryResponse(
        total=total,
        page=page,
        limit=limit,
        items=items,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# 4. DELETE /api/v1/user-plants/{id}
#    Xóa một bản ghi lịch sử nhận diện (kèm ảnh trên Cloudinary).
# ═══════════════════════════════════════════════════════════════════════════════

@router.delete(
    "/{plant_record_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Xóa bản ghi lịch sử nhận diện",
    description=(
        "Xóa document khỏi MongoDB và xóa ảnh tương ứng khỏi Cloudinary. "
        "Chỉ chủ sở hữu mới được xóa (kiểm tra user_id)."
    ),
)
async def delete_user_plant(
    plant_record_id: str,
    current_user: dict = Depends(get_current_user),
) -> None:
    """
    DELETE /api/v1/user-plants/{plant_record_id}

    Luồng:
    1. Parse plant_record_id thành ObjectId (400 nếu sai định dạng).
    2. Tìm document trong MongoDB, kiểm tra user_id (403 nếu không phải chủ).
    3. Xóa document khỏi MongoDB.
    4. Xóa ảnh khỏi Cloudinary (best-effort: lỗi xóa ảnh không làm rollback DB).
    """
    raw_uid = current_user.get("_id")
    if raw_uid is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Không thể xác định user từ token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user_id_str = str(raw_uid)

    # ── Parse ObjectId ────────────────────────────────────────────────────────
    try:
        record_oid = ObjectId(plant_record_id)
    except (InvalidId, Exception):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"ID bản ghi không hợp lệ: '{plant_record_id}'.",
        )

    collection = get_user_plants_collection()

    # ── Tìm document để kiểm tra quyền sở hữu ────────────────────────────────
    try:
        doc = await collection.find_one(
            {"_id": record_oid},
            projection={"user_id": 1, "cloudinary_public_id": 1},
        )
    except PyMongoError as exc:
        logger.error("[user_plants/delete] MongoDB find lỗi: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Lỗi cơ sở dữ liệu. Vui lòng thử lại.",
        )

    if doc is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy bản ghi.",
        )

    # SECURITY: Kiểm tra quyền sở hữu
    if str(doc.get("user_id")) != user_id_str:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bạn không có quyền xóa bản ghi này.",
        )

    # ── Xóa khỏi MongoDB ─────────────────────────────────────────────────────
    try:
        await collection.delete_one({"_id": record_oid})
    except PyMongoError as exc:
        logger.error("[user_plants/delete] MongoDB delete lỗi: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Không thể xóa bản ghi. Vui lòng thử lại.",
        )

    # ── Xóa ảnh trên Cloudinary (best-effort) ────────────────────────────────
    public_id = doc.get("cloudinary_public_id")
    if public_id:
        try:
            await asyncio.get_running_loop().run_in_executor(
                None,
                lambda: delete_plant_image(public_id)
            )
        except Exception as exc:
            # Lỗi xóa Cloudinary KHÔNG làm rollback DB
            # → Log cảnh báo, admin có thể dọn dẹp sau
            logger.warning(
                "[user_plants/delete] Không thể xóa ảnh Cloudinary '%s': %s",
                public_id, exc,
            )

    logger.info(
        "[user_plants/delete] Đã xóa bản ghi %s của user %s",
        plant_record_id, user_id_str,
    )
    # 204 No Content — không trả về body
