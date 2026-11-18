import asyncio
import unittest
from unittest.mock import patch, AsyncMock
from API.routing import map_routing_router as routing

class RoutingSafetyTests(unittest.TestCase):
    def test_missing_walking_provider_has_no_eta(self):
        with patch.object(routing, "_OSRM_URL", ""):
            result = asyncio.run(routing.get_directions(21.0, 105.0, 21.01, 105.01))
        self.assertEqual(result.route_kind, "reference")
        self.assertIsNone(result.duration_minutes)
        self.assertEqual(result.points, [[21.0, 105.0], [21.01, 105.01]])

    def test_provider_failure_does_not_invent_a_walkable_route(self):
        with patch.object(routing, "_OSRM_URL", "https://example.test/{lat1}"), patch.object(routing.httpx.AsyncClient, "get", new=AsyncMock(side_effect=TimeoutError)):
            result = asyncio.run(routing.get_directions(21.0, 105.0, 21.01, 105.01))
        self.assertEqual(result.route_kind, "reference")
        self.assertIsNone(result.duration_minutes)

    def test_invalid_coordinates_rejected(self):
        with self.assertRaises(routing.HTTPException):
            asyncio.run(routing.get_directions(100, 105, 21, 105))

class AdminAuthorizationTests(unittest.TestCase):
    def test_only_database_admin_can_update_protection(self):
        import ast
        from pathlib import Path
        tree = ast.parse(Path("API/auth/utils.py").read_text(encoding="utf-8"))
        fn = next(n for n in tree.body if isinstance(n, ast.AsyncFunctionDef) and n.name == "require_admin")
        fn.args.defaults = []
        scope = {"HTTPException": routing.HTTPException}
        exec(compile(ast.Module(body=[fn], type_ignores=[]), "auth", "exec"), scope)
        for user in [{}, {"role": "user"}, {"role": "Admin"}]:
            with self.assertRaises(routing.HTTPException) as error:
                asyncio.run(scope["require_admin"](user))
            self.assertEqual(error.exception.status_code, 403)
        admin = {"_id": "operator", "role": "admin"}
        self.assertEqual(asyncio.run(scope["require_admin"](admin)), admin)

class ConservationQueryTests(unittest.TestCase):
    def test_bbox_uses_public_cell_and_hides_address(self):
        import ast
        import sqlite3
        from pathlib import Path
        tree = ast.parse(Path("API/database.py").read_text(encoding="utf-8"))
        fn = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "get_system_plants_in_bounds")
        db = sqlite3.connect(":memory:")
        db.row_factory = sqlite3.Row
        db.executescript("""
        CREATE TABLE plant_medical (ID INTEGER, ten_label TEXT, ten_cay TEXT, ten_quocte TEXT, thong_tin TEXT, anh_minh_hoa TEXT, is_protected INTEGER, protection_level TEXT, conservation_notes TEXT);
        CREATE TABLE system_plant_locations (id INTEGER, plant_id INTEGER, latitude REAL, longitude REAL, address_name TEXT);
        INSERT INTO plant_medical VALUES (1,'rare','Rare',NULL,NULL,NULL,1,NULL,NULL);
        INSERT INTO system_plant_locations VALUES (1,1,21.0123,105.0234,'private trail');
        """)
        class Cursor:
            def execute(self, sql, params):
                self.cursor = db.execute(sql.replace("%s", "?"), params)
            def fetchall(self): return [dict(row) for row in self.cursor.fetchall()]
            def close(self): pass
        class Pool:
            def get_connection(self): return self
            def cursor(self, **kwargs): return Cursor()
            def close(self): pass
        scope = {"_DB_POOL": Pool(), "_HAS_IS_DELETED": False, "Error": sqlite3.Error, "print": lambda *args: None}
        exec(compile(ast.Module(body=[fn], type_ignores=[]), "query", "exec"), scope)
        query = scope[fn.name]
        self.assertEqual(query(21.012,21.013,105.023,105.024), [])
        rows = query(21.049,21.051,105.049,105.051)
        self.assertEqual(len(rows), 1)
        self.assertAlmostEqual(rows[0]["latitude"], 21.05)
        self.assertAlmostEqual(rows[0]["longitude"], 105.05)
        self.assertIsNone(rows[0]["address_name"])
        db.close()

if __name__ == "__main__":
    unittest.main()
