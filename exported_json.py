# =============================================================================
# export_seed.py
#
# Standalone utility script — run once before Flutter handover.
#
# Purpose:
#   Query all ACTIVE records from the `plant_medical` MySQL table and export
#   them as a UTF-8 encoded JSON array.  The output file (`data.json`) is
#   handed to the Flutter team to seed their local Drift/SQLite database for
#   offline-first operation in the field.
#
# Usage:
#   python export_seed.py
#
# Output:
#   data.json  — written in the same directory as this script.
#
# Requirements:
#   pip install mysql-connector-python
# =============================================================================

import json
import os
import sys
from datetime import datetime

import mysql.connector
from mysql.connector import Error

# ---------------------------------------------------------------------------
# Database connection config
# Must match the credentials in database.py exactly.
# ---------------------------------------------------------------------------
_DB_CONFIG = {
    "host":     "localhost",
    "user":     "root",
    "password": "minhtriet",
    "database": "plant_project",
}

# ---------------------------------------------------------------------------
# Output path — data.json lands in the same directory as this script.
# Change OUTPUT_PATH if you want it somewhere else (e.g. the Flutter assets/).
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Output path — Đẩy data.json thẳng vào thư mục exported_models.
# ---------------------------------------------------------------------------
# 1. Xác định đường dẫn tới thư mục exported_models
# 1. Lùi ra ngoài 1 cấp (từ thư mục API ra thư mục NCKH), rồi trỏ vào exported_models đã có sẵn
models_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "exported_models")

# 2. Chốt đường dẫn cuối cùng cho file data.json
OUTPUT_PATH = os.path.join(models_dir, "data.json")

# ---------------------------------------------------------------------------
# SQL — select only active, non-deleted plant records.
#
# Columns are listed explicitly (no SELECT *) so the order is deterministic
# and won't break if someone adds a column to the table later.
# ---------------------------------------------------------------------------
_SQL = """
    SELECT
        ID,
        ten_label,
        ten_cay,
        ten_quocte,
        thong_tin,
        cong_dung,
        cach_dung,
        luu_y,
        updated_at,
        is_deleted
    FROM plant_medical
    WHERE is_deleted = 0
    ORDER BY ID ASC
"""


def export_seed() -> None:
    """
    Connect to MySQL, query active plant records, and write them to data.json.

    Each row is serialised as a dict with the original column names as keys.
    The `updated_at` timestamp is converted to an ISO 8601 string so Flutter
    can parse it unambiguously with DateTime.parse().

    Exits with a non-zero status code on any database or I/O error so that
    CI pipelines or shell scripts can detect failure.
    """
    connection = None
    cursor     = None

    try:
        # ------------------------------------------------------------------
        # Step 1: Open a direct (non-pooled) connection.
        # A pool would be overkill for a one-shot export script; a single
        # connection is simpler and closes cleanly in the finally block.
        # ------------------------------------------------------------------
        print("[export_seed] Connecting to MySQL...")
        connection = mysql.connector.connect(**_DB_CONFIG)
        print(f"[export_seed] Connected to '{_DB_CONFIG['database']}' on {_DB_CONFIG['host']}.")

        # dictionary=True returns each row as {column_name: value} — no index juggling.
        cursor = connection.cursor(dictionary=True)

        # ------------------------------------------------------------------
        # Step 2: Run the query.
        # ------------------------------------------------------------------
        print("[export_seed] Querying active plant records (is_deleted = 0)...")
        cursor.execute(_SQL)
        rows = cursor.fetchall()
        print(f"[export_seed] {len(rows)} record(s) retrieved.")

        if not rows:
            print("[export_seed] WARNING: No active records found. data.json will contain an empty array.")

        # ------------------------------------------------------------------
        # Step 3: Post-process each row for JSON serialisation.
        #
        # mysql.connector returns `updated_at` as a Python datetime object.
        # json.dumps() cannot serialise datetime natively, so we convert it
        # to an ISO 8601 string here (e.g. "2026-06-15T14:27:41").
        # Flutter parses this with DateTime.parse(row['updated_at']).
        #
        # `is_deleted` comes back as an int (0 or 1) from tinyint(1).
        # We keep it as-is; Drift maps it to bool on the Flutter side.
        # ------------------------------------------------------------------
        serialisable_rows = []
        for row in rows:
            # Convert datetime → ISO 8601 string
            if isinstance(row.get("updated_at"), datetime):
                row["updated_at"] = row["updated_at"].isoformat()

            serialisable_rows.append(row)

        # ------------------------------------------------------------------
        # Step 4: Write data.json with UTF-8 encoding.
        #
        # ensure_ascii=False is MANDATORY — without it, json.dumps() would
        # escape every Vietnamese character as \uXXXX sequences, making the
        # file unreadable by humans and ~3× larger on disk.
        #
        # indent=2 makes the file git-diffable and easy to inspect by hand.
        # ------------------------------------------------------------------
        print(f"[export_seed] Writing output to: {OUTPUT_PATH}")
        with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
            json.dump(serialisable_rows, f, ensure_ascii=False, indent=2)

        # ------------------------------------------------------------------
        # Step 5: Confirm and summarise.
        # ------------------------------------------------------------------
        file_size_kb = os.path.getsize(OUTPUT_PATH) / 1024
        print("=" * 55)
        print("EXPORT COMPLETE")
        print(f"  Records exported : {len(serialisable_rows)}")
        print(f"  Output file      : {OUTPUT_PATH}")
        print(f"  File size        : {file_size_kb:.1f} KB")
        print("=" * 55)
        print("Hand the following file to the Flutter team:")
        print(f"  → data.json  ({len(serialisable_rows)} plants, UTF-8, ISO 8601 timestamps)")

    except Error as db_err:
        print(f"[export_seed] DATABASE ERROR: {db_err}")
        sys.exit(1)

    except OSError as io_err:
        print(f"[export_seed] FILE I/O ERROR: {io_err}")
        sys.exit(1)

    finally:
        # Always release database resources, even on exception.
        if cursor is not None:
            cursor.close()
        if connection is not None and connection.is_connected():
            connection.close()
            print("[export_seed] MySQL connection closed.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    export_seed()