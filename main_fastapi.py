import os
import sys
import asyncio
from contextlib import asynccontextmanager

import numpy as np
import tensorflow as tf
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse

# ---------------------------------------------------------------------------
# Path setup — lets us import the AI_Core package from the project root.
# ---------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)
sys.path.append(PROJECT_ROOT)

from AI_Core.load_model import load_ai_model, transform_image
from API import database

# ---------------------------------------------------------------------------
# Global model state — populated once at startup, never per-request.
# ---------------------------------------------------------------------------
MODEL = None
CLASS_NAMES = []

CONFIDENCE_THRESHOLD = 0.75
MAX_IMAGE_BYTES = 10 * 1024 * 1024  # 10 MB
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/jpg", "image/png"}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load the .keras model ONCE at startup and keep it in memory for the
    life of the process. This avoids the cost of reloading weights on every
    request."""
    global MODEL, CLASS_NAMES
    print("Server starting — loading AI model...")
    MODEL, CLASS_NAMES = load_ai_model()

    if MODEL is None:
        print("CRITICAL: AI model failed to load. /predict will return 500.")
    yield

    print("Server shutting down — releasing model.")
    MODEL = None
    CLASS_NAMES = []


app = FastAPI(
    title="Forest Medicinal Plant Vision API (Inference-only)",
    version="1.0.0",
    lifespan=lifespan,
)


@app.post("/predict")
async def predict_api(file: UploadFile = File(...)):
    """AI inference endpoint: takes an image, predicts the plant class, and
    enriches the result with its botanical profile from MySQL. No GPS
    tracking, scan history, or clustering logic — those are permanently
    removed."""

    if MODEL is None:
        return JSONResponse(
            status_code=500,
            content={"error": "AI model is not loaded. Check server startup logs."},
        )

    if file.content_type not in ALLOWED_CONTENT_TYPES:
        return JSONResponse(
            status_code=400,
            content={
                "error": (
                    f"Invalid file type '{file.content_type}'. "
                    f"Only JPEG and PNG images are accepted. "
                    f"Please upload a photo of a plant leaf."
                ),
            },
        )

    if file.size > MAX_IMAGE_BYTES:
        await file.close()
        return JSONResponse(
            status_code=413,
            content={
                "error": "Kích thước ảnh quá lớn. Vui lòng chụp hoặc tải ảnh dưới 10 MB."
            },
        )

    img_bytes = await file.read()

    tensor = transform_image(img_bytes)
    if tensor is None:
        return JSONResponse(
            status_code=400,
            content={
                "error": (
                    "The uploaded file appears to be corrupt or unreadable. "
                    "Please try a different image."
                ),
            },
        )

    # Inference is CPU/GPU-bound and blocking, so it's offloaded to a thread
    # pool to keep the event loop free for other requests.
    predictions = await asyncio.get_running_loop().run_in_executor(
        None, MODEL.predict, tensor
    )

    score = tf.nn.softmax(predictions[0])
    predicted_class_idx = int(np.argmax(score))
    predicted_class = CLASS_NAMES[predicted_class_idx]
    confidence = float(np.max(score))

    print(f"Prediction: {predicted_class} ({confidence * 100:.2f}%)")

    if confidence < CONFIDENCE_THRESHOLD:
        return {
            "predicted_plant": "Không xác định",
            "confidence": f"{confidence * 100:.2f}%",
            "plant_info": (
                "Vui lòng chụp rõ lá cây, hoặc vật thể này "
                "không có trong hệ thống dữ liệu."
            ),
        }

    # MySQL lookup for the plant's botanical profile — offloaded to a thread
    # pool since the mysql-connector driver call is blocking, not async.
    plant_info = await asyncio.get_running_loop().run_in_executor(
        None, database.get_plant_info_by_label, predicted_class
    )

    return {
        "predicted_plant": predicted_class,
        "confidence": f"{confidence * 100:.2f}%",
        "plant_info": plant_info,
    }
