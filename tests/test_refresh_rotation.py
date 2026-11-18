import ast
import asyncio
import hashlib
import unittest
from pathlib import Path
from types import SimpleNamespace
from fastapi import HTTPException

class RotationTests(unittest.TestCase):
    def test_concurrent_refresh_consumes_token_once(self):
        tree = ast.parse(Path('API/auth/router.py').read_text(encoding='utf-8'))
        fn = next(n for n in tree.body if isinstance(n, ast.AsyncFunctionDef) and n.name == 'refresh_access_token')
        fn.decorator_list = []
        fn.args.args[0].annotation = None
        class Sessions:
            available = True
            async def find_one_and_delete(self, query):
                if not self.available: return None
                self.available = False
                return query
        class Users:
            database = SimpleNamespace(refresh_sessions=Sessions())
            async def find_one(self, query): return {'_id': 'user'}
        async def issue(uid): return 'new-pair'
        scope = dict(decode_refresh_token=lambda token: {'sub': 'user'},
                     ObjectId=lambda value: value, get_user_collection=lambda: Users(),
                     HTTPException=HTTPException, status=SimpleNamespace(HTTP_401_UNAUTHORIZED=401),
                     hashlib=hashlib, _make_token=issue)
        exec(compile(ast.Module(body=[fn], type_ignores=[]), 'rotation', 'exec'), scope)
        async def run():
            body = SimpleNamespace(refresh_token='old')
            return await asyncio.gather(scope[fn.name](body), scope[fn.name](body), return_exceptions=True)
        results = asyncio.run(run())
        self.assertEqual(results.count('new-pair'), 1)
        rejected = next(r for r in results if isinstance(r, HTTPException))
        self.assertEqual(rejected.status_code, 401)
