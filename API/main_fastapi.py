import os
import sys

# Đảm bảo in tiếng Việt trên console Windows không bị lỗi
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')
# ---------------------------------------------------------------------------
# Thiết lập đường dẫn — hỗ trợ import trên cả Local và Cloud Server
# ---------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)
for p in [PROJECT_ROOT, BASE_DIR, os.path.join(PROJECT_ROOT, "AI_Core"), os.path.join(PROJECT_ROOT, "API")]:
    if p not in sys.path:
        sys.path.insert(0, p)

import asyncio
from contextlib import asynccontextmanager
from typing import List, Optional
from pydantic import BaseModel
import numpy as np
import tensorflow as tf
from fastapi import FastAPI, File, UploadFile, HTTPException, Query
from fastapi.responses import JSONResponse

try:
    import database
except ImportError:
    from API import database

try:
    from AI_Core.load_model import load_ai_model, transform_image, get_top_predictions
except ImportError:
    from load_model import load_ai_model, transform_image, get_top_predictions

import firebase_admin
from firebase_admin import credentials as fb_credentials

# ---------------------------------------------------------------------------
# Trạng thái model toàn cục — chỉ khởi tạo một lần khi server bật, không tái tạo theo từng request.
# ---------------------------------------------------------------------------
MODEL = None
CLASS_NAMES = []
IMAGE_BASE_URL = "http://222.255.184.116"
TOP_K = 3

CONFIDENCE_THRESHOLD = 0.80  # Dưới 80% → trả về thông báo, không hiển thị kết quả
MAX_IMAGE_BYTES = 10 * 1024 * 1024  # Giới hạn kích thước ảnh: 10 MB
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/jpg", "image/png"}

# Giới hạn tham số search
SEARCH_MAX_KEYWORD_LEN = 100
SEARCH_DEFAULT_LIMIT   = 5
SEARCH_MAX_LIMIT       = 50
SUGGESTIONS_DEFAULT_LIMIT = 5
SUGGESTIONS_MAX_LIMIT     = 5


class PlantPrediction(BaseModel):
    plant_id: str
    # ^ Định danh nội bộ — frontend dùng để gọi GET /api/v1/plants/{plant_id} khi người dùng bấm vào thẻ cây.
    # Không hiển thị giá trị này trực tiếp lên giao diện.
    common_name: str
    scientific_name: Optional[str] = None  # Tên khoa học (ten_quocte)
    confidence: Optional[str] = None
    image_url: Optional[str] = None

class PredictResponse(BaseModel):
    status: str                      # "success" hoặc "unknown"
    predictions: List[PlantPrediction] = []
    message: Optional[str] = None

class PlantDetailResponse(BaseModel):
    common_name: str
    scientific_name: Optional[str] = None
    description: Optional[str] = None
    usage: Optional[str] = None
    how_to_use: Optional[str] = None
    precautions: Optional[str] = None
    image_url: Optional[str] = None


class SearchResponse(BaseModel):
    """Response của GET /api/v1/plants/search."""
    query: str
    total: int
    results: List[PlantPrediction] = []


class SuggestedTermItem(BaseModel):
    """Một cụm từ gợi ý trong GET /api/v1/plants/search-suggestions."""
    keyword: str

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Nạp model .keras MỘT LẦN khi server khởi động và giữ trong bộ nhớ
    suốt vòng đời tiến trình. Tránh tốn chi phí load lại trọng số mỗi request."""
    global MODEL, CLASS_NAMES

    # --- Firebase Admin SDK initialization ---
    # Guard ensures we don't re-initialize on hot-reload (uvicorn --reload).
    if not firebase_admin._apps:
        _fb_cred_path = os.path.join(BASE_DIR, "firebase-credentials.json")
        _fb_cred = fb_credentials.Certificate(_fb_cred_path)
        firebase_admin.initialize_app(_fb_cred)
        print("Firebase Admin SDK initialized.")

    print("Server đang khởi động — đang nạp model AI...")
    MODEL, CLASS_NAMES = load_ai_model()

    if MODEL is None:
        print("NGHIÊM TRỌNG: Model AI không thể nạp được. Endpoint /predict sẽ trả về lỗi 500.")
    yield

    print("Server đang tắt — giải phóng model khỏi bộ nhớ.")
    MODEL = None
    CLASS_NAMES = []


from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Forest Medicinal Plant Vision API (Inference-only)",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

try:
    from auth.router import router as auth_router
except ImportError:
    from API.auth.router import router as auth_router

try:
    from user_plants.router import router as user_plants_router
except ImportError:
    from API.user_plants.router import router as user_plants_router

try:
    from system_plants.router import router as system_plants_router
except ImportError:
    from API.system_plants.router import router as system_plants_router

app.include_router(auth_router)
app.include_router(user_plants_router)
app.include_router(system_plants_router)

def _build_image_url(anh_minh_hoa: Optional[str]) -> Optional[str]:
    """Ghép tên file ảnh thành URL đầy đủ."""
    if not anh_minh_hoa:
        return None
    return f"{IMAGE_BASE_URL}/static/plants/{anh_minh_hoa}"


def _clean_scientific_name(raw: Optional[str]) -> Optional[str]:
    """Bỏ tiền tố 'Tên khoa học: ' do DB lưu thừa, chỉ trả về tên Latin."""
    if not raw:
        return None
    return raw.removeprefix("Tên khoa học: ").strip()


@app.post("/predict", response_model=PredictResponse)
async def predict_api(file: UploadFile = File(...)):
    """Endpoint nhận diện cây thuốc: nhận ảnh, dự đoán loài cây và
    bổ sung thông tin y thực vật từ MySQL. Không có GPS,
    lịch sử quét hay phân cụm — đã loại bỏ vĩnh viễn."""


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

    # Inference tốn CPU/GPU và có tính blocking, nên được đẩy sang ThreadPool
    # để không làm nghẽn Event Loop của FastAPI khi xử lý các request đồng thời.
    predictions = await asyncio.get_running_loop().run_in_executor(
        None, MODEL.predict, tensor
    )

    top_matches = get_top_predictions(predictions[0], CLASS_NAMES, k=TOP_K)
    top1_label, top1_confidence = top_matches[0]

    print(f"Dự đoán hàng đầu: {top1_label} ({top1_confidence * 100:.2f}%)")

    if top1_confidence < CONFIDENCE_THRESHOLD:
        return PredictResponse(
            status="unknown",
            predictions=[],
            message=(
                "Vui lòng chụp rõ lá cây, hoặc vật thể này "
                "không có trong hệ thống dữ liệu."
            ),
        )

    labels_only = [label for label, _ in top_matches]
    plant_rows = await asyncio.get_running_loop().run_in_executor(
        None, database.get_top_matches, labels_only
    )

    predictions_list = []
    for label, confidence in top_matches:
        row = plant_rows.get(label)
        if row is None:
            print(f"[predict] CẢNH BÁO: Nhãn '{label}' được dự đoán nhưng không tồn tại trong cơ sở dữ liệu.")
            continue

        predictions_list.append(PlantPrediction(
            plant_id=label,
            common_name=row.get("ten_cay") or label,
            scientific_name=_clean_scientific_name(row.get("ten_quocte")),
            confidence=f"{confidence * 100:.2f}%",
            image_url=_build_image_url(row.get("anh_minh_hoa")),
        ))

    return PredictResponse(status="success", predictions=predictions_list)

# ---------------------------------------------------------------------------
# GET /api/v1/plants/search — Live Search (QUAN TRỌNG: khai báo TRƯỜC /{plant_id})
# ---------------------------------------------------------------------------
@app.get("/api/v1/plants/search", response_model=SearchResponse, tags=["Plants"])
async def search_plants_api(
    q: str = Query(..., min_length=1, max_length=SEARCH_MAX_KEYWORD_LEN,
                   description="Từ khoá tìm kiếm"),
    limit: int = Query(SEARCH_DEFAULT_LIMIT, ge=1, le=SEARCH_MAX_LIMIT,
                       description=f"Số kết quả tối đa (1–{SEARCH_MAX_LIMIT})"),
) -> SearchResponse:
    """Live Search — tìm kiếm cây thuốc theo từ khoá.
    Hỗ trợ tiếng Việt có dấu và không dấu."""
    q_stripped = q.strip()
    if not q_stripped:
        raise HTTPException(
            status_code=422,
            detail="Tham số 'q' không được chỉ chứa khoảng trắng.",
        )

    rows = await asyncio.get_running_loop().run_in_executor(
        None, database.search_plants, q_stripped, limit
    )

    results: List[PlantPrediction] = [
        PlantPrediction(
            plant_id=row["ten_label"],
            common_name=row.get("ten_cay") or row["ten_label"],
            scientific_name=_clean_scientific_name(row.get("ten_quocte")),
            confidence=None,
            image_url=_build_image_url(row.get("anh_minh_hoa")),
        )
        for row in rows
    ]

    return SearchResponse(query=q_stripped, total=len(results), results=results)


# ---------------------------------------------------------------------------
# GET /api/v1/plants/search-suggestions — Gợi ý cụm từ (QUAN TRỌNG: TRƯỜC /{plant_id})
# ---------------------------------------------------------------------------
@app.get(
    "/api/v1/plants/search-suggestions",
    response_model=List[SuggestedTermItem],
    tags=["Plants"],
    summary="Gợi ý cụm từ tìm kiếm / triệu chứng",
)
async def search_suggestions_api(
    q: str = Query(..., min_length=1, max_length=SEARCH_MAX_KEYWORD_LEN,
                   description="Từ khoá để gợi ý"),
    limit: int = Query(SUGGESTIONS_DEFAULT_LIMIT, ge=1, le=SUGGESTIONS_MAX_LIMIT,
                       description=f"Số gợi ý (1–{SUGGESTIONS_MAX_LIMIT})"),
) -> List[SuggestedTermItem]:
    """Gợi ý cụm từ / triệu chứng liên quan đến từ khoá người dùng đang gõ."""
    q_stripped = q.strip()
    if not q_stripped:
        return []

    rows = await asyncio.get_running_loop().run_in_executor(
        None, database.search_keywords, q_stripped, limit
    )

    return [SuggestedTermItem(keyword=row["keyword"]) for row in rows]


# ---------------------------------------------------------------------------
# GET /api/v1/plants/{plant_id} — Hồ sơ chi tiết một cây
# ---------------------------------------------------------------------------
@app.get("/api/v1/plants/{plant_id}", response_model=PlantDetailResponse)
async def get_plant_detail(plant_id: str):
    plant_info = await asyncio.get_running_loop().run_in_executor(
        None, database.get_plant_info_by_label, plant_id
    )

    if plant_info is None:
        raise HTTPException(
            status_code=404,
            detail=f"Không tìm thấy dữ liệu cho cây có ID '{plant_id}'.",
        )

    return PlantDetailResponse(
        common_name=plant_info.get("Tên cây") or plant_id,
        scientific_name=_clean_scientific_name(plant_info.get("Tên quốc tế")),
        description=plant_info.get("Thông tin"),
        usage=plant_info.get("Công dụng"),
        how_to_use=plant_info.get("Cách dùng"),
        precautions=plant_info.get("Lưu ý"),
        image_url=_build_image_url(plant_info.get("anh_minh_hoa")),
    )