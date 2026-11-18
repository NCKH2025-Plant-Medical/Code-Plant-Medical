"""Consent gated bridge from a prediction to the admin review inbox."""

import base64
import binascii
import hashlib
import hmac
import json
import os
import time
from datetime import datetime, timezone
from uuid import uuid4

from bson.binary import Binary
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from pydantic import BaseModel

try:
    from shared_admin_mongo import get_shared_database
except ImportError:
    from API.shared_admin_mongo import get_shared_database


router = APIRouter(prefix="/api/v1/prediction-feedback", tags=["Feedback"])
CONSENT_VERSION = "review-image-v1"
MAX_REVIEW_IMAGE = 8 * 1024 * 1024


def _secret():
    value = os.getenv("REVIEW_TOKEN_SECRET", "")
    if len(value) < 32:
        raise RuntimeError("REVIEW_TOKEN_SECRET must contain at least 32 characters")
    return value.encode("utf-8")


def _sign(payload):
    raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    data = base64.urlsafe_b64encode(raw).rstrip(b"=")
    mac = hmac.new(_secret(), data, hashlib.sha256).hexdigest().encode("ascii")
    return (data + b"." + mac).decode("ascii")


def _verify(token, purpose):
    try:
        data, mac = token.encode("ascii").split(b".", 1)
        expected = hmac.new(_secret(), data, hashlib.sha256).hexdigest().encode("ascii")
        if not hmac.compare_digest(mac, expected):
            raise ValueError("signature")
        payload = json.loads(base64.urlsafe_b64decode(data + b"=" * (-len(data) % 4)))
        if payload.get("purpose") != purpose:
            raise ValueError("purpose")
        if purpose == "submit" and time.time() - payload["issued_at"] > 1800:
            raise ValueError("expired")
        return payload
    except (ValueError, KeyError, TypeError, UnicodeError, binascii.Error) as exc:
        raise HTTPException(status_code=400, detail="Mã xác nhận ảnh không hợp lệ hoặc đã hết hạn.") from exc


def prediction_tokens(image_bytes, top3, model_version):
    """No image or prediction metadata is persisted before consent."""
    prediction_id = uuid4().hex
    return prediction_id, _sign({
        "purpose": "submit",
        "prediction_id": prediction_id,
        "image_sha256": hashlib.sha256(image_bytes).hexdigest(),
        "predicted_top3": top3,
        "model_version": model_version,
        "issued_at": int(time.time()),
    })


@router.post("", status_code=202)
async def submit_feedback(
    file: UploadFile = File(...),
    feedback_token: str = Form(...),
    consent_granted: bool = Form(...),
    source: str = Form("user_feedback"),
):
    if not consent_granted:
        raise HTTPException(status_code=422, detail="Cần đồng ý lưu ảnh trước khi gửi.")
    if source not in ("user_feedback", "low_confidence"):
        raise HTTPException(status_code=422, detail="Nguồn phản hồi không hợp lệ.")
    if file.content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise HTTPException(status_code=415, detail="Chỉ nhận ảnh JPEG, PNG hoặc WebP.")
    payload = _verify(feedback_token, "submit")
    image_bytes = await file.read(MAX_REVIEW_IMAGE + 1)
    if not image_bytes or len(image_bytes) > MAX_REVIEW_IMAGE:
        raise HTTPException(status_code=413, detail="Ảnh phải nhỏ hơn 8 MB.")
    if hashlib.sha256(image_bytes).hexdigest() != payload["image_sha256"]:
        raise HTTPException(status_code=400, detail="Ảnh không khớp với lần nhận diện.")
    if not payload["predicted_top3"]:
        raise HTTPException(status_code=422, detail="Không có dự đoán để thẩm định.")
    doc = {
        "prediction_id": payload["prediction_id"],
        "consent_granted": True,
        "consent_at": datetime.now(timezone.utc),
        "consent_version": CONSENT_VERSION,
        "source": source,
        "predicted_top3": payload["predicted_top3"],
        "model_version": payload["model_version"],
        "capture_group_id": payload["prediction_id"],
        "image_bytes": Binary(image_bytes),
    }
    try:
        await get_shared_database().get_collection("plant_review_submissions").update_one(
            {"prediction_id": payload["prediction_id"]}, {"$setOnInsert": doc}, upsert=True
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Không thể gửi ảnh lúc này.") from exc
    return {
        "prediction_id": payload["prediction_id"],
        "revocation_token": _sign({
            "purpose": "revoke", "prediction_id": payload["prediction_id"]
        }),
    }


class Revocation(BaseModel):
    revocation_token: str


@router.post("/revoke", status_code=202)
async def revoke_feedback(payload: Revocation):
    data = _verify(payload.revocation_token, "revoke")
    prediction_id = data["prediction_id"]
    try:
        await get_shared_database().get_collection("plant_review_revocations").update_one(
            {"prediction_id": prediction_id},
            {"$setOnInsert": {"prediction_id": prediction_id}}, upsert=True
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Không thể rút lại đồng ý lúc này.") from exc
    return {"accepted": True}
