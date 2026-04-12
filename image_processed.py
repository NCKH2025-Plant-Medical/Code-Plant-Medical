import os
import cv2
import shutil
import numpy as np
import unicodedata

# Vì có ảnh có tên tiếng việt nên hàm ni dùng để chuẩn hóa lại cái tên chứ tên tiếng việt nó không nhận
def rename_file(text):
    text_ascii = unicodedata.normalize('NFD', text).encode('ascii', 'ignore').decode('utf-8')
    # normalize ép các chuỗi dù được viết bằng kiểu gì cũng về 1 định dạng 1
    # NFD lệnh này thì dùng để tách hết mấy cái chữ ra thành từng mãnh luôn 
    
    # encode ép chuỗi unicode thành chuỗi byte cái so sánh với mã ascii mà cái mã ascii ni không có dấu
    # vì khi gặp dấu thì nó lỗi nên dùng tham số ignore để bỏ qua luôn

   # thì encode nó đổi qua kiểu byte nên t dùng decode để đổi qua lại thành tên bth để đọc
    return text_ascii.replace(" ", "_").replace("-", "_")
    # cái này thì trả về về cái biến trên nãy thôi với t replace mấy cái khoản trống với gạch ngang thành gạch dưới


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

    resized_image = cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_CUBIC)
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

base_dir = os.path.dirname(os.path.abspath(__file__))
# Hàm ni t muốn lấy cái đường dẫn chuẩn chỗ t muốn làm việc thôi do nó nhảy liên tục quá 





# Trỏ chính xác vào thư mục dataset và dataset_processed bên trong NCKH
input_folder = os.path.join(base_dir, "dataset")
output_folder = os.path.join(base_dir, "dataset_processed")
target_size = (224, 224) 

if os.path.exists(output_folder):
    shutil.rmtree(output_folder)
os.makedirs(output_folder, exist_ok=True)

print("Bắt đầu xử lý")
total_count = 0

for class_name in os.listdir(input_folder):
    class_path = os.path.join(input_folder, class_name)

    if os.path.isdir(class_path):
        
        clean_class_name = rename_file(class_name)
        output_class = os.path.join(output_folder, clean_class_name)
        os.makedirs(output_class, exist_ok=True)
        
        print(f"Xử lý file: {class_name} -> {clean_class_name}")

        img_counter = 1
        
        for filename in os.listdir(class_path):
            extension = os.path.splitext(filename)[1].lower()
            if extension in [".png", ".jpg", ".jpeg", ".bmp"]:
                input_path = os.path.join(class_path, filename)
                
            
                clean_filename = f"anh_{img_counter:04d}{extension}"
                output_path = os.path.join(output_class, clean_filename)

               
                try:
                    img_array = np.fromfile(input_path, np.uint8)
                    image = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
                except Exception as e:
                    print(f" Không thể đọc: {input_path} - {e}")
                    continue
                
                if image is None:
                    print(f" File hỏng hoặc không phải ảnh: {input_path}")
                    continue

                
                final_resized = resize_with_padding(image, target_size)
                
               
                cv2.imwrite(output_path, final_resized)
                
                img_counter += 1
                total_count += 1

print(f"\n Đã xử lý {total_count} ảnh vào '{output_folder}'")
