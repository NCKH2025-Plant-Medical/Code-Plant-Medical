import os
import cv2
import shutil
import numpy as np
import unicodedata

# Kỹ thuật bóc tách dấu tiếng Việt triệt để nhất bằng unicodedata
def chuan_hoa_ten_thu_muc(text):
    # Chuẩn hóa về dạng NFD (tách chữ và dấu riêng), sau đó loại bỏ các ký tự không phải ASCII
    text_ascii = unicodedata.normalize('NFD', text).encode('ascii', 'ignore').decode('utf-8')
    # Thay thế khoảng trắng và gạch ngang bằng gạch dưới
    return text_ascii.replace(" ", "_").replace("-", "_")

def resize_with_padding(image, target_size=(224, 224), padding_color=(0, 0, 0)):
    h, w = image.shape[:2]
    th, tw = target_size
    scale = min(tw / w, th / h)
    
    new_w = int(w * scale)
    new_h = int(h * scale)

    resized_image = cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_CUBIC)

    pad_top = (th - new_h) // 2
    pad_bottom = th - new_h - pad_top
    pad_left = (tw - new_w) // 2
    pad_right = tw - new_w - pad_left

    final_image = cv2.copyMakeBorder(resized_image, pad_top, pad_bottom, pad_left, pad_right, cv2.BORDER_CONSTANT, value=padding_color)
    return final_image

base_dir = os.path.dirname(os.path.abspath(__file__))

# Trỏ chính xác vào thư mục dataset và dataset_processed bên trong NCKH
input_folder = os.path.join(base_dir, "dataset")
output_folder = os.path.join(base_dir, "dataset_processed")
target_size = (224, 224) 

if os.path.exists(output_folder):
    shutil.rmtree(output_folder)
os.makedirs(output_folder, exist_ok=True)

print("Bắt đầu xử lý, tự động đổi tên và chống biến dạng ảnh...")
total_count = 0

for class_name in os.listdir(input_folder):
    class_path = os.path.join(input_folder, class_name)

    if os.path.isdir(class_path):
        # 1. Ép tên thư mục cây thành chuẩn ASCII an toàn tuyệt đối
        clean_class_name = chuan_hoa_ten_thu_muc(class_name)
        output_class = os.path.join(output_folder, clean_class_name)
        os.makedirs(output_class, exist_ok=True)
        
        print(f"Đang xử lý thư mục: {class_name} -> {clean_class_name}")

        img_counter = 1 # Bộ đếm để đặt tên file ảnh mới
        
        for filename in os.listdir(class_path):
            extension = os.path.splitext(filename)[1].lower()
            if extension in [".png", ".jpg", ".jpeg", ".bmp"]:
                input_path = os.path.join(class_path, filename)
                
                # 2. Đổi tên file ảnh thành số thứ tự: anh_0001.jpg, anh_0002.jpg...
                clean_filename = f"anh_{img_counter:04d}{extension}"
                output_path = os.path.join(output_class, clean_filename)

                # Dùng numpy đọc ảnh gốc (bất chấp tên tiếng Việt)
                try:
                    img_array = np.fromfile(input_path, np.uint8)
                    image = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
                except Exception as e:
                    print(f"  [Lỗi hệ thống] Không thể đọc: {input_path} - {e}")
                    continue
                
                if image is None:
                    print(f"  [Bỏ qua] File hỏng hoặc không phải ảnh: {input_path}")
                    continue

                # Resize giữ tỷ lệ khung hình
                final_resized = resize_with_padding(image, target_size)
                
                # Lưu file với tên mới thuần tiếng Anh
                cv2.imwrite(output_path, final_resized)
                
                img_counter += 1
                total_count += 1

print(f"\nHoàn tất tuyệt đối! Đã xử lý và lưu an toàn {total_count} ảnh vào '{output_folder}'")
