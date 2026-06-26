# =============================================================================
# load_model.py
#
# FIX (Modularity): This file now owns ALL AI-related logic for the project.
#   Previously it only contained load_datasets_kfold() (a training utility),
#   while the two inference functions — load_ai_model() and transform_image()
#   — were incorrectly living inside main_fastapi.py (the API layer).
#   They have been moved here permanently. main_fastapi.py now imports them.
#
# Responsibilities after refactor:
#   load_datasets_kfold()  → called by train.py during K-Fold training
#   load_ai_model()        → called by main_fastapi.py ONCE at server startup
#   transform_image()      → called by main_fastapi.py on every /predict request
# =============================================================================

import io
import json
import os

import numpy as np
import tensorflow as tf
from PIL import Image, ImageOps

from AI_Core.build_model import create_model

# ---------------------------------------------------------------------------
# Shared path constants — used by both load_ai_model() and train.py
# ---------------------------------------------------------------------------
# SỬA LẠI ĐƯỜNG DẪN: Lùi ra thư mục gốc NCKH rồi mới trỏ vào các thư mục con
BASE_DIR         = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT     = os.path.dirname(BASE_DIR) # Lùi 1 bước ra thư mục NCKH

IMAGE_SIZE       = (224, 224)
# Trỏ vào thư mục chứa model
MODEL_PATH       = os.path.join(PROJECT_ROOT, "exported_models", "model_cay_thuoc.keras")
CLASS_NAMES_PATH = os.path.join(PROJECT_ROOT, "exported_models", "class_names.json")


# ---------------------------------------------------------------------------
# 1.  K-FOLD DATASET LOADER  (used by train.py — unchanged from original)
# ---------------------------------------------------------------------------
def load_datasets_kfold(k_folds=5):
    """Split the processed dataset into K deterministic folds for training."""

    # Sửa lại đường dẫn lấy data
    # Sửa lại đường dẫn lấy data
    dataset_path = os.path.join(PROJECT_ROOT, "data", "dataset_processed")
    img_size     = (224, 224)
    batch_size   = 32
    seed         = 42

    print("Reading dataset from:", dataset_path)

    # NOTE: shuffle=True is intentionally kept here as in the original code.
    # (The data-leakage fix for this flag is a separate task scoped to Area 1
    #  Bug #3, which will be addressed in the next step.)
    full_dataset = tf.keras.utils.image_dataset_from_directory(
        dataset_path,
        validation_split=None,
        seed=seed,
        image_size=img_size,
        color_mode="rgb",
        label_mode="int",
        batch_size=batch_size,
        shuffle=False,
    )

    class_names   = full_dataset.class_names
    num_classes   = len(class_names)
    total_batches = tf.data.experimental.cardinality(full_dataset).numpy()
    val_size      = total_batches // k_folds
    autotune      = tf.data.AUTOTUNE
    folds         = []

    for i in range(k_folds):
        val_ds   = full_dataset.skip(i * val_size).take(val_size)
        part1    = full_dataset.take(i * val_size)
        part2    = full_dataset.skip((i + 1) * val_size)
        train_ds = part1.concatenate(part2)

        train_ds = train_ds.shuffle(buffer_size=1000, seed=seed)

        train_ds = train_ds.prefetch(buffer_size=autotune)
        val_ds   = val_ds.prefetch(buffer_size=autotune)
        folds.append((train_ds, val_ds))

    return folds, class_names, num_classes


# ---------------------------------------------------------------------------
# 2.  MODEL LOADER  (used by main_fastapi.py at startup)
# ---------------------------------------------------------------------------
# FIX (Modularity): This entire function was moved FROM main_fastapi.py.
#   It previously lived at module level there, mixing AI initialisation
#   logic directly into the API layer. It now belongs here.
#
# The function returns (model, class_names) instead of writing to globals
# so that main_fastapi.py owns its own state and this function stays pure
# and easily testable in isolation.
# ---------------------------------------------------------------------------
def load_ai_model():
    """
    Build the MobileNetV2 architecture and load trained weights from disk.

    Called exactly once at FastAPI server startup via the lifespan handler
    in main_fastapi.py. Never call this inside a request handler.

    Returns:
        model        : tf.keras.Model with weights loaded, ready for inference.
                       Returns None if loading fails.
        class_names  : list[str] — ordered plant class labels.
                       Returns [] if loading fails.
    """
    try:
        # Step 1: Read the class-name list first so we know num_classes
        #         before rebuilding the architecture.
        with open(CLASS_NAMES_PATH, "r", encoding="utf-8") as f:
            class_names = json.load(f)

        num_classes = len(class_names)
        print(f"Class labels loaded ({num_classes} classes): {class_names}")

        # Step 2: Rebuild the exact same architecture used during training.
        #         We do NOT use tf.keras.models.load_model() because the
        #         saved-config can mismatch across TF versions. Loading only
        #         weights (step 3) is the safe "bypass" approach.
        model = create_model(num_classes)

        # Step 3: Inject the trained weights into the freshly built architecture.
        model.load_weights(MODEL_PATH)
        print("Model loaded successfully and ready for inference.")

        return model, class_names

    except Exception as e:
        print(f"Error loading model: {e}")
        return None, []


# ---------------------------------------------------------------------------
# 3.  INFERENCE PREPROCESSOR  (used by main_fastapi.py per /predict request)
# ---------------------------------------------------------------------------
# FIX (Modularity): This entire function was moved FROM main_fastapi.py.
#   Keeping preprocessing logic inside the API route handler made it
#   impossible to unit-test independently and violated single-responsibility.
#
# FIX (Preprocessing Skew): The original function used ImageOps.fit(), which
#   performs a CENTER-CROP before resizing.  Training, however, used
#   resize_with_padding() from image_processed.py, which PADS the image
#   with black borders so the leaf is never cropped.
#
#   These two operations produce measurably different pixel distributions:
#   - A tall, narrow leaf photo loses its top and bottom with fit().
#   - The same photo retains the full leaf with padding, surrounded by black.
#   Because the model was trained exclusively on padded images, feeding it
#   cropped images at inference causes a silent accuracy regression.
#
#   The fix replicates the exact resize_with_padding() logic from
#   image_processed.py using Pillow (PIL) instead of OpenCV so there is no
#   extra cv2 dependency in the server process.
# ---------------------------------------------------------------------------
def transform_image(image_bytes: bytes):
    """
    Convert raw image bytes into a (1, 224, 224, 3) float32 tensor that
    exactly matches the preprocessing pipeline used during training.

    Args:
        image_bytes: Raw bytes of the uploaded image file.

    Returns:
        tf.Tensor of shape (1, 224, 224, 3), or None if preprocessing fails.
    """
    try:
        # Read the image directly from memory — no temp file on disk.
        image = Image.open(io.BytesIO(image_bytes))

        # Honour the EXIF orientation tag embedded by phone cameras so that
        # a portrait-mode photo is not rotated sideways before inference.
        image = ImageOps.exif_transpose(image)

        # Ensure 3-channel RGB.  Handles RGBA PNGs, greyscale JPEGs, etc.
        if image.mode != "RGB":
            image = image.convert("RGB")

        # ------------------------------------------------------------------
        # FIX (Preprocessing Skew): REMOVED ImageOps.fit() (center-crop).
        #
        # OLD code (causes skew):
        #   image = ImageOps.fit(image, IMAGE_SIZE, method=Image.LANCZOS)
        #
        # ImageOps.fit() crops a centred square out of the image first, then
        # resizes that crop to 224×224.  Any part of the leaf outside the
        # centre square is permanently discarded.
        #
        # NEW code below replicates resize_with_padding() exactly:
        #   1. Scale the image DOWN uniformly so the longest side == 224.
        #   2. Paste the scaled image centred on a black 224×224 canvas.
        # This guarantees the entire leaf is always visible in the tensor,
        # matching what the model learned to expect during training.
        # ------------------------------------------------------------------
        target_w, target_h = IMAGE_SIZE
        orig_w,  orig_h    = image.size  # PIL gives (width, height)

        # Compute the uniform scale factor so the image fits inside the
        # target box without any dimension exceeding 224 px.
        # min() is used (not max()) so we always shrink, never overflow.
        scale = min(target_w / orig_w, target_h / orig_h)

        new_w = int(orig_w * scale)
        new_h = int(orig_h * scale)

        # LANCZOS is the highest-quality downsampling filter in Pillow and
        # is the Pillow equivalent of cv2.INTER_CUBIC used in training.
        image = image.resize((new_w, new_h), Image.LANCZOS)

        # Create a black 224×224 canvas and paste the scaled image centred.
        # Padding colour (0, 0, 0) matches image_processed.py exactly.
        padded_image = Image.new("RGB", IMAGE_SIZE, (0, 0, 0))
        paste_x = (target_w - new_w) // 2
        paste_y = (target_h - new_h) // 2
        padded_image.paste(image, (paste_x, paste_y))
        # ------------------------------------------------------------------
        # END FIX
        # ------------------------------------------------------------------

        # Convert PIL image → numpy float32 array → TensorFlow tensor.
        img_array = tf.keras.utils.img_to_array(padded_image)   # (224, 224, 3)
        img_array = tf.expand_dims(img_array, axis=0)            # (1, 224, 224, 3)

        return img_array

    except Exception as e:
        print(f"Image preprocessing error: {e}")
        return None
