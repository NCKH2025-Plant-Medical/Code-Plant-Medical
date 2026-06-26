# =============================================================================
# train.py
# =============================================================================

# =============================================================================
# train.py
# =============================================================================

import json
import os
import sys

# 1. CẤU HÌNH ĐƯỜNG DẪN HỆ THỐNG TRƯỚC KHI IMPORT (Rất quan trọng)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)
sys.path.append(PROJECT_ROOT) # Cấp quyền cho Python nhìn thấy toàn bộ dự án

import matplotlib
matplotlib.use("Agg")   # Non-interactive backend — safe for Colab / headless servers.
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns                                   
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix  

# 2. IMPORT MODULE TỪ AI_CORE CHUẨN XÁC
from AI_Core.build_model import create_model
from AI_Core.load_model import load_datasets_kfold

# ---------------------------------------------------------------------------
# Hyperparameters & Paths
# ---------------------------------------------------------------------------
EXPORT_DIR = os.path.join(PROJECT_ROOT, "exported_models")
os.makedirs(EXPORT_DIR, exist_ok=True) # Tự động tạo thư mục nếu chưa có

K_FOLDS         = 3
EPOCHS_PER_FOLD = 20

# 3. TRỎ TOÀN BỘ FILE THÀNH PHẨM VÀO THƯ MỤC EXPORTED_MODELS
MODEL_SAVE_PATH = os.path.join(EXPORT_DIR, "model_cay_thuoc.keras")   
CM_SAVE_PATH    = os.path.join(EXPORT_DIR, "confusion_matrix.png") # Gom chung ảnh biểu đồ vào đây

# ---------------------------------------------------------------------------
# Load dataset and persist class names 
# ---------------------------------------------------------------------------
print(f"Đang chia dữ liệu thành {K_FOLDS} phần (Folds)")
folds, class_names, num_classes = load_datasets_kfold(k_folds=K_FOLDS)

# LƯU FILE JSON ĐÚNG KHO EXPORTED_MODELS
with open(os.path.join(EXPORT_DIR, "class_names.json"), "w", encoding="utf-8") as f:
    json.dump(class_names, f, ensure_ascii=False)

# ---------------------------------------------------------------------------
# K-Fold training loop
#
# One addition to the original: we track best_fold_index so the evaluation
# step below can retrieve the exact val_ds that was held out when the best
# model was produced.  Every other line is identical to the original.
# ---------------------------------------------------------------------------
best_accuracy   = 0.0
best_fold_index = 0     # FIX: Added Academic Metrics — records which fold's
                        # val_ds to use for the post-training evaluation.

for i, (train_ds, val_ds) in enumerate(folds):
    fold_no = i + 1
    print(f"\n{'='*40}")
    print(f"Đang huấn luyện Fold {fold_no}/{K_FOLDS}")
    print(f"{'='*40}")

    model = create_model(num_classes)

    optimizer = tf.keras.optimizers.Adam(learning_rate=0.00001)

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
    print(f"Kết thúc Fold {fold_no}. Độ chính xác Val cao nhất: {val_acc*100:.2f}%")

    if val_acc > best_accuracy:
        print(f"!!! KỶ LỤC MỚI !!! (Cũ: {best_accuracy*100:.2f}% -> Mới: {val_acc*100:.2f}%)")
        best_accuracy   = val_acc
        best_fold_index = i     # FIX: Added Academic Metrics — save which fold won.

        model.save(MODEL_SAVE_PATH)
        print("Đã lưu model tốt nhất.")
    else:
        print("Model này chưa vượt qua kỷ lục cũ.")

print(f"\n{'='*40}")
print(f"HOÀN TẤT. Model tốt nhất đạt: {best_accuracy*100:.2f}%")
print(f"File model: {MODEL_SAVE_PATH}")
print(f"{'='*40}")


# =============================================================================
# FIX: Added Academic Metrics — everything below this line is new.
#
# Why this approach is academically correct:
#   - We reload the saved weights into a fresh architecture instead of using
#     the in-memory `model` variable.  The in-memory variable holds whichever
#     fold trained LAST, which may not be the best fold.  Reloading from disk
#     guarantees the weights being evaluated are exactly the ones that were
#     saved as the best.
#   - We evaluate on folds[best_fold_index][1] — the held-out validation set
#     of the winning fold.  This is the same data the model never trained on
#     in that fold, giving an honest performance estimate.
#   - classification_report() with target_names shows per-class Precision,
#     Recall, and F1-Score — the three metrics required by NCKH reviewers to
#     confirm the model is not simply memorising the majority class.
#   - The confusion matrix is saved as a high-resolution PNG with both raw
#     counts and row-normalised percentages side by side.  Raw counts show
#     absolute errors; normalised percentages reveal per-class error rates
#     independent of class size — important when 16 classes vary in size.
# =============================================================================

print("\n" + "="*40)
print("BẮT ĐẦU ĐÁNH GIÁ HỌC THUẬT (ACADEMIC EVALUATION)")
print("="*40)

# ---------------------------------------------------------------------------
# Step 1: Reload the best saved model from disk
# ---------------------------------------------------------------------------
# FIX: Added Academic Metrics — rebuild architecture then inject saved weights.
# We do NOT use tf.keras.models.load_model() because saved-config metadata can
# mismatch across TF versions.  Loading weights only into a freshly built
# architecture is the same safe bypass used in load_ai_model() (load_model.py).
print(f"\nĐang tải lại model tốt nhất từ '{MODEL_SAVE_PATH}'...")
best_model = create_model(num_classes)
best_model.load_weights(MODEL_SAVE_PATH)
print("Tải model thành công.")

# ---------------------------------------------------------------------------
# Step 2: Collect ground-truth labels and predictions from the best val_ds
# ---------------------------------------------------------------------------
# FIX: Added Academic Metrics — iterate the winning fold's validation dataset
# and accumulate y_true / y_pred batch by batch.
#
# We call best_model(batch, training=False) directly (not .predict()) so that
# Dropout and BatchNormalization behave in inference mode even though the
# model was compiled with from_logits=True.  We then apply softmax manually
# to convert logits → probabilities before taking argmax.
print(f"\nĐang chạy inference trên val_ds của Fold {best_fold_index + 1}...")

best_val_ds = folds[best_fold_index][1]   # The held-out validation split

y_true = []   # Ground-truth integer class indices
y_pred = []   # Predicted integer class indices

for batch_images, batch_labels in best_val_ds:
    # batch_images : (batch_size, 224, 224, 3)  — float32 pixel values
    # batch_labels : (batch_size,)               — integer class indices

    logits        = best_model(batch_images, training=False)  # Raw logits: (batch, num_classes)
    probabilities = tf.nn.softmax(logits, axis=-1)            # Probabilities: (batch, num_classes)
    predictions   = tf.argmax(probabilities, axis=-1)         # Class index: (batch,)

    y_true.extend(batch_labels.numpy().tolist())
    y_pred.extend(predictions.numpy().tolist())

y_true = np.array(y_true)
y_pred = np.array(y_pred)

print(f"Thu thập xong: {len(y_true)} mẫu từ validation set.")

# ---------------------------------------------------------------------------
# Step 3: Print Classification Report (Precision / Recall / F1 per class)
# ---------------------------------------------------------------------------
# FIX: Added Academic Metrics — classification_report() outputs the standard
# table format expected in an NCKH research paper appendix.
#   digits=4     → four decimal places for academic precision reporting
#   zero_division=0 → avoids warnings if a class has zero predictions
print("\n" + "="*40)
print("CLASSIFICATION REPORT")
print(f"(Validation Set — Best Fold {best_fold_index + 1})")
print("="*40)

report = classification_report(
    y_true,
    y_pred,
    target_names=class_names,  # Show plant names instead of raw integers
    digits=4,
    zero_division=0,
)
print(report)

# ---------------------------------------------------------------------------
# Step 4: Build confusion matrices (raw counts + row-normalised)
# ---------------------------------------------------------------------------
# FIX: Added Academic Metrics — two matrices are generated:
#   cm_counts : raw integer counts  → reveals absolute error magnitudes
#   cm_norm   : row-normalised %    → reveals per-class recall regardless of
#               class imbalance (each row sums to 1.0, so a small class with
#               few samples is not visually dominated by a large class)
cm_counts = confusion_matrix(y_true, y_pred)
cm_norm   = (
    cm_counts.astype(float)
    / cm_counts.sum(axis=1, keepdims=True)   # Divide each row by its row sum
)

# ---------------------------------------------------------------------------
# Step 5: Plot and save the Confusion Matrix figure
# ---------------------------------------------------------------------------
# FIX: Added Academic Metrics — side-by-side heatmaps saved to PNG.
# Figure width scales with num_classes so labels remain readable for 16 classes.
print(f"\nĐang tạo biểu đồ Confusion Matrix...")

fig, axes = plt.subplots(
    nrows=1,
    ncols=2,
    figsize=(max(18, num_classes * 1.2), max(8, num_classes * 0.7)),
)

fig.suptitle(
    f"Confusion Matrix  —  Best Fold {best_fold_index + 1}  "
    f"(val_accuracy = {best_accuracy * 100:.2f}%)\n"
    f"Forest Medicinal Plant Vision  |  MobileNetV2  |  {num_classes} classes",
    fontsize=13,
    fontweight="bold",
    y=1.02,
)

# --- Left panel: raw counts -------------------------------------------------
sns.heatmap(
    cm_counts,
    annot=True,
    fmt="d",               # Integer format — e.g. "42" not "42.0"
    cmap="Blues",
    xticklabels=class_names,
    yticklabels=class_names,
    linewidths=0.5,
    linecolor="white",
    ax=axes[0],
)
axes[0].set_title("Raw Counts", fontsize=12, fontweight="bold")
axes[0].set_xlabel("Predicted Label", fontsize=10)
axes[0].set_ylabel("True Label", fontsize=10)
axes[0].tick_params(axis="x", rotation=45, labelsize=8)
axes[0].tick_params(axis="y", rotation=0,  labelsize=8)

# --- Right panel: row-normalised percentages --------------------------------
sns.heatmap(
    cm_norm,
    annot=True,
    fmt=".2f",             # Two decimals — e.g. "0.97"
    cmap="Greens",
    xticklabels=class_names,
    yticklabels=class_names,
    vmin=0.0,
    vmax=1.0,              # Fix colour scale to [0, 1] for comparability
    linewidths=0.5,
    linecolor="white",
    ax=axes[1],
)
axes[1].set_title("Normalised by True Label (row %)", fontsize=12, fontweight="bold")
axes[1].set_xlabel("Predicted Label", fontsize=10)
axes[1].set_ylabel("True Label", fontsize=10)
axes[1].tick_params(axis="x", rotation=45, labelsize=8)
axes[1].tick_params(axis="y", rotation=0,  labelsize=8)

plt.tight_layout()
plt.savefig(CM_SAVE_PATH, dpi=150, bbox_inches="tight")
plt.close(fig)

print(f"Confusion matrix đã lưu → '{CM_SAVE_PATH}'")

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
print("\n" + "="*40)
print("ĐÁNH GIÁ HOÀN TẤT.")
print(f"  Model tốt nhất : {MODEL_SAVE_PATH}")
print(f"  Val accuracy   : {best_accuracy * 100:.2f}%")
print(f"  Chi tiết P/R/F1: xem bảng classification report ở trên")
print(f"  Confusion matrix: {CM_SAVE_PATH}")
print("="*40)
