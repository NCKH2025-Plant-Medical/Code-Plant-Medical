"""Read only access to content published by the independent admin service."""

import json

try:
    import database
except ImportError:
    from API import database


def _connection():
    if database._DB_POOL is None:
        raise RuntimeError("MySQL catalog is unavailable")
    return database._DB_POOL.get_connection()


def published_aliases(plant_ids):
    ids = list(dict.fromkeys(int(value) for value in plant_ids))
    if not ids:
        return {}
    conn = _connection()
    cursor = None
    try:
        cursor = conn.cursor(dictionary=True)
        placeholders = ",".join(["%s"] * len(ids))
        cursor.execute(
            "SELECT plant_id, alias_normalized FROM plant_alias "
            f"WHERE is_active=1 AND plant_id IN ({placeholders})",
            tuple(ids),
        )
        result = {}
        for row in cursor.fetchall():
            result.setdefault(row["plant_id"], []).append(row["alias_normalized"])
        return result
    finally:
        if cursor:
            cursor.close()
        conn.close()


def published_warnings(plant_id):
    conn = _connection()
    cursor = None
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "SELECT e.id,e.plant_a_id,e.plant_b_id,e.published, "
            "a.ten_cay AS plant_a_name,a.ten_quocte AS plant_a_scientific, "
            "b.ten_cay AS plant_b_name,b.ten_quocte AS plant_b_scientific "
            "FROM admin_lookalike_pairs e "
            "JOIN plant_medical a ON a.ID=e.plant_a_id AND a.is_deleted=0 "
            "JOIN plant_medical b ON b.ID=e.plant_b_id AND b.is_deleted=0 "
            "WHERE e.published IS NOT NULL AND (e.plant_a_id=%s OR e.plant_b_id=%s)",
            (plant_id, plant_id),
        )
        warnings = []
        for row in cursor.fetchall():
            content = row["published"]
            if isinstance(content, str):
                content = json.loads(content)
            other_a = row["plant_a_id"] != plant_id
            warnings.append({
                "risk_level": content["risk_level"],
                "warning_text": content["warning_text"],
                "source": content["source"],
                "distinguishing_features": content.get("distinguishing_features", []),
                "images": content.get("images", []),
                "other_plant": {
                    "plant_id": row["plant_a_id"] if other_a else row["plant_b_id"],
                    "common_name": row["plant_a_name"] if other_a else row["plant_b_name"],
                    "scientific_name": row["plant_a_scientific"] if other_a else row["plant_b_scientific"],
                },
            })
        return warnings
    finally:
        if cursor:
            cursor.close()
        conn.close()


def published_profile_details(plant_id):
    conn = _connection()
    cursor = None
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "SELECT family,parts_used,contraindications,source_reference "
            "FROM admin_profile_details WHERE plant_id=%s", (plant_id,)
        )
        return cursor.fetchone() or {}
    finally:
        if cursor:
            cursor.close()
        conn.close()
