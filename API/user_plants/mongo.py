# API/user_plants/mongo.py
#
# Tái sử dụng client Motor đã khởi tạo từ auth.mongo.
# Collection UserPlants nằm trong cùng DB plant_vision_db.

from API.auth.mongo import database as _db

# Collection chứa cây cá nhân của người dùng
def get_user_plants_collection():
    """Trả về AsyncIOMotorCollection cho UserPlants."""
    return _db.get_collection("UserPlants")
