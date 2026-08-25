
import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.applications import MobileNetV2 
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input
# preprocess_input nó sẽ tự động ép giá trị bức ảnh về khoảng -1 và 1 của MobileNetV2

def create_model(num_classes):

    data_augmentation = tf.keras.Sequential([
        layers.RandomFlip("horizontal_and_vertical"),
        layers.RandomRotation(0.2), # Xoay nghiêng bức ảnh đi 20 %  
        layers.RandomZoom(0.2),# phóng to, thu nhỏ đi 20%
        layers.RandomContrast(0.2), # Thay đổi độ tương phan
    ]) 

    # Đoạn này là t khởi tạo model MobileNetV2
    base_model = MobileNetV2(
        input_shape=(224, 224, 3),
        include_top=False, # Phần top của CNN thì hay dùng để phân loại nên t tắt cái khả năng phân loại đi
        weights='imagenet' # Tải toàn bộ ma trận trọng số của model
    )
    
    base_model.trainable = True # Dùng hàm ni để t mỡ thằng model ra để mình tinh chỉnh lại thành của mình



    # Nói dễ hiểu thì kiểu 100 lớp đàu của CNN dùng để nhận diện cơ bản hơn mà cái model của thằng này nó vippro quá rồi nên t tắt bớt cho nhẹ máy
    for layer in base_model.layers[:100]: # Vòng lặp này là t dùng để đóng 100 cái layer đầu đi 
        layer.trainable = False


    # Vì cái mô hình MobileNetV2 nó có cái lớp BatchNormalization mà t tìm hiểu khi dùng lại thì nên tắt đi chứ không là bị loạn ảnh đầu vào
    for layer in base_model.layers:
        if isinstance(layer, layers.BatchNormalization):
            layer.trainable = False 

    inputs = tf.keras.Input(shape=(224, 224, 3)) # Nhận ảnh
    x = data_augmentation(inputs) # Bỏ vào cái augmentation
    x = tf.keras.applications.mobilenet_v2.preprocess_input(x) # Cho nó chuẩn hó lại thành từ - 1 đến 1 của MobileNetV2
    
    x = base_model(x, training=True) # Đưa vào mô hình gọi ở trên bật cái khả năng training của nó lên
    x = layers.GlobalAveragePooling2D()(x) # Cái ni khó hiểu lắm hiểu đơn giản nó ép bức ảnh thành khối 1D để làm vc hiểu là nó sẽ có mảng 1280 số
    x = layers.Dropout(0.2)(x) # Cái này t tắt random nơ ron não đi để nó không học vẹt
    outputs = layers.Dense(num_classes)(x) # Cái này thì lấy nét đặc trưng lấy từ ảnh rồi xét với số cây t có rồi đưa ra phán đoán

    model = models.Model(inputs, outputs) # Cái này thì đóng gói model lại thôi
    model.summary();
    
    return model
