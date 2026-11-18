"""Mongo inbox shared with admin_web, separate from the app auth database."""

import os
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient

load_dotenv(Path(__file__).resolve().parent.parent / ".env")


@lru_cache(maxsize=1)
def get_shared_database():
    uri = os.getenv("ADMIN_SHARED_MONGO_URI")
    db_name = os.getenv("MONGO_DB", "plant_vision_db")
    if not uri:
        raise RuntimeError("ADMIN_SHARED_MONGO_URI is not configured")
    return AsyncIOMotorClient(uri)[db_name]
