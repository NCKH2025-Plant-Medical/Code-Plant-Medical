import io
import json
import os
import numpy as np
import tensorflow as tf
from PIL import Image, ImageOps

from AI_Core.build_model import create_model

BASE_DIR         = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT     = os.path.dirname(BASE_DIR) 

IMAGE_SIZE       = (224, 224)
# Trỏ vào thư mục chứa model
MODEL_PATH       = os.path.join(PROJECT_ROOT, "exported_models", "model_cay_thuoc.keras")
CLASS_NAMES_PATH = os.path.join(PROJECT_ROOT, "exported_models", "class_names.json")

def load_datasets_kfold(k_folds=5):

    dataset_path = "/content/dataset_processed"
    img_size     = (224, 224)
    batch_size   = 32
    seed         = 42

    print("Reading dataset from:", dataset_path)

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
  

    class_names   = full_dataset.class_names # Lấy tên các danh sách đã gắn và biến full_dataset
    num_classes   = len(class_names) # num_classes = 3

    total_batches = tf.data.experimental.cardinality(full_dataset).numpy() #cardinality dùng để đếm xem trong full_dataset có bao nhiêu batch 
    val_size      = total_batches // k_folds # Tính mỗi fold có bao nhiêu batchs
    autotune      = tf.data.AUTOTUNE # Hàm tự điều chỉnh cấu hình phần cứng để nạp ảnh nhanh nhất
    folds         = []

    for i in range(k_folds):# Chạy vòng lặp 5 lần

        val_ds   = full_dataset.skip(i * val_size).take(val_size) # Chạy vòng lập lấy và bỏ 
        part1    = full_dataset.take(i * val_size)
        # Lấy khúc bỏ qua của val lúc đầu

        part2    = full_dataset.skip((i + 1) * val_size)
        # lấy khúc còn của val_ds chưa lấy

        train_ds = part1.concatenate(part2)
        # Kết hợp lại để thành tệp train_ds

        train_ds = train_ds.shuffle(buffer_size=1000, seed=seed)

        train_ds = train_ds.prefetch(buffer_size=autotune)
        val_ds   = val_ds.prefetch(buffer_size=autotune)
        #Trong khi GPU đang bận "học" batch số 1, thì CPU đã âm thầm "đọc" sẵn batch số 2 từ ổ cứng và để vào bộ nhớ đệm (buffer).
        
        folds.append((train_ds, val_ds))

    return folds, class_names, num_classes



def load_ai_model():
    try:
        with open(CLASS_NAMES_PATH, "r", encoding="utf-8") as f:
            class_names = json.load(f)

        num_classes = len(class_names)
        print(f"Class labels loaded ({num_classes} classes): {class_names}")

        model = create_model(num_classes)
        model.load_weights(MODEL_PATH)
        print("Model loaded successfully and ready for inference.")

        return model, class_names

    except Exception as e:
        print(f"Error loading model: {e}")
        return None, []


def transform_image(image_bytes: bytes):

    try:
        image = Image.open(io.BytesIO(image_bytes))

        image = ImageOps.exif_transpose(image)
        if image.mode != "RGB":
            image = image.convert("RGB")

        target_w, target_h = IMAGE_SIZE
        orig_w,  orig_h    = image.size  

        scale = min(target_w / orig_w, target_h / orig_h)

        new_w = int(orig_w * scale)
        new_h = int(orig_h * scale)

        image = image.resize((new_w, new_h), Image.LANCZOS)

        padded_image = Image.new("RGB", IMAGE_SIZE, (0, 0, 0))
        paste_x = (target_w - new_w) // 2
        paste_y = (target_h - new_h) // 2
        padded_image.paste(image, (paste_x, paste_y))

        img_array = tf.keras.utils.img_to_array(padded_image)   
        img_array = tf.expand_dims(img_array, axis=0)            

        return img_array

    except Exception as e:
        print(f"Image preprocessing error: {e}")
        return None


def get_top_predictions(logits, class_names: list[str], k: int = 3):
    """
    Given raw model output (logits) for ONE image, return the top-k
    (label, confidence) pairs sorted by confidence, descending.
    """
    scores = tf.nn.softmax(logits).numpy()
    top_indices = np.argsort(scores)[::-1][:k]
    return [(class_names[i], float(scores[i])) for i in top_indices]