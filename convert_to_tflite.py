# =============================================================================
# convert_to_tflite.py
#
# Run this script on the same machine (or Colab session) where
# `model_cay_thuoc.keras` and `class_names.json` are stored.
#
# Output files produced:
#   model_cay_thuoc.tflite   → hand to Flutter team for assets/
#   labels.txt               → hand to Flutter team for assets/
# =============================================================================

import json
import os
import sys
import numpy as np
import tensorflow as tf

# 1. CẤU HÌNH ĐƯỜNG DẪN HỆ THỐNG TRƯỚC KHI IMPORT
BASE_DIR = os.path.dirname(os.path.abspath(__file__)) # Thư mục hiện tại là scripts/
PROJECT_ROOT = os.path.dirname(BASE_DIR)              # Lùi 1 bước ra thư mục gốc NCKH
sys.path.append(PROJECT_ROOT)                         # Cấp quyền cho Python nhìn thấy toàn bộ dự án

# 2. IMPORT MODULE TỪ AI_CORE CHUẨN XÁC
from AI_Core.build_model import create_model

# ---------------------------------------------------------------------------
# 3. TRỎ TOÀN BỘ ĐƯỜNG DẪN VÀO KHO EXPORTED_MODELS
# ---------------------------------------------------------------------------
EXPORT_DIR       = os.path.join(PROJECT_ROOT, "exported_models")
KERAS_WEIGHTS    = os.path.join(EXPORT_DIR, "model_cay_thuoc.keras")
CLASS_NAMES_PATH = os.path.join(EXPORT_DIR, "class_names.json")
TFLITE_OUT       = os.path.join(EXPORT_DIR, "model_cay_thuoc.tflite")
LABELS_OUT       = os.path.join(EXPORT_DIR, "labels.txt")

# ---------------------------------------------------------------------------
# Step 1 — Load class names
# ---------------------------------------------------------------------------
print("="*55)
print("BƯỚC 1: Đọc danh sách nhãn cây...")
print("="*55)

with open(CLASS_NAMES_PATH, "r", encoding="utf-8") as f:
    class_names = json.load(f)

num_classes = len(class_names)
print(f"  Tìm thấy {num_classes} nhãn: {class_names}")


# ---------------------------------------------------------------------------
# Step 2 — Rebuild the training architecture and load saved weights
#
# We do NOT use tf.keras.models.load_model() directly because create_model()
# uses base_model(x, training=True) and augmentation layers that can cause
# config serialisation mismatches across TF versions.
# Loading weights only into a freshly built architecture avoids this entirely
# (the same bypass used in load_ai_model() in load_model.py).
# ---------------------------------------------------------------------------
print("\n" + "="*55)
print("BƯỚC 2: Tải lại kiến trúc và trọng số model...")
print("="*55)

training_model = create_model(num_classes)
training_model.load_weights(KERAS_WEIGHTS)
print("  Tải model thành công.")


# ---------------------------------------------------------------------------
# Step 3 — Build a clean INFERENCE-ONLY model for export
#
# The training model contains:
#   a) Data augmentation layers (RandomFlip, RandomRotation, etc.) — these
#      must be EXCLUDED from the TFLite export.  They are stochastic
#      operations that make no sense at inference time and would produce
#      different results on every call.
#   b) base_model called with training=True — TFLite requires a fully
#      static, deterministic graph.  We need training=False behaviour.
#
# Solution: build a new model that takes the same (224, 224, 3) input but
# skips augmentation and calls every layer with training=False, then copies
# all weights from the trained model layer by layer.
#
# The inference graph is:
#   Input (224,224,3)
#     → mobilenet_v2.preprocess_input   (scales pixels to [-1, 1])
#     → MobileNetV2 base (training=False, BN uses stored running stats)
#     → GlobalAveragePooling2D
#     → Dropout (training=False → identity, no random zeroing)
#     → Dense (num_classes logits)
#     → Softmax (added here so Flutter receives probabilities, not logits)
# ---------------------------------------------------------------------------
print("\n" + "="*55)
print("BƯỚC 3: Xây dựng inference model (không có augmentation)...")
print("="*55)

inputs = tf.keras.Input(shape=(224, 224, 3), name="input_image")

# Pixel normalisation to [-1, 1] — identical to training pipeline
x = tf.keras.applications.mobilenet_v2.preprocess_input(inputs)

# Reuse the MobileNetV2 base from the trained model (weights are already
# loaded into training_model — we extract the base by its layer name).
base_model = training_model.get_layer("mobilenetv2_1.00_224")
x = base_model(x, training=False)   # BN uses running mean/variance

# Reuse the trained head layers
x = training_model.get_layer("global_average_pooling2d")(x)
x = training_model.get_layer("dropout")(x, training=False)  # Acts as identity
logits = training_model.get_layer("dense")(x)

# Add Softmax here so the TFLite model outputs probabilities [0, 1].
# The training model deliberately used from_logits=True for numerical
# stability during training. At inference we want Flutter to receive
# ready-to-use confidence scores without calling softmax client-side.
outputs = tf.keras.layers.Softmax(name="output_probabilities")(logits)

inference_model = tf.keras.Model(inputs=inputs, outputs=outputs, name="inference_model")
print("  Inference model xây dựng thành công.")
print(f"  Input shape  : {inference_model.input_shape}")
print(f"  Output shape : {inference_model.output_shape}  ← {num_classes} xác suất")


# ---------------------------------------------------------------------------
# Step 4 — Convert to TFLite with DEFAULT optimisation (dynamic-range
#           post-training quantisation)
#
# tf.lite.Optimize.DEFAULT applies dynamic-range quantisation:
#   - Weights are quantised from float32 → int8  (stored on disk as int8)
#   - Activations are quantised dynamically at runtime
#   - No representative dataset is required (unlike full integer quantisation)
#
# Expected results for MobileNetV2:
#   Original .keras  : ~14 MB
#   After DEFAULT    :  ~4 MB   (≈ 3-4× size reduction)
#   Accuracy loss    :  < 1%    (acceptable for 16-class plant identification)
#
# If the Flutter team reports accuracy regression, upgrade to full integer
# quantisation (INT8) by providing a representative_dataset_gen — ask for
# the next step in the offline architecture series.
# ---------------------------------------------------------------------------
print("\n" + "="*55)
print("BƯỚC 4: Chuyển đổi sang TFLite + Quantization...")
print("="*55)

converter = tf.lite.TFLiteConverter.from_keras_model(inference_model)

# Apply dynamic-range post-training quantisation
converter.optimizations = [tf.lite.Optimize.DEFAULT]

tflite_model = converter.convert()
print("  Chuyển đổi thành công.")


# ---------------------------------------------------------------------------
# Step 5 — Save the .tflite file
# ---------------------------------------------------------------------------
print("\n" + "="*55)
print("BƯỚC 5: Lưu file .tflite...")
print("="*55)

with open(TFLITE_OUT, "wb") as f:
    f.write(tflite_model)

size_mb = os.path.getsize(TFLITE_OUT) / (1024 * 1024)
print(f"  Đã lưu: {TFLITE_OUT}")
print(f"  Kích thước file: {size_mb:.2f} MB")


# ---------------------------------------------------------------------------
# Step 6 — Export labels.txt for the Flutter team
#
# Flutter's TFLite integration reads a plain-text labels file where each
# line index matches the class index output by the model.
# Line 0 → class index 0, Line 1 → class index 1, etc.
# ---------------------------------------------------------------------------
print("\n" + "="*55)
print("BƯỚC 6: Xuất file labels.txt...")
print("="*55)

with open(LABELS_OUT, "w", encoding="utf-8") as f:
    for label in class_names:
        f.write(label + "\n")

print(f"  Đã lưu: {LABELS_OUT}")
for idx, name in enumerate(class_names):
    print(f"    [{idx:02d}] {name}")


# ---------------------------------------------------------------------------
# Step 7 — Smoke test: run one blank inference through the TFLite model
#           to confirm the runtime loads it without errors before handover
# ---------------------------------------------------------------------------
print("\n" + "="*55)
print("BƯỚC 7: Smoke test — kiểm tra TFLite model...")
print("="*55)

interpreter = tf.lite.Interpreter(model_path=TFLITE_OUT)
interpreter.allocate_tensors()

input_details  = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# Feed a blank (zero) image — we only verify the model runs, not accuracy
dummy_input = np.zeros((1, 224, 224, 3), dtype=np.float32)
interpreter.set_tensor(input_details[0]["index"], dummy_input)
interpreter.invoke()

output = interpreter.get_tensor(output_details[0]["index"])  # (1, num_classes)
assert output.shape == (1, num_classes), (
    f"Output shape mismatch: expected (1, {num_classes}), got {output.shape}"
)
assert abs(output[0].sum() - 1.0) < 1e-3, (
    f"Output does not sum to 1.0 — Softmax layer may be missing."
)

print(f"  Input tensor  shape : {input_details[0]['shape']}")
print(f"  Output tensor shape : {output_details[0]['shape']}")
print(f"  Output sum          : {output[0].sum():.6f}  (expected ≈ 1.0)")
print("  Smoke test PASSED.")


# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
print("\n" + "="*55)
print("HOÀN TẤT. Bàn giao cho Flutter team:")
print(f"  1. {TFLITE_OUT}  ({size_mb:.2f} MB)")
print(f"  2. {LABELS_OUT}  ({num_classes} nhãn)")
print("="*55)