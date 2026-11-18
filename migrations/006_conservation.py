"""Run explicitly before deploying public conservation endpoints."""
import os
import mysql.connector
from dotenv import load_dotenv
load_dotenv()

def main():
    conn = mysql.connector.connect(host=os.environ["DB_HOST"], user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"], database=os.environ["DB_NAME"])
    cur = conn.cursor()
    try:
        cur.execute("SHOW COLUMNS FROM plant_medical")
        existing = {row[0] for row in cur.fetchall()}
        columns = {
            "is_protected": "TINYINT(1) NOT NULL DEFAULT 1",
            "protection_level": "VARCHAR(100) NULL",
            "fuzzing_radius_meters": "INT NOT NULL DEFAULT 8000",
            "conservation_notes": "TEXT NULL",
            "updated_by": "VARCHAR(100) NULL",
            "protected_at": "DATETIME NULL",
        }
        for name, definition in columns.items():
            if name not in existing:
                cur.execute(f"ALTER TABLE plant_medical ADD COLUMN {name} {definition}")
        conn.commit()
    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    main()
