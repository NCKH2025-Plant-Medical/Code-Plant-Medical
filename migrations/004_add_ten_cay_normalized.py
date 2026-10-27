"""
migrations/004_add_ten_cay_normalized.py
Thêm cột ten_cay_normalized và index idx_ten_cay_normalized vào plant_medical.
Backfill dữ liệu tên cây chuẩn hóa (không dấu, lowercase, trim).
"""
import unicodedata
import re
import mysql.connector

_DB_CONFIG = {
    "host": "localhost",
    "user": "plant_api",
    "password": "MatKhauAPI_TuyetMat_2026",
    "database": "plant_project",
}

def remove_vietnamese_tones(text: str) -> str:
    if not text:
        return ""
    nfd = unicodedata.normalize("NFD", text)
    stripped = "".join(ch for ch in nfd if unicodedata.category(ch) != "Mn")
    stripped = stripped.replace("đ", "d").replace("Đ", "d")
    return re.sub(r"\s+", " ", stripped).strip().lower()

def run():
    print("Migration 004: add ten_cay_normalized and index")
    conn = mysql.connector.connect(**_DB_CONFIG)
    cur = conn.cursor(dictionary=True)

    # 1. Kiểm tra cột
    cur.execute(
        "SELECT COUNT(*) as c FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='plant_medical' AND COLUMN_NAME='ten_cay_normalized'"
    )
    if cur.fetchone()["c"] == 0:
        cur.execute("ALTER TABLE plant_medical ADD COLUMN ten_cay_normalized VARCHAR(255) NULL AFTER ten_cay")
        conn.commit()
        print("  [OK] Added column ten_cay_normalized")
    else:
        print("  [SKIP] Column ten_cay_normalized already exists")

    # 2. Kiểm tra index
    cur.execute(
        "SELECT COUNT(*) as c FROM information_schema.STATISTICS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='plant_medical' AND INDEX_NAME='idx_ten_cay_normalized'"
    )
    if cur.fetchone()["c"] == 0:
        cur.execute("CREATE INDEX idx_ten_cay_normalized ON plant_medical (ten_cay_normalized)")
        conn.commit()
        print("  [OK] Added index idx_ten_cay_normalized")
    else:
        print("  [SKIP] Index idx_ten_cay_normalized already exists")

    # 3. Backfill dữ liệu
    cur.execute("SELECT ID, ten_cay FROM plant_medical")
    rows = cur.fetchall()
    for r in rows:
        norm = remove_vietnamese_tones(r["ten_cay"])
        cur.execute("UPDATE plant_medical SET ten_cay_normalized = %s WHERE ID = %s", (norm, r["ID"]))
    conn.commit()
    print(f"  [OK] Backfilled {len(rows)} rows with ten_cay_normalized")

    cur.close()
    conn.close()

if __name__ == "__main__":
    run()
