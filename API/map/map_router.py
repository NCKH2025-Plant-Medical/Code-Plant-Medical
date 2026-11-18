# API/map/map_router.py
#
# Module Bản đồ (Map): Tập hợp toàn bộ các router liên quan đến bản đồ
# (Cây hệ thống trên map, Cây quanh đây theo bán kính, Chỉ đường GPS OSRM).
# ─────────────────────────────────────────────────────────────────────────────

from fastapi import APIRouter

try:
    from map_system_plants_router import router as map_system_plants_router
    from map_nearby_router import router as map_nearby_router
    from map_routing_router import router as map_routing_router
except ImportError:
    try:
        from system_plants.map_system_plants_router import router as map_system_plants_router
        from nearby.map_nearby_router import router as map_nearby_router
        from routing.map_routing_router import router as map_routing_router
    except ImportError:
        from API.system_plants.map_system_plants_router import router as map_system_plants_router
        from API.nearby.map_nearby_router import router as map_nearby_router
        from API.routing.map_routing_router import router as map_routing_router

# Router chính của phân hệ Bản đồ (Map Module)
map_router = APIRouter(tags=["Map"])

# Gộp các sub-router chuyên biệt vào map_router
map_router.include_router(map_system_plants_router)
map_router.include_router(map_nearby_router)
map_router.include_router(map_routing_router)

router = map_router

