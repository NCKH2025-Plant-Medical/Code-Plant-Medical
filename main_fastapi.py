import tensorflow as tf 
# Tensorflow là bộ não chính cho việc nhận diện, hỗ trợ load và dự đoán

import numpy as np
#  Numpy Xử lý ảnh đầu vào thành mãng ma trận để đưa vào tensorflow

import json
# Vì mô hình trả về các con số, thư viện này giúp dịch con số thành tên cây thuốc 

import io # Thư viện xử lý luồng dữ liệu đầu vào/ra làm việc trực tiếp trên ram
# Bức ảnh khi chụp được truyền đi dưới dạng luồng byte, thay vì lưu bức ảnh xuống ổ cứng server 
# dùng thư viện io giữ trực tiếp trên ram, giúp api phản hồi nhanh hơn 

import uvicorn # Đây là web server (ASGI Server)
# Làm tất cả đều nhờ nó làm cầu nối để thực hiện

from PIL import Image # Thư viện xử lý ảnh 

from fastapi import FastAPI, File, UploadFile
# Dùng FastAPI để xây dựng các API endpoints (API Endpoints là các địa chỉ URL cụ thể định nghĩa trong hệ thống FastAPI)
# UploadFile hỗ trợ đọc file upload lên từ web hoặc hệ thống 

from fastapi.responses import JSONResponse # Đóng gói câu trả lời của server trả về cho người dùng dưới dạng chuẩn JSON
import database  # gọi file database.py 


IMAGE_SIZE = (224, 224)
MODEL_PATH = "Plane_model.keras" # Model được huẩn luyện xong
CLASS_NAMES_PATH = "class_names.json" 
    
app = FastAPI() # Khởi tạo API 
# Dùng để định nghĩa tất các đường dẫn API phía dưới

# Biến toàn cục
MODEL = None # Lưu trữ trọng số của AI sau khi đọc từ file.keras
CLASS_NAMES = []


# Sau khi chạy file build và train thì nó sẽ lưu tất cả kiến thức thành một dữ liệu tỉnh
# và dữ liệu tính đó là file Plane_model.keras được lưu ở ổ cứng nên khi gọi api cần load lại model
# Load model vào FastAPI
def load_ai_model():
    # Tải model và class names khi mở server
    global MODEL, CLASS_NAMES  #Gọi lại biến toàn cục (global là ghi đè lên biến toàn cục phía trên)
    try:
        #  Tải Model
        MODEL = tf.keras.models.load_model(MODEL_PATH) # Gọi model (Dựng lại mọi thứ trong model)
        # Dọc file keras để tạo lại toàn bộ kiến trúc mạng nơron, nạp trọng số đã train
        # Nói dễ hiểu là ta đang load cái mô hình đấy
        
        # Tải Class Names
        with open(CLASS_NAMES_PATH, "r", encoding="utf-8") as f:
            # Đọc file danh sách tên cây 
            CLASS_NAMES = json.load(f) # Lưu file class_names vào bộ nhớ

        print(f"Danh sach nhan: {CLASS_NAMES}")
            
    except Exception as e:
        print(f" Loi load model: {e}")
        MODEL = None
        
load_ai_model() # Ta để đây là khi vừa chạy server uvicorn thì nó gọi lại model luôn 


# Hàm Xử lý Ảnh đầu vào
def transform_image(image_bytes):
    # Xử lý ảnh đầu vào
    try:
        image = Image.open(io.BytesIO(image_bytes)) 
        # Dùng io đọc trực tiếp luồng byte của bức ảnh ngay trên bộ nhớ ram
        
        # Chuyển sang kênh màu vì mô hình của mình học bằng ảnh màu nên ảnh trắng đen thì chịu
        # Thật ra thì cũng không cần thiết lắm đâu nhưng mà bỏ vô cũng được
        if image.mode != "RGB":
            image = image.convert("RGB")
            
        # Resize ảnh Dùng LANCZOS là thuật toán nội suy để giữ ảnh nét, chi tiết sâu khi cắt
        image = image.resize(IMAGE_SIZE, resample=Image.LANCZOS) 
        
        #  Chuyển thành mảng vì nó không có nhìn được đâu nó chỉ hiểu các ma trận pixel thôi
        img_array = tf.keras.utils.img_to_array(image) # (224,224,3)
        
        # Thêm chiều batch (Ví dụ: từ (224,224,3) -> (1,224,224,3))
        img_array = tf.expand_dims(img_array, 0) 
        # Deep learning trong TensorFlow bắt buộc phải xử lý xong xong nhiều ảnh nên cần phải gán thêm patch cho nó
        
        return img_array
    except Exception as e:
        print(f"Loi xu ly anh: {e}")
        return None


# C. API Endpoints
@app.post("/predict")
# Khai báo API endpoints đường dẫn là /predict và bắt buộc sử dụng phương thức HTTP Post
# Dễ hiểu thì phương thức Post là gửi dữ liệu lên Server để xử lý hoặc lưu trữ gần như không giới hạn. Gửi được các file ảnh, âm thanh, tài liệu
# Còn một phương thức nữa là get nhưng nó không phù hợp cho việc truyền tải hình ảnh 

async def predict_api(file: UploadFile = File(...)):
# async def hàm này siêu ngon nói dễ hiểu thì giúp máy chủ hoạt động đa nhiệm thật ra cái mình đang làm đây cũng không cần lắm nhưng mà t thấy ngon nên bỏ vào thôi
# UploadFile đây là class đặc biệt của FastAPI chuyên dùng để hứng file người dùng gửi lên.
# File(...) cái này là dùng kiểu như bắt buộc phải gửi là file

    """Endpoint nhận ảnh -> Dự đoán -> Lấy thông tin từ MySQL -> Trả về kết quả"""
    # Mô tả (Description) cho cổng /predict
    # cái này t test thử cái công dụng của FAST API thôi đừng quan tâm nó như comment thôi
    
    if MODEL is None:
        return JSONResponse(status_code=500, content={"AI Model chua load"})
    # Hàm Kiểm tra lại MODEL load chưa 
    
   
    img_bytes = await file.read()
     # Đọc và xử lý ảnh
     # await giúp giải phóng luồng xử lý giúp máy chủ có thể tiếp tục làm việc trong khi vẫn đang xử lý ảnh


    tensor = transform_image(img_bytes) # Gọi lại hàm xử lý ảnh 
    
    if tensor is None:
         return JSONResponse(status_code=400, content={"File anh loi"})
    # Nếu xử lý ảnh không được bị none thì trả về 




    # Dự đoán bằng AI
    predictions = MODEL.predict(tensor)
    # MODEL.predict(tensor) nhát giải thích quá MODEL là cái bộ não model của mình đó, predict là hàm dự đoán ảnh của TensorFlow, tensor là cái ảnh đó

    score = tf.nn.softmax(predictions[0])
    # thì ảnh sẽ có cái như này (1,224,224,3) thì nó lấy cái batch ra 
    # Lúc này thu được một mảng 1 chiều chứa các điểm số thô của riêng bức ảnh duy nhất mà người dùng vừa gửi lên "
    # tf.nn.softmax hàm này dùng công thức để đưa lại thành số để thể hiện độ tự tin của model mà con người hiểu được
    # score sinh ra sẽ luôn luôn có độ dài chính xác là 3 phần tử (ví dụ: [0.1, 0.8, 0.1]).

    predicted_class_index = np.argmax(score)
    # score ở trên là một mảng chứa các xác suất phần trăm (ví dụ: [0.05, 0.10, 0.80, 0.05])
    # np.argmax() nó tìm ra vị trí (số thứ tự / index) của con số lớn nhất đó nằm ở đâu trong mảng

    predicted_class = CLASS_NAMES[predicted_class_index] 
    # Sau đó thì ánh xạ lại từ file class_names json lấy con số của biến trên tra cứu vào mãng thôi 

    confidence = float(np.max(score))
    # Cái này trả về mức độ tin tưởng thôi thì cũng dùng hàm max của numpy cái t lấy đối số cao nhất của thằng score đó rồi chuyển qua số %
    
    print(f" AI dự đoán: {predicted_class} ({confidence*100:.2f}%)") # Cái này t print trong terminal để check thôi 


    # KẾT NỐI DATABASE ĐỂ LẤY THÔNG TIN
    plant_info = database.get_plant_info_by_label(predicted_class)

    # 4. Trả về kết quả (Gộp thông tin AI và thông tin Thuốc)
    response_data = {
        "Tên cây dự đoán: ": predicted_class,
        "Độ tin cậy của hệ thống:": f"{confidence * 100:.2f}%",
        "Thông tin từ hệ thống về cây:": plant_info 
    }
    
    return response_data
