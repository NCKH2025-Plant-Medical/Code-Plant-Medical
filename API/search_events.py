"""Accept only a confirmed, final zero result from the public app search."""

import asyncio
import hashlib
import re
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

try:
    import database as catalog
    from shared_admin_mongo import get_shared_database
except ImportError:
    from API import database as catalog
    from API.shared_admin_mongo import get_shared_database


router = APIRouter(prefix="/api/v1/search-events", tags=["Search"])
_PRIVATE = re.compile(r"@|https?://|www\.|\d{5,}", re.IGNORECASE)


class ZeroResultEvent(BaseModel):
    query: str = Field(min_length=2, max_length=100)
    search_session_id: UUID


@router.post("/zero-result", status_code=202)
async def record_zero_result(payload: ZeroResultEvent):
    query = payload.query.strip()
    if len(query) < 2 or _PRIVATE.search(query):
        raise HTTPException(status_code=422, detail="Từ khóa không phù hợp để thống kê.")
    try:
        matches = await asyncio.get_running_loop().run_in_executor(
            None, catalog.search_plants, query, 1
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail="Không thể xác minh tìm kiếm.") from exc
    if matches:
        raise HTTPException(status_code=409, detail="Từ khóa hiện đã có kết quả.")

    now = datetime.now(timezone.utc)
    normalized = catalog.remove_vietnamese_tones(query)
    bucket = int(now.timestamp()) // 600
    receipt = hashlib.sha256(
        f"{payload.search_session_id}:{normalized}:{bucket}".encode("utf-8")
    ).hexdigest()
    document = {
        "_id": receipt,
        "schema_version": 1,
        "event_id": str(uuid4()),
        "search_session_id": str(payload.search_session_id),
        "producer": "app",
        "query": query,
        "outcome": "success",
        "result_count": 0,
        "is_final": True,
        "occurred_at": now,
        "expires_at": now + timedelta(days=7),
    }
    try:
        await get_shared_database().get_collection("plant_search_events").update_one(
            {"_id": receipt}, {"$setOnInsert": document}, upsert=True
        )
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Không thể ghi sự kiện tìm kiếm.") from exc
    return {"accepted": True}
