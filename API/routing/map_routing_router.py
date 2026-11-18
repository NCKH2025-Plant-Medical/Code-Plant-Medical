# API/routing/router.py
#
# Endpoint chỉ đường (Directions / Routing) dành cho bản đồ cây thuốc
# ─────────────────────────────────────────────────────────────────────────────
# Tách biệt toàn bộ logic tính toán lộ trình, khoảng cách (km), thời gian và góc xoay (bearing)
# về phía Backend, trả kết quả đã tính toán và định dạng sẵn sàng cho Frontend hiển thị.
# ─────────────────────────────────────────────────────────────────────────────

import asyncio
import os
import logging
import math
from typing import List, Optional
import httpx
from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/routing", tags=["Routing"])

# Only configure an OSRM instance built with a pedestrian profile.
# Public pedestrian demo for local development; override for production.
_OSRM_URL = os.getenv("WALKING_OSRM_URL") or "https://routing.openstreetmap.de/routed-foot/route/v1/driving/{lng1},{lat1};{lng2},{lat2}"
_TIMEOUT_SECONDS = 12.0


class DirectionsResponse(BaseModel):
    snapped_end_point: Optional[List[float]] = None
    off_trail_points: List[List[float]] = []
    route_kind: str = "reference"
    distance_km: float
    distance_display: str           # Ví dụ: "450 m" hoặc "2,3 km"
    duration_minutes: Optional[int] = None
    duration_display: str           # Ví dụ: "6 phút" hoặc "< 1 phút"
    bearing: float                  # Góc xoay 0 - 360 độ (hướng xuất phát)
    points: List[List[float]]       # Danh sách [[lat, lng], [lat, lng], ...]


def calculate_bearing(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Tính góc bearing (0 - 360 độ) từ điểm 1 đến điểm 2."""
    r_lat1 = math.radians(lat1)
    r_lng1 = math.radians(lng1)
    r_lat2 = math.radians(lat2)
    r_lng2 = math.radians(lng2)

    d_lng = r_lng2 - r_lng1
    y = math.sin(d_lng) * math.cos(r_lat2)
    x = math.cos(r_lat1) * math.sin(r_lat2) - math.sin(r_lat1) * math.cos(r_lat2) * math.cos(d_lng)

    bearing = math.degrees(math.atan2(y, x))
    return (bearing + 360.0) % 360.0


def calculate_haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Tính khoảng cách hình cầu Haversine (km)."""
    r_lat1 = math.radians(lat1)
    r_lat2 = math.radians(lat2)
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)

    a = math.sin(d_lat / 2.0) ** 2 + math.cos(r_lat1) * math.cos(r_lat2) * (math.sin(d_lng / 2.0) ** 2)
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return 6371.0 * c


def format_distance(dist_km: float) -> str:
    """Định dạng khoảng cách chính xác theo km (ví dụ 2,3 km) hoặc mét (ví dụ 450 m)."""
    if dist_km < 1.0:
        meters = int(round(dist_km * 1000.0))
        return f"{meters} m"
    formatted = f"{dist_km:.1f}".replace(".", ",")
    return f"{formatted} km"


def format_duration(duration_min: int) -> str:
    """Định dạng thời gian di chuyển (ví dụ '6 phút' hoặc '< 1 phút')."""
    if duration_min <= 0:
        return "< 1 phút"
    if duration_min >= 60:
        h = duration_min // 60
        m = duration_min % 60
        return f"{h} giờ {m} phút" if m > 0 else f"{h} giờ"
    return f"{duration_min} phút"


@router.get(
    "/directions",
    response_model=DirectionsResponse,
    summary="Tính toán đường đi, khoảng cách realtime và góc xoay từ GPS người dùng đến cây",
    description=(
        "Xử lý hoàn toàn logic định tuyến OSRM, tính khoảng cách (làm tròn km/m), "
        "thời gian di chuyển và góc xoay (bearing). Trả kết quả đã định dạng sẵn."
    ),
)
async def get_directions(
    start_lat: float = Query(..., description="Vĩ độ điểm xuất phát (GPS người dùng)"),
    start_lng: float = Query(..., description="Kinh độ điểm xuất phát (GPS người dùng)"),
    end_lat: float = Query(..., description="Vĩ độ điểm đích (Tọa độ cây thuốc)"),
    end_lng: float = Query(..., description="Kinh độ điểm đích (Tọa độ cây thuốc)"),
) -> DirectionsResponse:
    # 1. Kiểm tra toạ độ hợp lệ
    if not (-90 <= start_lat <= 90 and -90 <= end_lat <= 90):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vĩ độ phải nằm trong khoảng [-90, 90]",
        )
    if not (-180 <= start_lng <= 180 and -180 <= end_lng <= 180):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Kinh độ phải nằm trong khoảng [-180, 180]",
        )

    # 2. Thử gọi dịch vụ định tuyến OSRM
    url = _OSRM_URL.format(lng1=start_lng, lat1=start_lat, lng2=end_lng, lat2=end_lat)
    route_points: List[List[float]] = []
    dist_km: float = 0.0
    duration_min: int = 0
    bearing: float = calculate_bearing(start_lat, start_lng, end_lat, end_lng)

    try:
        if not _OSRM_URL:
            raise ValueError("Walking routing is not configured")
        async with httpx.AsyncClient(timeout=_TIMEOUT_SECONDS) as client:
            resp = await client.get(url, params={"overview": "full", "geometries": "geojson", "steps": "true"})
            if resp.status_code == 200:
                data = resp.json()
                if data.get("code") == "Ok" and data.get("routes"):
                    primary_route = data["routes"][0]
                    coords = primary_route["geometry"]["coordinates"]
                    # GeoJSON coordinates là [lng, lat] -> chuyển thành [lat, lng]
                    route_points = [[float(c[1]), float(c[0])] for c in coords]

                    dist_meters = float(primary_route.get("distance", 0.0))
                    dist_km = round(dist_meters / 1000.0, 2)

                    dur_sec = float(primary_route.get("duration", 0.0))
                    duration_min = max(1, int(math.ceil(dur_sec / 60.0)))

                    # Nếu có các đoạn rẽ (legs/steps), tính bearing đoạn đầu tiên
                    try:
                        first_step = primary_route["legs"][0]["steps"][0]
                        first_maneuver_bearing = first_step.get("maneuver", {}).get("bearing_after")
                        if first_maneuver_bearing is not None:
                            bearing = float(first_maneuver_bearing)
                        elif len(route_points) >= 2:
                            bearing = calculate_bearing(
                                route_points[0][0], route_points[0][1],
                                route_points[1][0], route_points[1][1],
                            )
                    except Exception:
                        pass
    except Exception as exc:
        logger.warning("[routing] OSRM service timeout hoặc lỗi (%s), dùng fallback Haversine.", exc)

    route_kind = "walking" if route_points else "reference"

    # 3. Fallback nếu OSRM lỗi hoặc không tìm thấy đường đi (ví dụ khoảng cách xa hoặc đường chim bay)
    if not route_points:
        route_points = [[start_lat, start_lng], [end_lat, end_lng]]
        dist_km = round(calculate_haversine(start_lat, start_lng, end_lat, end_lng), 2)
        # Giả định vận tốc xe di chuyển nội đô ~ 30 km/h
        duration_min = None
        bearing = calculate_bearing(start_lat, start_lng, end_lat, end_lng)

    dist_display = format_distance(dist_km)
    dur_display = format_duration(duration_min) if duration_min is not None else "Chưa xác định thời gian"

    return DirectionsResponse(
        snapped_end_point=route_points[-1] if route_kind == "walking" else None,
        off_trail_points=[route_points[-1], [end_lat, end_lng]] if route_kind == "walking" else route_points,
        route_kind=route_kind,
        distance_km=dist_km,
        distance_display=dist_display,
        duration_minutes=duration_min,
        duration_display=dur_display,
        bearing=round(bearing, 1),
        points=route_points,
    )
