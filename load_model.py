# File: load_model.py
import tensorflow as tf

def load_datasets_kfold(k_folds=5):
    dataset_path = "dataset_processed"
    img_size = (224, 224)  # <--- SỬA THÀNH 224, 224
    batch_size = 32
    seed = 42

    # ... (Phần còn lại giữ nguyên y hệt code cũ) ...
    full_dataset = tf.keras.utils.image_dataset_from_directory(
        dataset_path, validation_split=None, seed=seed,
        image_size=img_size, color_mode="rgb", label_mode="int",
        batch_size=batch_size, shuffle=True
    )
    # ... (Giữ nguyên phần logic chia K-Fold bên dưới) ...
    
    # Copy lại đoạn logic chia K-Fold từ tin nhắn trước của tôi vào đây
    # Nếu bạn cần tôi gửi lại full file load_model mới thì bảo tôi nhé.
    
    class_names = full_dataset.class_names
    num_classes = len(class_names)
    
    total_batches = tf.data.experimental.cardinality(full_dataset).numpy()
    val_size = total_batches // k_folds
    folds = []
    for i in range(k_folds):
        val_ds = full_dataset.skip(i * val_size).take(val_size)
        part1 = full_dataset.take(i * val_size)
        part2 = full_dataset.skip((i + 1) * val_size)
        train_ds = part1.concatenate(part2)
        
        autotune = tf.data.AUTOTUNE
        train_ds = train_ds.prefetch(buffer_size=autotune)
        val_ds = val_ds.prefetch(buffer_size=autotune)
        folds.append((train_ds, val_ds))

    return folds, class_names, num_classes