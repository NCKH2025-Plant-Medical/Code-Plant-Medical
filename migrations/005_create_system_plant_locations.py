"""
Migration 005: Tạo bảng system_plant_locations + seed tọa độ mẫu.

Bảng này lưu tọa độ GPS của các cây hệ thống (plant_medical).
Một loài cây có thể phân bố tại nhiều vị trí (quan hệ 1-N).

Chạy migration:
    cd d:/NCKH2026/NCKH
    python migrations/005_create_system_plant_locations.py

Yêu cầu:
    • Kết nối MySQL hoạt động (cấu hình DB_HOST, DB_USER, DB_PASSWORD, DB_NAME trong .env).
    • Bảng plant_medical đã tồn tại.
"""

import os
import sys

# Đảm bảo in tiếng Việt không lỗi trên Windows console
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

# Thêm đường dẫn gốc vào sys.path để import được các module của project
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)
sys.path.insert(0, PROJECT_ROOT)

from dotenv import load_dotenv
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

import mysql.connector
from mysql.connector import Error


# ── Cấu hình kết nối ─────────────────────────────────────────────────────────
DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "user":     os.getenv("DB_USER", "plant_api"),
    "password": os.getenv("DB_PASSWORD", "MatKhauAPI_TuyetMat_2026"),
    "database": os.getenv("DB_NAME", "plant_project"),
}


# ── SQL tạo bảng ─────────────────────────────────────────────────────────────
CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS system_plant_locations (
    id           INT          NOT NULL AUTO_INCREMENT,
    plant_id     INT          NOT NULL COMMENT 'FK tới plant_medical.ID',
    latitude     DECIMAL(10, 8) NOT NULL COMMENT 'Vĩ độ (WGS84)',
    longitude    DECIMAL(11, 8) NOT NULL COMMENT 'Kinh độ (WGS84)',
    address_name VARCHAR(255) DEFAULT NULL COMMENT 'Tên địa danh / vườn dược liệu',

    PRIMARY KEY  (id),
    INDEX idx_lat_lng (latitude, longitude),
    INDEX idx_plant_id (plant_id),

    CONSTRAINT fk_spl_plant
        FOREIGN KEY (plant_id) REFERENCES plant_medical (ID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Tọa độ GPS của các cây thuốc hệ thống — phục vụ tính năng Bản đồ GPS';
"""


def run_migration():
    """Thực thi migration: tạo bảng và seed dữ liệu mẫu."""
    conn = cursor = None
    try:
        print("[Migration 005] Đang kết nối MySQL...")
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        print(f"[Migration 005] Đã kết nối tới DB '{DB_CONFIG['database']}'.")

        # ── 1. Tạo bảng ───────────────────────────────────────────────────────
        print("[Migration 005] Đang tạo bảng system_plant_locations...")
        cursor.execute(CREATE_TABLE_SQL)
        conn.commit()
        print("[Migration 005] ✅ Bảng system_plant_locations đã sẵn sàng.")

        # ── 2. Kiểm tra bảng đã có dữ liệu chưa ─────────────────────────────
        cursor.execute("SELECT COUNT(*) AS cnt FROM system_plant_locations")
        existing_count = cursor.fetchone()["cnt"]

        if existing_count > 0:
            print(
                f"[Migration 005] Bảng đã có {existing_count} bản ghi. "
                "Bỏ qua bước seed dữ liệu mẫu."
            )
            return

        # ── 3. Lấy danh sách plant_id thực từ plant_medical ──────────────────
        print("[Migration 005] Đang lấy danh sách cây từ plant_medical...")
        cursor.execute(
            "SELECT ID, ten_label, ten_cay FROM plant_medical LIMIT 30"
        )
        plants = cursor.fetchall()

        if not plants:
            print("[Migration 005] ⚠️  plant_medical không có dữ liệu — bỏ qua seed.")
            return

        print(f"[Migration 005] Tìm thấy {len(plants)} cây. Đang seed tọa độ mẫu...")

        # ── 4. Seed tọa độ mẫu ───────────────────────────────────────────────
        # Tọa độ mẫu phân bổ quanh khu vực Hà Nội và các vùng dược liệu Việt Nam.
        # QUAN TRỌNG: Đây là dữ liệu demo — cần được thay thế bởi tọa độ thực tế
        # từ dữ liệu điều tra dược liệu hoặc cơ sở dữ liệu địa lý cây thuốc.
        sample_locations = [
            # [offset_lat, offset_lng, address_name]
            (0.0000,  0.0000, "Vườn thực vật Hà Nội"),
            (0.0120,  0.0050, "Vườn Bách Thảo"),
            (0.0250, -0.0080, "Vườn dược liệu Gia Lâm"),
            (0.0380,  0.0120, "Rừng sinh thái Cúc Phương"),
            (-0.0100, 0.0200, "Vùng núi Ba Vì"),
            (0.0500, -0.0150, "Vườn dược liệu Hòa Bình"),
            (-0.0200, -0.0100, "Khu bảo tồn thiên nhiên Hương Sơn"),
            (0.0600,  0.0300, "Đồi chè dược liệu Phú Thọ"),
        ]

        # Tọa độ trung tâm (Hà Nội)
        BASE_LAT = 21.0285
        BASE_LNG = 105.8542

        seed_data = []
        for idx, plant in enumerate(plants):
            loc = sample_locations[idx % len(sample_locations)]
            lat = round(BASE_LAT + loc[0] + (idx * 0.0021), 8)
            lng = round(BASE_LNG + loc[1] + (idx * 0.0013), 8)
            addr = loc[2]
            seed_data.append((plant["ID"], lat, lng, addr))

        cursor.executemany(
            "INSERT INTO system_plant_locations (plant_id, latitude, longitude, address_name) "
            "VALUES (%s, %s, %s, %s)",
            seed_data,
        )
        conn.commit()

        print(f"[Migration 005] ✅ Đã seed {len(seed_data)} tọa độ mẫu.")
        print()
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║  Migration 005 hoàn thành!                                  ║")
        print("║                                                              ║")
        print("║  ⚠️  LƯU Ý QUAN TRỌNG:                                      ║")
        print("║  Tọa độ đã seed là DỮ LIỆU MẪU để demo UI.                 ║")
        print("║  Cần thay thế bằng tọa độ thực tế trước khi đưa vào        ║")
        print("║  production (điều tra dược liệu, GPS thực địa, v.v.).       ║")
        print("╚══════════════════════════════════════════════════════════════╝")

    except Error as err:
        print(f"[Migration 005] ❌ Lỗi MySQL: {err}")
        sys.exit(1)
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()
            print("[Migration 005] Đã đóng kết nối MySQL.")


if __name__ == "__main__":
    run_migration()
