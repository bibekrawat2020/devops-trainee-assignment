import os
import random
import socket
from datetime import datetime

import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)

DATABASE_URL = os.environ.get("DATABASE_URL")

QUOTES = [
    "It's not a bug, it's an undocumented feature.",
    "Works on my machine.",
    "There are only two hard things in Computer Science: cache invalidation, naming things, and off-by-one errors.",
    "A server walked into a bar. Nobody noticed - it had 99.999% uptime.",
    "Friends don't let friends deploy on a Friday.",
    "The cloud is just someone else's computer... that you're paying by the hour.",
    "chmod 777 fixes everything. Fight me.",
    "In case of fire: git commit, git push, then evacuate.",
    "YAML: where one wrong space ruins your whole week.",
    "99 little bugs in the code, 99 little bugs. Take one down, patch it around, 127 little bugs in the code.",
]


def get_db_connection():
    return psycopg2.connect(DATABASE_URL, connect_timeout=3)


def init_db():
    """Create the visits table if it doesn't exist yet."""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS visits (
                id SERIAL PRIMARY KEY,
                visited_at TIMESTAMP DEFAULT NOW()
            );
            """
        )
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print(f"DB init skipped (will retry on next request): {e}")


def record_visit_and_count():
    """Insert a visit row and return the running total. Returns None if DB is down."""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("INSERT INTO visits DEFAULT VALUES;")
        cur.execute("SELECT COUNT(*) FROM visits;")
        total = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        return total
    except Exception:
        return None


def check_db():
    try:
        conn = get_db_connection()
        conn.close()
        return True
    except Exception:
        return False


@app.route("/")
def oracle():
    visit_count = record_visit_and_count()
    return jsonify(
        oracle_says=random.choice(QUOTES),
        served_by_host=socket.gethostname(),
        timestamp=datetime.utcnow().isoformat() + "Z",
        total_visits=visit_count if visit_count is not None else "unavailable (db unreachable)",
        db_connected=visit_count is not None,
    )


@app.route("/healthz")
def healthz():
    ok = check_db()
    status = 200 if ok else 503
    return jsonify(status="ok" if ok else "degraded", db_connected=ok), status


init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)