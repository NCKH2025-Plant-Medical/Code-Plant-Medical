
import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.applications import MobileNetV2 
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input

def create_model(num_classes):
    # Định nghĩa Data Augmentation (Đưa vào trong hàm để tránh lỗi)
    data_augmentation = tf.keras.Sequential([
        layers.RandomFlip("horizontal_and_vertical"),
        layers.RandomRotation(0.2),
        layers.RandomZoom(0.2),
        layers.RandomContrast(0.2), 
    ]) 

    #  Tải mô hình MobileNetV2 (base_model)
    base_model = MobileNetV2(
        input_shape=(224, 224, 3),
        include_top=False,
        weights='imagenet'
    )
    
    # THIẾT LẬP FINE-TUNING: Mở khóa các lớp cuối
    base_model.trainable = True

    # Đóng băng 100 lớp đầu tiên (chỉ Fine-Tuning 35 lớp cuối)
    for layer in base_model.layers[:100]:
        layer.trainable = False
        
    # Giữ BatchNormalization luôn bị đóng băng (Best Practice)
    for layer in base_model.layers:
        if isinstance(layer, layers.BatchNormalization):
            layer.trainable = False

    # 3. Ghép nối và xây dựng mô hình
    inputs = tf.keras.Input(shape=(224, 224, 3))
    x = data_augmentation(inputs)
    x = tf.keras.applications.mobilenet_v2.preprocess_input(x)
    
    x = base_model(x, training=True) # training=True cho phép fine-tuning
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(num_classes)(x)

    model = models.Model(inputs, outputs)
    

    return model
