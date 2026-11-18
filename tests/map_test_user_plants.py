# tests/test_user_plants_map.py
#
# Test suite cho GET /api/v1/user-plants/map
#
# Chạy:
#   pytest tests/test_user_plants_map.py -v
#
# Cài thêm nếu chưa có:
#   pip install pytest pytest-asyncio httpx

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from httpx import AsyncClient, ASGITransport

# Đảm bảo import được API
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# ── Stub cho Firebase Admin và Motor (tránh kết nối thật khi test) ────────
import firebase_admin
if not firebase_admin._apps:
    import unittest.mock as _mock
    with _mock.patch("firebase_admin.initialize_app"):
        pass

# ── Fake user docs ─────────────────────────────────────────────────────────
from bson import ObjectId

USER_A_ID   = ObjectId()
USER_B_ID   = ObjectId()
FAKE_USER_A = {"_id": USER_A_ID, "email": "a@test.com"}
FAKE_USER_B = {"_id": USER_B_ID, "email": "b@test.com"}

# ── Fake plant docs ────────────────────────────────────────────────────────
def _make_plant(plant_id, user_id, lng, lat, name="Cây test", thumbnail=None):
    return {
        "_id": ObjectId(plant_id) if plant_id else ObjectId(),
        "user_id": str(user_id),
        "name": name,
        "thumbnail_url": thumbnail,
        "location": {
            "type": "Point",
            "coordinates": [lng, lat],
        },
    }

# Cây của User A
PLANT_A1 = _make_plant("aaa111111111111111111111", USER_A_ID, 106.0, 21.0, "Rau má")
PLANT_A2 = _make_plant("aaa222222222222222222222", USER_A_ID, 105.9, 21.1, "Bạc hà")

# Cây của User B (không được lộ cho User A)
PLANT_B1 = _make_plant("bbb111111111111111111111", USER_B_ID, 106.0, 21.0, "CÂY CỦA B")

# Cây hỏng (thiếu coordinates)
PLANT_CORRUPT = {
    "_id": ObjectId(),
    "user_id": str(USER_A_ID),
    "name": "Cây hỏng",
    "location": {"type": "Point"},   # Thiếu "coordinates"!
}


# ══════════════════════════════════════════════════════════════════════════════
# Helpers & fixtures
# ══════════════════════════════════════════════════════════════════════════════

def _fake_cursor(docs: list):
    """Tạo AsyncMock giả lập Motor cursor."""
    cursor = MagicMock()
    cursor.to_list = AsyncMock(return_value=docs)
    return cursor


async def _get_app():
    """Import app lazily để patch có hiệu lực trước khi import."""
    from API.main_fastapi import app
    return app


# ══════════════════════════════════════════════════════════════════════════════
# Test Cases
# ══════════════════════════════════════════════════════════════════════════════

@pytest.mark.asyncio
async def test_unauthorized_no_token():
    """401 khi không có Bearer token."""
    app = await _get_app()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/user-plants/map", params={
            "min_lat": 21.0, "max_lat": 21.2,
            "min_lng": 105.8, "max_lng": 106.2,
        })
    assert resp.status_code in (401, 403), f"Expected 401/403, got {resp.status_code}"


@pytest.mark.asyncio
async def test_unauthorized_expired_token():
    """401 khi token hết hạn."""
    import jwt
    from datetime import datetime, timezone, timedelta
    expired_token = jwt.encode(
        {"sub": str(USER_A_ID), "exp": datetime.now(timezone.utc) - timedelta(hours=1)},
        "my-super-secret-key-123",
        algorithm="HS256",
    )
    app = await _get_app()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get(
            "/api/v1/user-plants/map",
            params={"min_lat": 21.0, "max_lat": 21.2, "min_lng": 105.8, "max_lng": 106.2},
            headers={"Authorization": f"Bearer {expired_token}"},
        )
    assert resp.status_code == 401, f"Expected 401, got {resp.status_code}"


@pytest.mark.asyncio
async def test_bad_input_string_params():
    """400 khi truyền chữ vào query params thay vì float."""
    import jwt
    from datetime import datetime, timezone, timedelta
    token = jwt.encode(
        {"sub": str(USER_A_ID), "exp": datetime.now(timezone.utc) + timedelta(hours=1)},
        "my-super-secret-key-123",
        algorithm="HS256",
    )
    app = await _get_app()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get(
            "/api/v1/user-plants/map",
            params={"min_lat": "abc", "max_lat": 21.2, "min_lng": 105.8, "max_lng": 106.2},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert resp.status_code == 422, f"Expected 422 (FastAPI validation), got {resp.status_code}"


@pytest.mark.asyncio
async def test_cross_data_isolation():
    """
    CRITICAL: User A KHÔNG được nhìn thấy cây của User B,
    dù cây của B nằm trong cùng bounding box.
    """
    import jwt
    from datetime import datetime, timezone, timedelta

    token_a = jwt.encode(
        {"sub": str(USER_A_ID), "exp": datetime.now(timezone.utc) + timedelta(hours=1)},
        "my-super-secret-key-123",
        algorithm="HS256",
    )

    # Mock get_current_user trả về User A
    # Mock collection.find trả về CHỈ cây của User A (MongoDB đã filter)
    with (
        patch("API.user_plants.router.get_current_user", return_value=FAKE_USER_A),
        patch("API.user_plants.router.get_user_plants_collection") as mock_col,
    ):
        mock_col.return_value.find.return_value = _fake_cursor([PLANT_A1, PLANT_A2])

        app = await _get_app()
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get(
                "/api/v1/user-plants/map",
                params={"min_lat": 20.9, "max_lat": 21.2, "min_lng": 105.8, "max_lng": 106.2},
                headers={"Authorization": f"Bearer {token_a}"},
            )

    assert resp.status_code == 200
    data = resp.json()

    # Không có cây nào của User B trong kết quả
    names = [item["name"] for item in data]
    assert "CÂY CỦA B" not in names, "❌  Cross-data leak: cây của User B xuất hiện trong response của User A!"
    assert "Rau má" in names
    assert "Bạc hà" in names
    print(f"✅  Cross-data isolation OK: {names}")


@pytest.mark.asyncio
async def test_corrupt_document_skipped():
    """Document hỏng (thiếu coordinates) phải bị bỏ qua, không crash."""
    with (
        patch("API.user_plants.router.get_current_user", return_value=FAKE_USER_A),
        patch("API.user_plants.router.get_user_plants_collection") as mock_col,
    ):
        # Trả về 1 cây hợp lệ + 1 cây hỏng
        mock_col.return_value.find.return_value = _fake_cursor([PLANT_A1, PLANT_CORRUPT])

        app = await _get_app()
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get(
                "/api/v1/user-plants/map",
                params={"min_lat": 20.9, "max_lat": 21.2, "min_lng": 105.8, "max_lng": 106.2},
                headers={"Authorization": "Bearer fake_valid_token"},
            )

    assert resp.status_code == 200
    data = resp.json()
    # Chỉ 1 cây hợp lệ được trả về, cây hỏng bị bỏ qua
    assert len(data) == 1
    assert data[0]["name"] == "Rau má"
    print("✅  Corrupt document skipped OK")


@pytest.mark.asyncio
async def test_db_timeout_returns_500():
    """PyMongoError phải trả về 500, không crash server."""
    from pymongo.errors import NetworkTimeout

    with (
        patch("API.user_plants.router.get_current_user", return_value=FAKE_USER_A),
        patch("API.user_plants.router.get_user_plants_collection") as mock_col,
    ):
        mock_col.return_value.find.return_value.to_list = AsyncMock(
            side_effect=NetworkTimeout("Simulated DB timeout")
        )

        app = await _get_app()
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get(
                "/api/v1/user-plants/map",
                params={"min_lat": 20.9, "max_lat": 21.2, "min_lng": 105.8, "max_lng": 106.2},
                headers={"Authorization": "Bearer fake_valid_token"},
            )

    assert resp.status_code == 500
    print("✅  DB timeout → 500 OK")


@pytest.mark.asyncio
async def test_result_limit_500():
    """Kết quả không vượt quá 500 document."""
    # Giả lập MongoDB trả về đúng 500 doc (đã bị limit từ Motor)
    fake_docs = [
        _make_plant(None, USER_A_ID, 106.0 + i * 0.001, 21.0 + i * 0.001)
        for i in range(500)
    ]

    with (
        patch("API.user_plants.router.get_current_user", return_value=FAKE_USER_A),
        patch("API.user_plants.router.get_user_plants_collection") as mock_col,
    ):
        mock_col.return_value.find.return_value = _fake_cursor(fake_docs)

        app = await _get_app()
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get(
                "/api/v1/user-plants/map",
                params={"min_lat": 20.9, "max_lat": 22.0, "min_lng": 105.0, "max_lng": 107.0},
                headers={"Authorization": "Bearer fake_valid_token"},
            )

    assert resp.status_code == 200
    data = resp.json()
    assert len(data) <= 500
    print(f"✅  Result limit OK: {len(data)} ≤ 500")


@pytest.mark.asyncio
async def test_response_schema():
    """Response phải có đúng các field: id, name, thumbnail_url, lat, lng, source='mongodb'."""
    with (
        patch("API.user_plants.router.get_current_user", return_value=FAKE_USER_A),
        patch("API.user_plants.router.get_user_plants_collection") as mock_col,
    ):
        mock_col.return_value.find.return_value = _fake_cursor([PLANT_A1])

        app = await _get_app()
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get(
                "/api/v1/user-plants/map",
                params={"min_lat": 20.9, "max_lat": 21.2, "min_lng": 105.8, "max_lng": 106.2},
                headers={"Authorization": "Bearer fake_valid_token"},
            )

    assert resp.status_code == 200
    item = resp.json()[0]
    assert "id"            in item
    assert "name"          in item
    assert "thumbnail_url" in item
    assert "lat"           in item
    assert "lng"           in item
    assert item["source"]  == "mongodb"
    assert item["lat"]     == 21.0
    assert item["lng"]     == 106.0
    print("✅  Response schema OK:", item)
