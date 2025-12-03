import tensorflow as tf
import json
import numpy as np
import os
from load_model import load_datasets_kfold
from build_model import create_model

# 1. Cấu hình
K_FOLDS = 3             # <--- ĐÃ GIẢM XUỐNG 3
EPOCHS_PER_FOLD = 20    # Giữ số này thấp để train nhanh
best_accuracy = 0.0

# 2. Load dữ liệu dạng K-Fold
print(f"Đang chia dữ liệu thành {K_FOLDS} phần (Folds)...")
folds, class_names, num_classes = load_datasets_kfold(k_folds=K_FOLDS)

with open("class_names.json", "w", encoding="utf-8") as f:
    json.dump(class_names, f, ensure_ascii=False)

# 3. Bắt đầu vòng lặp huấn luyện
for i, (train_ds, val_ds) in enumerate(folds):
    fold_no = i + 1
    print(f"\n{'='*40}")
    print(f"Đang huấn luyện Fold {fold_no}/{K_FOLDS}")
    print(f"{'='*40}")

    model = create_model(num_classes)

    optimizer = tf.keras.optimizers.Adam(
        learning_rate=0.00001  # <--- GIẢM TỪ 0.0001 XUỐNG CÒN 0.00001
    ) 
    
    model.compile(
        optimizer=optimizer,
        loss=tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        metrics=['accuracy']
    )

    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS_PER_FOLD,
        verbose=1
    )

    val_acc = max(history.history['val_accuracy'])
    print(f"--> Kết thúc Fold {fold_no}. Độ chính xác Val cao nhất: {val_acc*100:.2f}%")

    if val_acc > best_accuracy:
        print(f"!!! KỶ LỤC MỚI !!! (Cũ: {best_accuracy*100:.2f}% -> Mới: {val_acc*100:.2f}%)")
        best_accuracy = val_acc
        # Lưu dạng .keras để tránh lỗi TrueDivide
        model.save("Plane_model.keras") 
        print("Đã lưu model tốt nhất.")
    else:
        print("Model này chưa vượt qua kỷ lục cũ.")

print(f"\n{'='*40}")
print(f"HOÀN TẤT. Model tốt nhất đạt: {best_accuracy*100:.2f}%")
print(f"File model: Plane_model.keras")