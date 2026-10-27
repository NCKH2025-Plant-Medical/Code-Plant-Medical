import os

# 1. CẤU HÌNH ĐƯỜNG DẪN ĐỘNG TRỎ VỀ THƯ MỤC DATA
BASE_DIR = os.path.dirname(os.path.abspath(__file__)) # Đang ở trong scripts/
PROJECT_ROOT = os.path.dirname(BASE_DIR)              # Lùi ra thư mục gốc NCKH/

# Trỏ chính xác vào kho dữ liệu đã qua xử lý
# Trỏ vào đúng kho ảnh đã xử lý
folder = os.path.join(PROJECT_ROOT, "data", "dataset_processed")

print(f"Đang quét thư mục: {folder}")
print("Đang đếm số lượng ảnh trong mỗi lớp...")

for class_name in os.listdir(folder):
    class_path = os.path.join(folder, class_name)

    if os.path.isdir(class_path):
    
        image_count = 0
        
        for filename in os.listdir(class_path):
           
            if filename.lower().endswith((".png", ".jpg", ".jpeg")):
                image_count += 1
        
        print(f"Lớp '{class_name}' có: {image_count} ảnh")