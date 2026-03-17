import tensorflow as tf
import os

def load_datasets_kfold(k_folds=5): # chia dữ liệu thành 5 phần như nhau
    # Tự động lấy đường dẫn thư mục hiện tại đang chứa file load_model.py (tức là thư mục NCKH)
    base_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Tự động nối ghép để trỏ chính xác vào dataset_processed
    dataset_path = os.path.join(base_dir, "dataset_processed")
    
    img_size = (224, 224)  
    batch_size = 32 # 1 batch = 32 ảnh
    seed = 42

    # In ra thử để bạn kiểm tra xem nó trỏ đúng chưa (có thể xóa dòng này sau khi chạy OK)
    print("Đang đọc dữ liệu từ:", dataset_path)

    # Làm sạch và chuẩn bị nguyên liệu 
    full_dataset = tf.keras.utils.image_dataset_from_directory( # Hàm hỗ trợ đi vào thư mục, quét và gán nhãn chia vali, train, xáo trộn
        dataset_path, 
        validation_split=None, # Để None vì sẽ tự chia bằng tay chứ không cần Keras chi dùm (lấy được 100% dữ liệu gốc của full dataset)
        seed=seed, # Quy luật để sáo trộn 
        image_size=img_size, 
        color_mode="rgb", 
        label_mode="int", # Định nghĩa các thư mục thành từng số nguyên 
        batch_size=batch_size, 
        shuffle=True # Sáo trộn
    )
  
    
    class_names = full_dataset.class_names # Lấy tên các danh sách đã gắn và biến full_dataset
    num_classes = len(class_names) # num_classes = 3
    
    total_batches = tf.data.experimental.cardinality(full_dataset).numpy() #cardinality dùng để đếm xem trong full_dataset có bao nhiêu batch 
    val_size = total_batches // k_folds # Tính mỗi fold có bao nhiêu batchs
    folds = []

    for i in range(k_folds): # Chạy vòng lặp 5 lần

        val_ds = full_dataset.skip(i * val_size).take(val_size) # Chạy vòng lập lấy và bỏ 
        # Cho val là một đoạn patch

        part1 = full_dataset.take(i * val_size) 
        # Lấy khúc bỏ qua của val lúc đầu
        part2 = full_dataset.skip((i + 1) * val_size)
        # lấy khúc còn của val_ds chưa lấy
        train_ds = part1.concatenate(part2)
        # Kết hợp lại để thành tệp train_ds
        
        autotune = tf.data.AUTOTUNE # Hàm tự điều chỉnh cấu hình phần cứng để nạp ảnh nhanh nhất

        train_ds = train_ds.prefetch(buffer_size=autotune) # Hàm giúp máy có thể chuẩn bị trước
        val_ds = val_ds.prefetch(buffer_size=autotune)
        #Trong khi GPU đang bận "học" batch số 1, thì CPU đã âm thầm "đọc" sẵn batch số 2 từ ổ cứng và để vào bộ nhớ đệm (buffer).

        folds.append((train_ds, val_ds)) 

    return folds, class_names, num_classes
