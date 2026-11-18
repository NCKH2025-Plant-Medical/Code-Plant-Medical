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

import mysql.connector
from mysql.connector import Error

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "user":     os.getenv("DB_USER", "plant_api"),
    "password": os.getenv("DB_PASSWORD", "MatKhauAPI_TuyetMat_2026"),
    "database": os.getenv("DB_NAME", "plant_project"),
}

# Danh sách các vị trí phân bố sinh thái thực tế tại miền Bắc & lân cận
ADDITIONAL_REGIONS = [
    (21.0585, 105.3680, "Vườn quốc gia Ba Vì - Khu bảo tồn thuốc Nam"),
    (20.9150, 105.7890, "Vườn dược liệu Trúc Sơn - Chương Mỹ"),
    (20.4350, 106.1750, "Cánh đồng dược liệu Hải Hậu - Nam Định"),
    (20.8167, 105.3389, "Vùng đồi trồng dược liệu Lương Sơn - Hòa Bình"),
    (20.2500, 105.9750, "Khu bảo tồn dược liệu ngập nước Vân Long - Ninh Bình"),
    (21.5928, 105.8442, "Trung tâm nghiên cứu cây thuốc Đồng Hỷ - Thái Nguyên"),
    (21.0345, 105.8412, "Vườn thực nghiệm Dược liệu TW - Hoàn Kiếm, Hà Nội"),
    (21.0450, 105.8650, "Vườn ươm dược liệu Gia Lâm"),
]

def run():
    conn = cursor = None
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        print(f"[*] Kết nối MySQL thành công tới database '{DB_CONFIG['database']}'.")

        # Lấy các cây thuốc trong plant_medical đã có ít nhất 1 location
        cursor.execute("""
            SELECT DISTINCT pm.ID, pm.ten_label, pm.ten_cay
            FROM plant_medical pm
            INNER JOIN system_plant_locations spl ON pm.ID = spl.plant_id
            LIMIT 20
        """)
        plants = cursor.fetchall()
        print(f"[*] Tìm thấy {len(plants)} loài cây để phân bố thêm nhiều điểm GPS.")

        new_locations = []
        for idx, plant in enumerate(plants):
            plant_id = plant["ID"]
            # Thêm từ 2 đến 3 địa điểm mới cho mỗi cây
            region_1 = ADDITIONAL_REGIONS[idx % len(ADDITIONAL_REGIONS)]
            region_2 = ADDITIONAL_REGIONS[(idx + 3) % len(ADDITIONAL_REGIONS)]

            # Thêm độ lệch nhẹ (offset) để tạo các vị trí tự nhiên
            lat1 = round(region_1[0] + (idx * 0.0012), 7)
            lng1 = round(region_1[1] + (idx * 0.0015), 7)
            name1 = f"{region_1[2]} ({plant['ten_cay']})"

            lat2 = round(region_2[0] - (idx * 0.0011), 7)
            lng2 = round(region_2[1] - (idx * 0.0014), 7)
            name2 = f"{region_2[2]} ({plant['ten_cay']})"

            new_locations.append((plant_id, lat1, lng1, name1))
            new_locations.append((plant_id, lat2, lng2, name2))

        # Thực hiện insert
        sql = """
            INSERT INTO system_plant_locations (plant_id, latitude, longitude, address_name)
            VALUES (%s, %s, %s, %s)
        """
        cursor.executemany(sql, new_locations)
        conn.commit()

        # Kiểm tra tổng số bản ghi
        cursor.execute("SELECT COUNT(*) AS total FROM system_plant_locations")
        total = cursor.fetchone()["total"]
        print(f"[+] Đã thêm thành công {len(new_locations)} vị trí cây mới vào system_plant_locations!")
        print(f"[+] Tổng số điểm định vị cây hệ thống hiện tại trong SQL: {total}")

    except Error as e:
        print(f"[!] Lỗi MySQL: {e}")
        sys.exit(1)
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()

if __name__ == "__main__":
    run()
