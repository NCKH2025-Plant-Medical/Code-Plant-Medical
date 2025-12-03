# File: image_processed.py
import os
import cv2
import shutil

input_folder = "dataset"
output_folder = "dataset_processed"

# Xóa thư mục output cũ đi để tạo mới cho sạch sẽ (tránh lẫn lộn ảnh cũ/mới)
if os.path.exists(output_folder):
    shutil.rmtree(output_folder)
os.makedirs(output_folder, exist_ok=True)

target_size = (224, 224) # <--- ĐÃ SỬA LÊN 224 CHO MOBILENETV2

print("Bắt đầu xử lý ảnh...")
count = 0

for class_name in os.listdir(input_folder):
    class_path = os.path.join(input_folder, class_name)

    if os.path.isdir(class_path):
        output_class = os.path.join(output_folder, class_name)
        os.makedirs(output_class, exist_ok=True)

        for filename in os.listdir(class_path):
            if filename.lower().endswith((".png", ".jpg", ".jpeg", ".bmp")):
                input_path = os.path.join(class_path, filename)
                output_path = os.path.join(output_class, filename)

                image = cv2.imread(input_path)
                
                if image is None:
                    print(f"Lỗi đọc ảnh: {input_path}")
                    continue

                # Resize ảnh
                resized = cv2.resize(image, target_size)
                cv2.imwrite(output_path, resized)
                count += 1

print(f"Hoàn tất! Đã xử lý và lưu {count} ảnh vào '{output_folder}'")