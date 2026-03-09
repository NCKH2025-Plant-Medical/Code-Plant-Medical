from fastapi import FastAPI, File, UploadFile, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import base64
from typing import Optional, List
import uuid
from pydantic import BaseModel

# Khởi tạo FastAPI
app = FastAPI(title="Image Upload API", version="1.0.0")

# Cấu hình CORS cho Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Trong production nên giới hạn domain cụ thể
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Khởi tạo Firebase
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase initialized successfully")
except Exception as e:
    print(f"⚠️ Firebase initialization error: {e}")
    db = None

# Models


class ImageResponse(BaseModel):
    id: str
    image_base64: str
    captured_at: str


class ImagesListResponse(BaseModel):
    total: int
    images: List[ImageResponse]


# Collection name
COLLECTION_NAME = "images"


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "message": "Image Upload API is running",
        "status": "active",
        "firebase_connected": db is not None
    }


@app.post("/api/upload-image")
async def upload_image(
    image: UploadFile = File(...),
    captured_at: Optional[str] = Form(None)
):
    """
    Upload ảnh từ Flutter, nén sang base64 và lưu vào Firestore

    Parameters:
    - image: File ảnh upload
    - captured_at: Thời gian chụp ảnh (ISO format), nếu không có sẽ dùng thời gian hiện tại
    """
    if db is None:
        raise HTTPException(status_code=500, detail="Firebase not initialized")

    try:
        # Đọc nội dung file
        image_content = await image.read()

        # Nén sang base64
        image_base64 = base64.b64encode(image_content).decode('utf-8')

        # Xử lý thời gian
        if captured_at:
            try:
                captured_time = captured_at.strftime("%Hh-%d-%m-%Y")
            except:
                captured_time = datetime.now().strftime("%Hh-%d-%m-%Y")
        else:
            captured_time = datetime.now().strftime("%Hh-%d-%m-%Y")

        # Tạo document ID
        doc_id = str(uuid.uuid4())

        # Dữ liệu lưu vào Firestore
        image_data = {
            "id": doc_id,
            "image_base64": image_base64,
            "captured_at": captured_time,
            "content_type": image.content_type,
        }

        # Lưu vào Firestore
        db.collection(COLLECTION_NAME).document(doc_id).set(image_data)

        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "Image uploaded successfully",
                "data": {
                    "id": doc_id,
                    "captured_at": captured_time,
                }
            }
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")


@app.get("/api/images", response_model=ImagesListResponse)
async def get_all_images(
    limit: Optional[int] = 100,
    order_by: Optional[str] = "uploaded_at"
):
    """
    Lấy danh sách tất cả ảnh từ Firestore

    Parameters:
    - limit: Giới hạn số ảnh trả về (default: 100)
    - order_by: Sắp xếp theo field (captured_at hoặc uploaded_at)
    """
    if db is None:
        raise HTTPException(status_code=500, detail="Firebase not initialized")

    try:
        # Query Firestore
        query = db.collection(COLLECTION_NAME)

        # Sắp xếp
        if order_by in ["captured_at"]:
            query = query.order_by(
                order_by, direction=firestore.Query.DESCENDING)

        # Giới hạn
        if limit:
            query = query.limit(limit)

        # Lấy dữ liệu
        docs = query.stream()

        images = []
        for doc in docs:
            data = doc.to_dict()
            images.append(ImageResponse(
                id=data.get("id", ""),
                image_base64=data.get("image_base64", ""),
                captured_at=data.get("captured_at", ""),
            ))

        return ImagesListResponse(
            total=len(images),
            images=images
        )

    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to retrieve images: {str(e)}")


@app.get("/api/images/{image_id}")
async def get_image_by_id(image_id: str):
    """
    Lấy một ảnh cụ thể theo ID
    """
    if db is None:
        raise HTTPException(status_code=500, detail="Firebase not initialized")

    try:
        doc = db.collection(COLLECTION_NAME).document(image_id).get()

        if not doc.exists:
            raise HTTPException(status_code=404, detail="Image not found")

        data = doc.to_dict()

        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "data": {
                    "id": data.get("id"),
                    "image_base64": data.get("image_base64"),
                    "captured_at": data.get("captured_at"),
                    "content_type": data.get("content_type"),
                }
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to retrieve image: {str(e)}")


@app.delete("/api/images/{image_id}")
async def delete_image(image_id: str):
    """
    Xóa một ảnh theo ID
    """
    if db is None:
        raise HTTPException(status_code=500, detail="Firebase not initialized")

    try:
        doc_ref = db.collection(COLLECTION_NAME).document(image_id)
        doc = doc_ref.get()

        if not doc.exists:
            raise HTTPException(status_code=404, detail="Image not found")

        doc_ref.delete()

        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "Image deleted successfully",
                "id": image_id
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to delete image: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
