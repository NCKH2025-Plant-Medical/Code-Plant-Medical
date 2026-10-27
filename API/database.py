import os
import re
import unicodedata
import mysql.connector
from mysql.connector import pooling, Error

# ---------------------------------------------------------------------------
# Database Configuration & Pool Initialization
# ---------------------------------------------------------------------------
_DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "user": os.getenv("DB_USER", "plant_api"),
    "password": os.getenv("DB_PASSWORD", "MatKhauAPI_TuyetMat_2026"),
    "database": os.getenv("DB_NAME", "plant_project"),
}
_POOL_NAME = "plant_pool"
_POOL_SIZE = 5

_DB_POOL: pooling.MySQLConnectionPool | None = None

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

# ---------------------------------------------------------------------------
# Runtime Schema Detection
# Automatically checks for 'is_deleted' and 'ten_cay_normalized' columns.
# ---------------------------------------------------------------------------
_HAS_IS_DELETED: bool = False
_HAS_TEN_CAY_NORMALIZED: bool = False


def _detect_schema() -> None:
    """Kiểm tra cột is_deleted và ten_cay_normalized trong plant_medical."""
    global _HAS_IS_DELETED, _HAS_TEN_CAY_NORMALIZED
    if _DB_POOL is None:
        return
    conn = cur = None
    try:
        conn = _DB_POOL.get_connection()
        cur = conn.cursor()
        cur.execute(
            "SELECT COLUMN_NAME FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() "
            "AND TABLE_NAME = 'plant_medical' "
            "AND COLUMN_NAME IN ('is_deleted', 'ten_cay_normalized')"
        )
        cols = {row[0] for row in cur.fetchall()}
        _HAS_IS_DELETED = "is_deleted" in cols
        _HAS_TEN_CAY_NORMALIZED = "ten_cay_normalized" in cols
        print(
            f"[database.py] Schema check: "
            f"is_deleted={'FOUND' if _HAS_IS_DELETED else 'NOT FOUND'}, "
            f"ten_cay_normalized={'FOUND' if _HAS_TEN_CAY_NORMALIZED else 'NOT FOUND'}"
        )
    except Error as e:
        print(f"[database.py] Schema detect error: {e}")
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


_detect_schema()

_WHERE_ACTIVE = "AND is_deleted = 0" if _HAS_IS_DELETED else ""

# ---------------------------------------------------------------------------
# Constants & Helpers for Search & Normalization
# ---------------------------------------------------------------------------
_SEARCH_MAX_KEYWORD_LEN = 100
_SEARCH_MAX_LIMIT = 50
_FULLTEXT_SPECIAL_CHARS = re.compile(r'[+\-<>()~*"@]')


def _escape_fulltext(keyword: str) -> str:
    """Loại bỏ ký tự đặc biệt MySQL BOOLEAN MODE để tránh syntax error."""
    return _FULLTEXT_SPECIAL_CHARS.sub(" ", keyword).strip()


def remove_vietnamese_tones(text: str) -> str:
    """Chuẩn hóa chuỗi tiếng Việt:
    - Normalization NFD tách diacritical marks
    - Chuyển 'đ'/'Đ' -> 'd'/'d'
    - Thu gọn khoảng trắng và lowercase
    """
    if not text:
        return ""
    nfd = unicodedata.normalize("NFD", text)
    stripped = "".join(ch for ch in nfd if unicodedata.category(ch) != "Mn")
    stripped = stripped.replace("đ", "d").replace("Đ", "d")
    return re.sub(r"\s+", " ", stripped).strip().lower()


_normalize_vietnamese = remove_vietnamese_tones

# Từ điển ánh xạ các tên gọi khác (alias) phổ biến của các cây thuốc
_COMMON_ALIASES: dict[str, list[str]] = {
    "Cho_de_rang_cua": ["diệp hạ châu", "dia ha chau", "chó đẻ", "chó đẻ răng cưa"],
    "Hoa_cuc": ["hoa cúc", "cúc hoa", "cúc vàng", "kim cúc"],
    "Nho_noi": ["cỏ nhọ nồi", "nhọ nồi", "cỏ mực"],
    "Nha_dam": ["nha đam", "lô hội"],
    "Mo_tam_the": ["mơ tam thể", "lá mơ lông", "mơ lông", "lá mơ"],
    "La_nang": ["lá náng", "náng hoa trắng", "cây náng"],
    "Hung_chanh": ["húng chanh", "tần dày lá"],
    "Trac_bach_diep": ["trắc bách diệp", "trắc bá diệp", "bá tử nhân"],
    "Y_di": ["ý dĩ", "bo bo", "hạt bo bo"],
    "Co_Xuoc": ["cỏ xước", "ngưu tất nam"],
    "Danh_danh": ["dành dành", "chi tử"],
    "Ich_mau": ["ích mẫu", "sung úy"],
    "Ke_dau_ngua": ["ké đầu ngựa", "thương nhĩ tử"],
    "Xich_dong_nam": ["xích đồng nam", "mò đỏ"],
    "Thien_mon_dong": ["thiên môn đông", "thiên môn"],
    "Dau_tam": ["dâu tằm", "tang diệp", "tang bạch bì"],
    "Co_tranh": ["cỏ tranh", "bạch mao căn"],
    "Ha_Kho_Thao": ["hạ khô thảo"],
    "Huong_nhu_tia": ["hương nhu tía", "hương nhu"],
    "La_lot": ["lá lốt"],
    "Ma_de": ["mã đề"],
    "Ngai_cuu": ["ngải cứu"],
    "Rau_ma": ["rau má"],
    "Rau_sam": ["rau sam"],
    "Tia_To": ["tía tô"],
    "Anh_thao": ["anh thảo"],
    "Bac_ha": ["bạc hà"],
    "Bo_cong_anh": ["bồ công anh"],
}


def _get_plant_search_names(row: dict) -> list[str]:
    """Trích xuất tất cả tên chính và tên gọi khác đã chuẩn hóa của một cây thuốc."""
    names: list[str] = []

    # 1. ten_cay gốc và tách phần trong/ngoài ngoặc đơn
    ten_cay = row.get("ten_cay") or ""
    if ten_cay:
        names.append(remove_vietnamese_tones(ten_cay))
        main_part = re.split(r"[\(\[\{]", ten_cay)[0].strip()
        if main_part:
            names.append(remove_vietnamese_tones(main_part))
        in_parens = re.findall(r"[\(\[\{](.*?)[\)\]\}]", ten_cay)
        for p in in_parens:
            for sub in re.split(r"[,;/]", p):
                sub_norm = remove_vietnamese_tones(sub)
                if sub_norm:
                    names.append(sub_norm)

    # 2. ten_label (vd: Bac_ha -> bac ha, Cho_de_rang_cua -> cho de rang cua)
    ten_label = row.get("ten_label") or ""
    if ten_label:
        label_as_name = remove_vietnamese_tones(ten_label.replace("_", " "))
        if label_as_name:
            names.append(label_as_name)

    # 3. Tên gọi khác trong từ điển alias
    for a in _COMMON_ALIASES.get(ten_label, []):
        a_norm = remove_vietnamese_tones(a)
        if a_norm:
            names.append(a_norm)

    # Khử trùng lặp giữ nguyên thứ tự
    seen: set[str] = set()
    unique_names: list[str] = []
    for n in names:
        if n and n not in seen:
            seen.add(n)
            unique_names.append(n)
    return unique_names


# ---------------------------------------------------------------------------
# 1. get_plant_info_by_label
# ---------------------------------------------------------------------------
def get_plant_info_by_label(predicted_class: str) -> dict | None:
    """Truy xuất hồ sơ đầy đủ của một cây theo ten_label.
    Chỉ trả về bản ghi active (is_deleted = 0).
    """
    if _DB_POOL is None:
        print("[database.py] ERROR: Connection pool is not available.")
        return None

    connection = None
    cursor = None

    try:
        connection = _DB_POOL.get_connection()
        cursor = connection.cursor(dictionary=True)

        sql = (
            "SELECT ten_cay, ten_quocte, thong_tin, cong_dung, cach_dung, luu_y, anh_minh_hoa "
            "FROM plant_medical "
            f"WHERE ten_label = %s {_WHERE_ACTIVE}"
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
            "Tên cây": result.get("ten_cay"),
            "Tên quốc tế": result.get("ten_quocte"),
            "Thông tin": result.get("thong_tin"),
            "Công dụng": result.get("cong_dung"),
            "Cách dùng": result.get("cach_dung"),
            "Lưu ý": result.get("luu_y"),
            "anh_minh_hoa": result.get("anh_minh_hoa"),
        }
    return None


# ---------------------------------------------------------------------------
# 2. get_top_matches — dùng cho /predict (batched lookup Top-K)
# ---------------------------------------------------------------------------
def get_top_matches(labels: list[str]) -> dict:
    """Batched lookup cho kết quả Top-K từ model AI.
    Returns a dict keyed by ten_label for O(1) lookup.
    """
    if _DB_POOL is None:
        print("[database.py] ERROR: Connection pool is not available.")
        return {}

    if not labels:
        return {}

    connection = None
    cursor = None
    try:
        connection = _DB_POOL.get_connection()
        cursor = connection.cursor(dictionary=True)

        placeholders = ", ".join(["%s"] * len(labels))
        sql = (
            f"SELECT ten_label, ten_cay, ten_quocte, anh_minh_hoa "
            f"FROM plant_medical "
            f"WHERE ten_label IN ({placeholders}) {_WHERE_ACTIVE}"
        )

        cursor.execute(sql, tuple(labels))
        rows = cursor.fetchall()
    except Error as err:
        print(f"[database.py] Batched query error for labels {labels}: {err}")
        return {}
    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None:
            connection.close()

    return {row["ten_label"]: row for row in rows}


# ---------------------------------------------------------------------------
# 3. search_plants — Live Search theo từ khoá (Full Match + Partial Match)
# ---------------------------------------------------------------------------
def search_plants(keyword: str, limit: int = 10) -> list[dict]:
    """Tìm kiếm cây thuốc theo 4 bước chuẩn hóa và phân cấp chính xác:

    Bước 1: Chuẩn hóa input (bỏ dấu, lowercase, trim khoảng trắng thừa).
    Bước 2: So sánh input đã chuẩn hóa với tên cây/tên gọi khác đã chuẩn hóa.
            Nếu có đúng 1 cây khớp CHÍNH XÁC (full match) -> return ngay
            mảng 1 phần tử đó, DỪNG xử lý.
    Bước 3: Nếu không có full match -> chạy partial match, phân hạng theo độ liên quan:
            - Ưu tiên 1: Khớp đầu chuỗi (starts with) tên cây/tên gọi khác
            - Ưu tiên 2: Chứa chuỗi (contains) trong tên cây/tên gọi khác
            - Ưu tiên 3: Khớp tên khoa học (ten_quocte)
            - Ưu tiên 4: Khớp công dụng / thông tin / cách dùng
    """
    if _DB_POOL is None:
        print("[database.py] ERROR: Connection pool is not available.")
        return []

    q_raw = (keyword or "").strip()
    if not q_raw:
        return []

    q_raw = q_raw[:_SEARCH_MAX_KEYWORD_LEN]
    q_norm = remove_vietnamese_tones(q_raw)
    if not q_norm:
        return []

    connection = None
    cursor = None
    try:
        connection = _DB_POOL.get_connection()
        cursor = connection.cursor(dictionary=True)

        cols = "ten_label, ten_cay, ten_quocte, cong_dung, thong_tin, cach_dung, anh_minh_hoa"
        if _HAS_TEN_CAY_NORMALIZED:
            cols += ", ten_cay_normalized"
        sql = f"SELECT {cols} FROM plant_medical WHERE 1=1 {_WHERE_ACTIVE}"
        cursor.execute(sql)
        rows = cursor.fetchall()
        if not rows:
            return []

        # Bước 2: So sánh input đã chuẩn hóa để tìm Full Match
        full_matches: list[dict] = []
        for row in rows:
            names = _get_plant_search_names(row)
            if q_norm in names:
                full_matches.append(row)

        if len(full_matches) == 1:
            match = full_matches[0]
            print(f"[database.py] search_plants: FULL MATCH for '{q_norm}' -> '{match.get('ten_label')}'")
            return [{
                "ten_label": match["ten_label"],
                "ten_cay": match.get("ten_cay"),
                "ten_quocte": match.get("ten_quocte"),
                "anh_minh_hoa": match.get("anh_minh_hoa"),
            }]

        # Bước 3: Phân hạng Partial Match theo thứ tự ưu tiên
        ranked_candidates: list[tuple[int, int, dict]] = []
        for row in rows:
            names = _get_plant_search_names(row)
            ten_cay_norm = names[0] if names else ""
            ten_quocte_norm = remove_vietnamese_tones(row.get("ten_quocte") or "")
            cong_dung_norm = remove_vietnamese_tones(row.get("cong_dung") or "")
            thong_tin_norm = remove_vietnamese_tones(row.get("thong_tin") or "")
            cach_dung_norm = remove_vietnamese_tones(row.get("cach_dung") or "")

            priority: int | None = None
            if any(name.startswith(q_norm) for name in names):
                priority = 1
            elif any(q_norm in name for name in names):
                priority = 2
            elif q_norm in ten_quocte_norm:
                priority = 3
            elif q_norm in cong_dung_norm or q_norm in thong_tin_norm or q_norm in cach_dung_norm:
                priority = 4

            if priority is not None:
                ranked_candidates.append((priority, len(ten_cay_norm), row))

        ranked_candidates.sort(key=lambda item: (item[0], item[1]))

        max_limit = min(limit, _SEARCH_MAX_LIMIT) if limit else 10
        results = [
            {
                "ten_label": item[2]["ten_label"],
                "ten_cay": item[2].get("ten_cay"),
                "ten_quocte": item[2].get("ten_quocte"),
                "anh_minh_hoa": item[2].get("anh_minh_hoa"),
            }
            for item in ranked_candidates[:max_limit]
        ]
        print(f"[database.py] search_plants: PARTIAL MATCH ({len(results)} plants) for '{q_norm}'")
        return results

    except Error as err:
        print(f"[database.py] search_plants error for keyword '{keyword}': {err}")
        return []
    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None:
            connection.close()


# ---------------------------------------------------------------------------
# 4. search_keywords — gợi ý cụm từ cho Live Search Suggestions
# ---------------------------------------------------------------------------
_SUGGESTIONS_MAX_LIMIT = 5


def search_keywords(keyword: str, limit: int = _SUGGESTIONS_MAX_LIMIT) -> list[dict]:
    """Tìm cụm từ gợi ý từ bảng search_keywords khớp với keyword.
    Dùng LIKE trên keyword_normalized. Chỉ trả về is_active = 1.
    """
    if _DB_POOL is None:
        print("[database.py] ERROR: Connection pool is not available.")
        return []

    keyword = (keyword or "").strip()
    if not keyword:
        return []

    keyword = keyword[:_SEARCH_MAX_KEYWORD_LEN]
    limit = max(1, min(limit, _SUGGESTIONS_MAX_LIMIT))

    keyword_norm = _normalize_vietnamese(keyword)
    norm_pattern = f"%{keyword_norm}%"

    connection = None
    cursor = None
    try:
        connection = _DB_POOL.get_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            "SELECT keyword "
            "FROM search_keywords "
            "WHERE is_active = 1 AND keyword_normalized LIKE %s "
            "ORDER BY "
            "  CASE WHEN keyword_normalized LIKE %s THEN 0 ELSE 1 END, "
            "  LENGTH(keyword) "
            "LIMIT %s",
            (norm_pattern, f"{keyword_norm}%", limit),
        )
        rows = cursor.fetchall()
        print(f"[database.py] search_keywords: {len(rows)} gợi ý cho '{keyword}'")
        return list(rows)

    except Error as err:
        print(f"[database.py] search_keywords error for '{keyword}': {err}")
        return []
    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None:
            connection.close()


# ---------------------------------------------------------------------------
# 5. get_system_plants_in_bounds — Lấy cây hệ thống trong Bounding Box
# ---------------------------------------------------------------------------
def get_system_plants_in_bounds(
    min_lat: float,
    max_lat: float,
    min_lng: float,
    max_lng: float,
    limit: int = 500,
) -> list[dict]:
    """Lấy danh sách cây hệ thống (MySQL) nằm trong bounding box địa lý.

    JOIN bảng system_plant_locations với plant_medical để trả về đầy đủ
    thông tin cây cần thiết cho bản đồ.

    Args:
        min_lat: Vĩ độ cực Nam (bottom boundary).
        max_lat: Vĩ độ cực Bắc (top boundary).
        min_lng: Kinh độ cực Tây (left boundary).
        max_lng: Kinh độ cực Đông (right boundary).
        limit:   Số lượng tối đa (mặc định 500, chống DDoS).

    Returns:
        List các dict với các key:
            ten_label, ten_cay, ten_quocte, thong_tin, anh_minh_hoa,
            latitude, longitude, address_name.
        Trả về list rỗng nếu lỗi hoặc không có dữ liệu.
    """
    if _DB_POOL is None:
        print("[database.py] ERROR: Connection pool is not available.")
        return []

    connection = None
    cursor = None
    try:
        connection = _DB_POOL.get_connection()
        cursor = connection.cursor(dictionary=True)

        sql = """
            SELECT
                spl.id AS location_id,
                spl.plant_id,
                pm.ten_label,
                pm.ten_cay,
                pm.ten_quocte,
                pm.thong_tin,
                pm.anh_minh_hoa,
                spl.latitude,
                spl.longitude,
                spl.address_name
            FROM system_plant_locations AS spl
            INNER JOIN plant_medical AS pm
                ON spl.plant_id = pm.ID
            WHERE
                spl.latitude  BETWEEN %s AND %s
                AND spl.longitude BETWEEN %s AND %s
                {where_active}
            ORDER BY spl.id
            LIMIT %s
        """.format(
            where_active=(
                "AND pm.is_deleted = 0" if _HAS_IS_DELETED else ""
            )
        )

        cursor.execute(sql, (min_lat, max_lat, min_lng, max_lng, limit))
        rows = cursor.fetchall()

        print(
            f"[database.py] get_system_plants_in_bounds: "
            f"bbox=[{min_lat},{max_lat},{min_lng},{max_lng}] → {len(rows)} cây"
        )
        return rows

    except Error as err:
        print(f"[database.py] get_system_plants_in_bounds error: {err}")
        return []
    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None:
            connection.close()