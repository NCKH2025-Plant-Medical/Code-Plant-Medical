import asyncio
import os
import sys

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)
sys.path.insert(0, PROJECT_ROOT)

from dotenv import load_dotenv
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

from motor.motor_asyncio import AsyncIOMotorClient
from bson import ObjectId

async def main():
    client = AsyncIOMotorClient(os.getenv("MONGODB_URL"))
    db = client.plant_vision_db
    users = await db.users.find({}).to_list(10)
    print(f"Users found: {len(users)}")
    for u in users:
        uid_str = str(u["_id"])
        username = u.get("username")
        count_str = await db.UserPlants.count_documents({"user_id": uid_str})
        count_oid = await db.UserPlants.count_documents({"user_id": u["_id"]})
        print(f"User '{username}' (id={uid_str}): string_match={count_str}, oid_match={count_oid}")
        
        # Check a sample plant
        sample = await db.UserPlants.find_one({"user_id": {"$in": [uid_str, u["_id"]]}})
        if sample:
            loc = sample.get("location")
            print(f"   Sample plant: {sample.get('name')}, loc={loc}")

    # Let's also check all documents in UserPlants
    total_all = await db.UserPlants.count_documents({})
    print(f"\nTotal documents in UserPlants collection: {total_all}")

if __name__ == "__main__":
    asyncio.run(main())
