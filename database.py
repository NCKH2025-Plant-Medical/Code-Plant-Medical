import mysql.connector
from mysql.connector import pooling, Error

_DB_POOL: pooling.MySQLConnectionPool | None = None  
_DB_CONFIG = {
    "host":     "localhost",
    "user":     "root",
    "password": "minhtriet",   
    "database": "plant_project",
}
_POOL_NAME = "plant_pool"
_POOL_SIZE = 5

try:
    _DB_POOL = pooling.MySQLConnectionPool(
        pool_name=_POOL_NAME,
        pool_size=_POOL_SIZE,
        pool_reset_session=True,
        **_DB_CONFIG,
    )
    print(
        f"[database.py] MySQL connection pool '{_POOL_NAME}' "
        f"initialised (size={_POOL_SIZE})."
    )
except Error as err:
    print(f"[database.py] CRITICAL: Could not create connection pool — {err}")
    _DB_POOL = None

def get_plant_info_by_label(predicted_class: str) -> dict | None:

    if _DB_POOL is None:
        print("[database.py] ERROR: Connection pool is not available.")
        return None

    connection = None   
    cursor     = None

    try:
        connection = _DB_POOL.get_connection()
        cursor = connection.cursor(dictionary=True)

      
        sql = (
            "SELECT ten_cay, ten_quocte, thong_tin, cong_dung, cach_dung, luu_y "
            "FROM plant_medical "
            "WHERE ten_label = %s"
        )
        cursor.execute(sql, (predicted_class,))
        result = cursor.fetchone()

    except Error as err:
        print(f"[database.py] Query error for label '{predicted_class}': {err}")
        return None

    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None:
            connection.close()  
    if result is not None:
        return {
            "Tên cây":      result.get("ten_cay"),
            "Tên quốc tế":  result.get("ten_quocte"),
            "Thông tin":    result.get("thong_tin"),
            "Công dụng":    result.get("cong_dung"),
            "Cách dùng":    result.get("cach_dung"),
            "Lưu ý":        result.get("luu_y"),
        }
    
    return None
