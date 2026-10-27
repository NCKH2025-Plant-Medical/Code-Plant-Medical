import os
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

# Load biến môi trường từ file .env ở thư mục gốc
load_dotenv()

MONGO_DETAILS = os.getenv("MONGODB_URL")

if not MONGO_DETAILS:
    raise ValueError("Chưa tìm thấy biến MONGODB_URL trong file .env!")

# Khởi tạo client kết nối Motor
client = AsyncIOMotorClient(MONGO_DETAILS)
database = client.plant_vision_db

def get_user_collection():
    """Hàm lấy collection users để dùng ở các router"""
    return database.get_collection("users")

# Hàm test kết nối
async def ping_database():
    try:
        await client.admin.command('ping')
        print(">>> Kết nối MongoDB Atlas (Auth Service) thành công! <<<")
    except Exception as e:
        print(f">>> Lỗi kết nối MongoDB Atlas: {e} <<<")

if __name__ == "__main__":
    asyncio.run(ping_database())