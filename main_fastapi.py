import tensorflow as tf
import numpy as np
import json
import io
import uvicorn
from PIL import Image
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
import database  # Đảm bảo file database.py nằm cùng thư mục với file này

# ----------------------------------------------------
# A. Cấu hình & Tải Model
# ----------------------------------------------------

# Kích thước ảnh phải khớp với lúc train
IMAGE_SIZE = (224, 224)
MODEL_PATH = "Plane_model.keras" 
CLASS_NAMES_PATH = "class_names.json"

app = FastAPI()

# Biến toàn cục
MODEL = None
CLASS_NAMES = []

def load_ai_model():
    """Tải model và class names khi server khởi động"""
    global MODEL, CLASS_NAMES
    try:
        # 1. Tải Model
        MODEL = tf.keras.models.load_model(MODEL_PATH)
        print("✅ Đã tải Model thành công.")
        
        # 2. Tải Class Names
        with open(CLASS_NAMES_PATH, "r", encoding="utf-8") as f:
            CLASS_NAMES = json.load(f)
        print(f"✅ Đã tải danh sách nhãn: {CLASS_NAMES}")
            
    except Exception as e:
        print(f"❌ LỖI KHỞI TẠO: {e}")
        MODEL = None
        
load_ai_model() 

# ----------------------------------------------------
# B. Hàm Xử lý Ảnh
# ----------------------------------------------------

def transform_image(image_bytes):
    """
    Xử lý ảnh đầu vào. 
    LƯU Ý: Không chia cho 255 vì Model đã có lớp Rescaling bên trong.
    """
    try:
        image = Image.open(io.BytesIO(image_bytes))
        
        # 1. Bắt buộc chuyển sang RGB (tránh lỗi ảnh PNG trong suốt hoặc ảnh xám)
        if image.mode != "RGB":
            image = image.convert("RGB")
            
        # 2. Resize ảnh (Dùng LANCZOS để ảnh nét hơn, giữ chi tiết gân lá tốt hơn mặc định)
        image = image.resize(IMAGE_SIZE, resample=Image.LANCZOS)
        
        # 3. Chuyển thành mảng
        img_array = tf.keras.utils.img_to_array(image)
        
        # 4. Thêm chiều batch (Ví dụ: từ (224,224,3) -> (1,224,224,3))
        img_array = tf.expand_dims(img_array, 0) 
        
        return img_array
    except Exception as e:
        print(f"Lỗi xử lý ảnh: {e}")
        return None

# ----------------------------------------------------
# C. API Endpoints
# ----------------------------------------------------

@app.post("/predict")
async def predict_api(file: UploadFile = File(...)):
    """Endpoint nhận ảnh -> Dự đoán -> Lấy thông tin từ MySQL -> Trả về kết quả"""
    
    if MODEL is None:
        return JSONResponse(status_code=500, content={"error": "AI Model chưa sẵn sàng."})
    
    # 1. Đọc và xử lý ảnh
    img_bytes = await file.read()
    tensor = transform_image(img_bytes)
    
    if tensor is None:
         return JSONResponse(status_code=400, content={"error": "File ảnh lỗi."})

    # 2. Dự đoán bằng AI
    predictions = MODEL.predict(tensor)
    score = tf.nn.softmax(predictions[0])
    
    predicted_class_index = np.argmax(score)
    predicted_class = CLASS_NAMES[predicted_class_index] # Ví dụ: "Ngai_cuu"
    confidence = float(np.max(score))
    
    print(f"🔍 AI dự đoán: {predicted_class} ({confidence*100:.2f}%)")

    # 3. KẾT NỐI DATABASE ĐỂ LẤY THÔNG TIN
    # Gọi hàm từ file database.py
    plant_info = database.get_plant_info_by_label(predicted_class)

    # 4. Trả về kết quả (Gộp thông tin AI và thông tin Thuốc)
    response_data = {
        "prediction": predicted_class,
        "confidence": f"{confidence * 100:.2f}%",
        "plant_info": plant_info if plant_info else "Chưa có thông tin trong Database"
    }
    
    return response_data