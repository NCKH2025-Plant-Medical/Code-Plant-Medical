import tensorflow as tf
import numpy as np
import json
import io
import uvicorn
from PIL import Image
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse

# ----------------------------------------------------
# A. Cấu hình & Tải Model và Database
# ----------------------------------------------------

# Kích thước ảnh phải khớp với lúc train (MobileNetV2)
IMAGE_SIZE = (224, 224)
MODEL_PATH = "Plane_model.keras" 
CLASS_NAMES_PATH = "class_names.json"
PLANT_INFO_PATH = "plant_info.json" # <--- PATH ĐẾN DB TĨNH

# Khởi tạo FastAPI
app = FastAPI()

# Biến toàn cục để lưu Model, Class Names và Database
MODEL = None
CLASS_NAMES = []
PLANT_INFO = {}

def load_ai_model():
    """Tải model, class names và thông tin cây khi server khởi động"""
    global MODEL, CLASS_NAMES, PLANT_INFO
    try:
        # 1. Tải Model
        MODEL = tf.keras.models.load_model(MODEL_PATH)
        
        # 2. Tải Class Names
        with open(CLASS_NAMES_PATH, "r", encoding="utf-8") as f:
            CLASS_NAMES = json.load(f)
            
        # 3. Tải Database thông tin chi tiết
        with open(PLANT_INFO_PATH, "r", encoding="utf-8") as f:
            PLANT_INFO = json.load(f)
            
        print(f"✅ Model, nhãn và thông tin {len(PLANT_INFO)} cây đã tải thành công.")
    except Exception as e:
        print(f"❌ LỖI KHỞI TẠO: Không thể tải các file cần thiết. {e}")
        MODEL = None
        
load_ai_model() # Tải model ngay lập tức

# ----------------------------------------------------
# B. Hàm Xử lý Ảnh
# ----------------------------------------------------

def transform_image(image_bytes):
    """Xử lý ảnh từ bytes thành tensor cho model"""
    try:
        image = Image.open(io.BytesIO(image_bytes))
        image = image.resize(IMAGE_SIZE)
        # Chuyển ảnh thành mảng và thêm chiều batch
        img_array = tf.keras.utils.img_to_array(image)
        img_array = tf.expand_dims(img_array, 0) 
        return img_array
    except Exception as e:
        return None

# ----------------------------------------------------
# C. API Endpoints
# ----------------------------------------------------

# Endpoint 1: Dự đoán cây từ ảnh (POST)
@app.post("/predict")
async def predict_api(file: UploadFile = File(...)):
    """Endpoint nhận ảnh và trả về dự đoán"""
    
    if MODEL is None:
        return JSONResponse(
            status_code=500, 
            content={"error": "AI Model chưa được tải. Vui lòng kiểm tra file model."}
        )
    
    img_bytes = await file.read()
    tensor = transform_image(img_bytes)
    
    if tensor is None:
         return JSONResponse(
             status_code=400, 
             content={"error": "Định dạng ảnh không hợp lệ (chỉ chấp nhận JPG/PNG)."}
         )

    # Dự đoán
    predictions = MODEL.predict(tensor)
    score = tf.nn.softmax(predictions[0])
    
    # Định dạng kết quả
    predicted_class_index = np.argmax(score)
    predicted_class = CLASS_NAMES[predicted_class_index]
    confidence = float(np.max(score))
    
    return {
        "prediction": predicted_class,
        "confidence": f"{confidence * 100:.2f}%",
        "status": "OK"
    }

# Endpoint 2: Tra cứu thông tin cây (GET)
@app.get("/info/{plant_name}")
async def get_plant_info(plant_name: str):
    """Endpoint tra cứu thông tin chi tiết của một cây"""
    
    # Kiểm tra xem tên cây có tồn tại trong database (PLANT_INFO) không
    if plant_name in PLANT_INFO:
        # Nếu có, trả về toàn bộ thông tin chi tiết của cây đó
        return PLANT_INFO[plant_name]
    else:
        # Nếu không tìm thấy, trả về lỗi 404
        return JSONResponse(
            status_code=404, 
            content={"error": f"Không tìm thấy thông tin cho cây '{plant_name}'."}
        )

# ----------------------------------------------------
# D. Chạy Server
# ----------------------------------------------------

# KHÔNG CẦN THÊM PHẦN if __name__ == "__main__": 
# CHỈ CẦN CHẠY LỆNH UVICORN TỪ TERMINAL