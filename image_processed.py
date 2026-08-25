import os
import cv2
import shutil
import numpy as np
import unicodedata
from tqdm import tqdm  # Thêm thanh tiến trình siêu xịn

# Vì có ảnh có tên tiếng việt nên hàm ni dùng để chuẩn hóa lại cái tên chứ tên tiếng việt nó không nhận
def rename_file(text):
    # Xử lý riêng chữ Đ/đ trước vì Unicode NFD không tách được ký tự này
    text = text.replace('đ', 'd').replace('Đ', 'D')
    
    # Ép về ASCII và loại bỏ dấu tiếng Việt
    text_ascii = unicodedata.normalize('NFD', text).encode('ascii', 'ignore').decode('utf-8')
    
    # Thay thế khoảng trắng và gạch ngang thành gạch dưới
    return text_ascii.replace(" ", "_").replace("-", "_")

# Hàm này dùng để không bị vấn đề méo ảnh khi resize ảnh ớ
def resize_with_padding(image, target_size=(224, 224), padding_color=(0, 0, 0)):

    h, w = image.shape[:2] # Lấy 2 chỉ số đầu tiên rồi gán cho biến h và w thôi vì ảnh có 3 kênh là h w với màu vd (800, 600, 3)

    th, tw = target_size  # T gán hai biến th với tw là 224 với 224

    scale = min(tw / w, th / h) # lấy cái tw chia cho w rồi cái kia cũng thế để tính được là t sẽ thu nhỏ bao nhiêu thì nó không vỡ
    # t chọn min giải thích lâu lắm nhma chọn min chứ chọn max bị lỗi vì cái này là t chia ra để tính cái % thu nhỏ mà

    # Nhân cả 2 chiều cho cái tỷ lệ scale là cảnh bị lún lại thôi chứ tỷ lệ khung hình vẫn y nguyên
    # bắt buộc phải gán kiểu int nghe chứ không có số thập phân không dùng đc
    new_w = int(w * scale) 
    new_h = int(h * scale)

    interp = cv2.INTER_AREA if scale < 1 else cv2.INTER_CUBIC # INTER_AREA bóp nhỏ ảnh sẽ giúp giữ được đường gân lá
    resized_image = cv2.resize(image, (new_w, new_h), interpolation=interp)
    # interpolation=cv2.INTER_CUBIC) cái này là thuật toán nội suy của thằng openCV
    # Hiểu đơn giản là cái thuật toán INTER_CUBIC là vipro nhất nên t chọn thôi, yên tâm t có tìm hiểu rồi thì cái này là hợp nhất r

    pad_top = (th - new_h) // 2 # lấy chiều cao targer - chiều cao mới sau khi * với % scale rồi chia 2
    # t chia 2 vì  t muốn cái lá phải nằm giữa thôi t đắp trên nữa dưới nữa

    pad_bottom = th - new_h - pad_top # mới nói ở trên tự hiểu đi

    pad_left = (tw - new_w) // 2 # tương tự trên luôn 
    pad_right = tw - new_w - pad_left # tương tự trên luôn 

    final_image = cv2.copyMakeBorder(resized_image, pad_top, pad_bottom, pad_left, pad_right, cv2.BORDER_CONSTANT, value=padding_color)
    # cv2.copyMakeBorder đóng khung hết tất cả lại lấy cái ảnh của resized_image rồi đóng khung lại nó có cấu trúc tren dưới phải trái ấy
    # cv2.BORDER_CONSTANT nếu có khoảng trống thì nó lắp lại bằng một màu trơn xong t dùng cái value = padding_color là tô màu đen lên

    return final_image


"""Nếu có viền đen như vậy thì lỡ model của mình học luôn cái viền đen đó rồi dẫn tới sai sót thì sao:
Thì model vẫn sẽ nhận thấy các viền đen đó nhưng không sao cả nhưng nó sẽ tự động bỏ chứ không coi đó là đặc trưng của cây thuốc.
LÍ DO 1: Mạng nơ-ron chập (CNN) học bằng cách dùng các bộ lọc (filters) để quét qua bức ảnh, nhằm tìm kiếm các đặc trưng như: đường gân lá, răng cưa ở mép lá, đốm màu, hoặc hình dáng cuống lá.
Khi các bộ lọc của AI quét qua vùng đen này, phép nhân ma trận đa phần sẽ trả về 0. AI sẽ nhanh chóng nhận ra đây là "vùng chết" (dead space) không chứa bất kỳ thông tin hữu ích nào để học.

LÍ DO 2: Viền đen sẽ gần như xuất hiện rãi rác ở khắp các label vì gần như ảnh nào cũng sẽ có, vì thế khi model
thống kê dư liệu nó sẽ tự hiểu rằng cái viền đen này không dùng làm gì, trọng số nơ ron sẽ tự động đánh rớt cái viền đen này
"""

base_dir = os.path.dirname(os.path.abspath(__file__)) # Đang ở trong scripts/
project_root = os.path.dirname(base_dir)              # Lùi ra thư mục gốc NCKH/

# Trỏ chính xác vào thư mục data (Đảm bảo bạn đã tạo thư mục data/raw_dataset và bỏ ảnh gốc vào đó)
input_folder = os.path.join(project_root, "data", "Dataset")
output_folder = os.path.join(project_root, "data", "dataset_processed")
target_size = (224, 224) 


if os.path.exists(output_folder):
    print(f"Đang xóa thư mục cũ: {output_folder}")
    shutil.rmtree(output_folder) # Xóa hoàn toàn file cũ

os.makedirs(output_folder, exist_ok=True)

print("\nBắt đầu xử lý dữ liệu...")
total_count = 0
failed_files = [] # Mảng lưu các file bị lỗi để tổng kết

for class_name in os.listdir(input_folder):
    class_path = os.path.join(input_folder, class_name)

    if os.path.isdir(class_path):
        clean_class_name = rename_file(class_name)
        output_class = os.path.join(output_folder, clean_class_name)
        os.makedirs(output_class, exist_ok=True)
        
        print(f"Xử lý: {class_name} -> {clean_class_name}")

        img_counter = 1
        
        # Lấy danh sách ảnh hợp lệ
        valid_extensions = [".png", ".jpg", ".jpeg", ".bmp"]
        image_files = [f for f in os.listdir(class_path) if os.path.splitext(f)[1].lower() in valid_extensions]
        
        # Dùng tqdm tại đây để hiện thanh tiến trình
        for filename in tqdm(image_files, desc="Processing", unit="img", leave=False):
            extension = os.path.splitext(filename)[1].lower()
            input_path = os.path.join(class_path, filename)
            
            clean_filename = f"anh_{img_counter:04d}{extension}"
            output_path = os.path.join(output_class, clean_filename)

            try:
                img_array = np.fromfile(input_path, np.uint8)
                image = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
            except Exception as e:
                failed_files.append(f"{input_path} (Lỗi đọc file: {e})")
                continue
            
            if image is None or image.shape[0] == 0 or image.shape[1] == 0:
                failed_files.append(f"{input_path} (File hỏng hoặc kích thước = 0)")
                continue

            final_resized = resize_with_padding(image, target_size)
            cv2.imwrite(output_path, final_resized)
            
            img_counter += 1
            total_count += 1

print("-" * 50)
print(f"Tổng kết: Đã xử lý {total_count} ảnh.")
print(f"Đầu ra: {output_folder}")

if failed_files:
    print(f"\nPhát hiện {len(failed_files)} file lỗi (đã bỏ qua):")
    for f in failed_files:
        print(f"   - {f}")
print("-" * 50)
