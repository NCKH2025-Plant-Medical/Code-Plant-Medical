import tensorflow as tf

print(f"Phiên bản TensorFlow hiện tại: {tf.__version__}")
print("Đang thử nạp bộ não AI...")

try:
    model = tf.keras.models.load_model("model_cay_thuoc.keras")
    print("✅ Nạp thành công! AI đã sẵn sàng!")
except Exception as e:
    print(f"❌ THỦ PHẠM ĐÂY RỒI: {e}")