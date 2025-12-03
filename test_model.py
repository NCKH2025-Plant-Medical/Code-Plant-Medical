import tensorflow as tf
import numpy as np
import json
import os
from tensorflow.keras.utils import load_img, img_to_array

# 1. Cấu hình
MODEL_PATH = "Plane_model.keras"  # <--- SỬA THÀNH .keras (KHỚP VỚI FILE TRAIN)
CLASS_NAMES_PATH = "class_names.json"
IMAGE_SIZE = (224, 224)

# 2. Load Model (Bây giờ load rất đơn giản, không cần custom_objects nữa)
print("Đang tải model...")
try:
    model = tf.keras.models.load_model(MODEL_PATH) # Không bị lỗi TrueDivide nữa
    with open(CLASS_NAMES_PATH, "r", encoding="utf-8") as f:
        class_names = json.load(f)
    print("Đã tải xong!")
except Exception as e:
    print(f"Lỗi: {e}")
    exit()

# ... (Phần hàm predict_image và vòng lặp while giữ nguyên) ...
# Nếu bạn cần tôi gửi full file test_model thì bảo tôi nhé.

def predict_image(image_path):
    """
    Hàm nhận vào đường dẫn ảnh và trả về tên cây + độ chính xác
    """
    if not os.path.exists(image_path):
        print(f"Không tìm thấy file ảnh: {image_path}")
        return

    # Load ảnh và resize về đúng kích thước (128, 128)
    img = load_img(image_path, target_size=IMAGE_SIZE)
    
    # Chuyển ảnh thành mảng numpy
    img_array = img_to_array(img)
    
    # Thêm 1 chiều vào đầu (batch_size) -> shape thành (1, 128, 128, 3)
    img_array = tf.expand_dims(img_array, 0)

    # Dự đoán
    predictions = model.predict(img_array)
    
    # Dùng Softmax để tính phần trăm độ tin cậy (vì model output là logits)
    score = tf.nn.softmax(predictions[0])

    # Lấy nhãn có điểm cao nhất
    predicted_class = class_names[np.argmax(score)]
    confidence = 100 * np.max(score)

    print("-" * 30)
    print(f"Ảnh: {image_path}")
    print(f"Dự đoán: {predicted_class}")
    print(f"Độ tin cậy: {confidence:.2f}%")
    print("-" * 30)

# --- PHẦN CHẠY THỬ (Đã sửa lỗi dấu ngoặc kép) ---
if __name__ == "__main__":
    while True:
        # .strip('"') sẽ giúp cắt bỏ dấu ngoặc kép nếu bạn lỡ copy vào
        path = input("Nhập đường dẫn ảnh để test (hoặc gõ 'q' để thoát): ").strip().strip('"')
        
        if path.lower() == 'q':
            break
            
        predict_image(path)