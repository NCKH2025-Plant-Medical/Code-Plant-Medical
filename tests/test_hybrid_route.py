import asyncio
import unittest
from unittest.mock import patch, AsyncMock
import httpx
from API.routing import map_routing_router as routing

class HybridRouteTests(unittest.TestCase):
    def test_road_geometry_eta_and_last_leg(self):
        response = httpx.Response(200, json={"code": "Ok", "routes": [{
            "geometry": {"coordinates": [[105,21],[105.001,21.002],[105.003,21.003]]},
            "distance": 850, "duration": 660,
        }]})
        with patch.object(routing, "_OSRM_URL", "https://example.test/{lat1}"), patch.object(
            routing.httpx.AsyncClient, "get", new=AsyncMock(return_value=response)):
            result = asyncio.run(routing.get_directions(21,105,21.005,105.005))
        self.assertEqual(result.route_kind, "walking")
        self.assertEqual(result.duration_minutes, 11)
        self.assertEqual(len(result.points), 3)
        self.assertEqual(result.snapped_end_point, [21.003,105.003])
        self.assertEqual(result.off_trail_points, [[21.003,105.003],[21.005,105.005]])
