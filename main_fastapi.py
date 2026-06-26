import os
import sys
import asyncio
from datetime import datetime
from contextlib import asynccontextmanager
from typing import List
import numpy as np
import tensorflow as tf
from pydantic import BaseModel
from fastapi import FastAPI, File, UploadFile, Query, Header, HTTPException
from fastapi.responses import JSONResponse


BASE_DIR = os.path.dirname(os.path.abspath(__file__)) 
PROJECT_ROOT = os.path.dirname(BASE_DIR)              
sys.path.append(PROJECT_ROOT)                        
from API import database
from AI_Core.load_model import load_ai_model, transform_image

MODEL = None
CLASS_NAMES = []

CONFIDENCE_THRESHOLD = 0.75
MAX_IMAGE_BYTES = 10 * 1024 * 1024 


ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/jpg", "image/png"}

@asynccontextmanager
async def lifespan(app: FastAPI):
    global MODEL, CLASS_NAMES
    print("Server starting — loading AI model...")
    MODEL, CLASS_NAMES = load_ai_model()

    if MODEL is None:
        print("CRITICAL: AI model failed to load. /predict will return 500.")
    yield

    print("Server shutting down — releasing model.")
    MODEL = None
    CLASS_NAMES = []

app = FastAPI(
    title="Forest Medicinal Plant Vision API",
    version="1.0.0",
    lifespan=lifespan,
)

@app.post("/predict")
async def predict_api(file: UploadFile = File(...)):

    if MODEL is None:
        return JSONResponse(
            status_code=500,
            content={"error": "AI model is not loaded. Check server startup logs."},
        )
    
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        return JSONResponse(
            status_code=400,
            content={
                "error": (
                    f"Invalid file type '{file.content_type}'. "
                    f"Only JPEG and PNG images are accepted. "
                    f"Please upload a photo of a plant leaf."
                ),
            },
        )

    if file.size > MAX_IMAGE_BYTES:
        await file.close() 
        return JSONResponse(
            status_code=413,
            content={
                "error": "Kích thước ảnh quá lớn. Vui lòng chụp hoặc tải ảnh dưới 10 MB."
            },
        )

    img_bytes = await file.read()

    tensor = transform_image(img_bytes)
    if tensor is None:    
        return JSONResponse(
            status_code=400,
            content={
                "error": (
                    "The uploaded file appears to be corrupt or unreadable. "
                    "Please try a different image."
                ),
            },
        )

    predictions = await asyncio.get_running_loop().run_in_executor(
        None, MODEL.predict, tensor
    )

    score               = tf.nn.softmax(predictions[0])
    predicted_class_idx = int(np.argmax(score))
    predicted_class     = CLASS_NAMES[predicted_class_idx]
    confidence          = float(np.max(score))

    print(f"Prediction: {predicted_class} ({confidence * 100:.2f}%)")

    if confidence < CONFIDENCE_THRESHOLD:
        return {
            "predicted_plant": "Không xác định",
            "confidence":      f"{confidence * 100:.2f}%",
            "plant_info":      (
                "Vui lòng chụp rõ lá cây, hoặc vật thể này "
                "không có trong hệ thống dữ liệu."
            ),
        }

    # --- 5. MySQL lookup (offloaded to thread pool — non-blocking) ---------
    # Chỗ 2: Truy vấn thông tin cây từ MySQL (Offloaded to thread pool)
    plant_info = await asyncio.get_running_loop().run_in_executor(
        None, database.get_plant_info_by_label, predicted_class
    )

    # --- 6. Return structured response -------------------------------------
    return {
        "predicted_plant": predicted_class,
        "confidence":      f"{confidence * 100:.2f}%",
        "plant_info":      plant_info,
    }


class ScanRecord(BaseModel):
    scan_uuid: str
    device_id: str
    plant_label: str
    confidence: float
    latitude: float
    longitude: float
    scanned_at: datetime

# Hàm xử lý Database thô (Đã bổ sung bộ lọc kiểm duyệt nhãn)
def process_batch_sync(payload: List[ScanRecord]):
    global CLASS_NAMES
    # Chuyển sang dạng set để tăng tốc độ tìm kiếm (độ phức tạp O(1))
    valid_labels = set(CLASS_NAMES)

    # 1. PHÂN LOẠI DỮ LIỆU: Lọc ra bản ghi nào hợp lệ, bản ghi nào là rác
    valid_records = [r for r in payload if r.plant_label in valid_labels]
    rejected_uuids = [r.scan_uuid for r in payload if r.plant_label not in valid_labels]

    # Nếu không có bản ghi nào hợp lệ thì dừng lại luôn, trả về kết quả
    if not valid_records:
        return [], rejected_uuids

    sql = """
        INSERT INTO scan_history 
            (scan_uuid, device_id, plant_label, confidence, latitude, longitude, scanned_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE scan_uuid = scan_uuid
    """
    
    # Gom dữ liệu từ các bản ghi HỢP LỆ để chèn vào MySQL
    # Gom dữ liệu từ các bản ghi HỢP LỆ để chèn vào MySQL
    # FIX: Bọc round(r.confidence, 4) để khớp hoàn toàn với kiểu DECIMAL(5,4) của MySQL
    values = [
        (
            r.scan_uuid, 
            r.device_id, 
            r.plant_label, 
            round(r.confidence, 4),  # <--- THÊM HÀM ROUND Ở ĐÂY
            r.latitude, 
            r.longitude, 
            r.scanned_at
        )
        for r in valid_records
    ]

    connection = database._DB_POOL.get_connection()
    try:
        cursor = connection.cursor()
        cursor.executemany(sql, values) 
        connection.commit()
        
        # Tất cả các mã UUID hợp lệ đã được lưu thành công
        accepted_uuids = [r.scan_uuid for r in valid_records]
        return accepted_uuids, rejected_uuids
        
    except Exception as e:
        print(f"Lỗi đồng bộ Batch: {e}")
        # Nếu sập hệ thống do lỗi database, coi như toàn bộ mảng valid bị từ chối lưu
        return [], [r.scan_uuid for r in payload]
    finally:
        if cursor: cursor.close()
        if connection: connection.close()

# API Tiếp nhận Đồng bộ (Đã tối ưu Async + Kiểm duyệt dữ liệu đầu vào)
@app.post("/api/v1/sync/scans")
async def sync_scans(payload: List[ScanRecord]):
    MAX_BATCH = 500
    
    if len(payload) > MAX_BATCH:
        raise HTTPException(
            status_code=413, 
            detail=f"Dữ liệu quá lớn. Vui lòng chia nhỏ mỗi lần gửi tối đa {MAX_BATCH} bản ghi."
        )

    if not payload:
        return {"accepted": [], "rejected": []}

    # Hứng 2 mảng trả về từ Thread Pool sau khi kiểm duyệt
    # Chỗ 3: Đẩy tác vụ lưu hàng loạt sang Thread Pool
    accepted_uuids, rejected_uuids = await asyncio.get_running_loop().run_in_executor(
        None, process_batch_sync, payload
    )
    
    # Trả về cả 2 danh sách. Team Mobile nhận được mảng rejected sẽ xóa bản ghi lỗi đó đi 
    # trong máy của họ để tránh việc app cứ cố gửi lại một bản ghi rác mãi mãi.
    return {"accepted": accepted_uuids, "rejected": rejected_uuids}

@app.get("/api/v1/plants/delta")
async def get_plant_delta(since: datetime | None = Query(default=None)):

    connection = database._DB_POOL.get_connection()
    try:
        cursor = connection.cursor(dictionary=True)
        
        if since is None:
            cursor.execute("SELECT * FROM plant_medical WHERE is_deleted = 0")
        else:
           cursor.execute(
            "SELECT * FROM plant_medical WHERE updated_at > %s",
            (since,)
        )
            
        rows = cursor.fetchall()
        server_time = datetime.utcnow()  

        return {
            "server_timestamp": server_time.isoformat(),
            "updated":  [r for r in rows if not r["is_deleted"]],
            "deleted_labels": [r["ten_label"] for r in rows if r["is_deleted"]],
        }
    except Exception as e:
        print(f"Lỗi truy xuất dữ liệu cây thuốc: {e}")
        return {"error": "Internal Server Error"}
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()


@app.post("/api/v1/admin/recluster")
async def recluster_scans(x_admin_key: str = Header(..., description="Mã bí mật của Admin")):

    ADMIN_SECRET = os.getenv("ADMIN_SECRET", "Nckh_Secret_Admin_Key_2026")
    
    # CHỐT CHẶN BẢO MẬT: Nếu điền sai mã, đuổi thẳng cổ ngay từ vòng gửi xe (HTTP 403 Forbidden)
    if x_admin_key != ADMIN_SECRET:
        raise HTTPException(
            status_code=403, 
            detail="Bạn không có quyền truy cập tính năng admin này."
        )

    connection = database._DB_POOL.get_connection()
    try:
        connection.start_transaction() 
        
        cursor = connection.cursor(dictionary=True)
        
        # 1. Tìm các điểm quét mới chưa được gom cụm
        cursor.execute("""
            SELECT sh.id, sh.plant_label, sh.latitude, sh.longitude, sh.scanned_at
            FROM scan_history sh
            LEFT JOIN scan_cluster_map scm ON sh.id = scm.scan_id
            WHERE scm.scan_id IS NULL
            ORDER BY sh.plant_label, sh.scanned_at
        """)
        unclustered = cursor.fetchall()
        
        clustered_count = 0
        for scan in unclustered:
            cursor.execute("""
                SELECT id, center_lat, center_lng, observation_count
                FROM plant_clusters
                WHERE plant_label = %s
                  -- Bộ lọc thô Bounding Box (Kích hoạt Index idx_label_location)
                  AND center_lat BETWEEN %s - 0.00045 AND %s + 0.00045
                  AND center_lng BETWEEN %s - 0.00065 AND %s + 0.00065
                  -- Bộ lọc tinh bằng công thức Haversine thực tế
                  AND (
                      6371000 * 2 * ASIN(SQRT(
                          POWER(SIN(RADIANS(%s - center_lat) / 2), 2) +
                          COS(RADIANS(center_lat)) * COS(RADIANS(%s)) *
                          POWER(SIN(RADIANS(%s - center_lng) / 2), 2)
                      ))
                  ) < 50
                LIMIT 1
                FOR UPDATE
            """, (
                scan["plant_label"],
                scan["latitude"], scan["latitude"], 
                scan["longitude"], scan["longitude"],
                scan["latitude"], scan["latitude"], scan["longitude"] 
            ))
            
            existing_cluster = cursor.fetchone()
            
            if existing_cluster:
                new_count = existing_cluster["observation_count"] + 1
                new_lat = (existing_cluster["center_lat"] * existing_cluster["observation_count"] + scan["latitude"]) / new_count
                new_lng = (existing_cluster["center_lng"] * existing_cluster["observation_count"] + scan["longitude"]) / new_count
                
                cursor.execute("""
                    UPDATE plant_clusters
                    SET center_lat = %s, center_lng = %s,
                        observation_count = %s, last_observed = %s
                    WHERE id = %s
                """, (new_lat, new_lng, new_count, scan["scanned_at"], existing_cluster["id"]))
                cluster_id = existing_cluster["id"]
            else:
                cursor.execute("""
                    INSERT INTO plant_clusters
                        (plant_label, center_lat, center_lng, observation_count, first_observed, last_observed)
                    VALUES (%s, %s, %s, 1, %s, %s)
                """, (scan["plant_label"], scan["latitude"], scan["longitude"], scan["scanned_at"], scan["scanned_at"]))
                cluster_id = cursor.lastrowid
            
            cursor.execute(
                "INSERT INTO scan_cluster_map (scan_id, cluster_id) VALUES (%s, %s)",
                (scan["id"], cluster_id)
            )
            clustered_count += 1
            
        # Xác nhận hoàn tất transaction và tự động mở khóa toàn bộ các dòng FOR UPDATE
        connection.commit()
        return {"message": f"Đã gom cụm thành công {clustered_count} điểm quét mới."}
        
    except Exception as e:
        # Nếu có bất kỳ lỗi gì xảy ra, hủy bỏ toàn bộ các lệnh vừa tính toán trong mẻ này để tránh rác DB
        if connection:
            connection.rollback()
        print(f"Lỗi gom cụm: {e}")
        return {"error": "Lỗi hệ thống khi gom cụm."}
    finally:
        if cursor: cursor.close()
        if connection: connection.close()
