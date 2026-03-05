import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
import os
from dotenv import load_dotenv

load_dotenv()

DB_CONFIG = {
    "dbname": os.getenv("DB_NAME", "checkx_db"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"), 
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432")
}

if not DB_CONFIG["password"]:
    raise RuntimeError("FEHLER: DB_PASSWORD ist nicht in der .env gesetzt!")

try:
    connection_pool = psycopg2.pool.ThreadedConnectionPool(
        2, 20, **DB_CONFIG, cursor_factory=RealDictCursor
    )
    print("Datenbank-Pool erfolgreich initialisiert.")
except Exception as e:
    print(f"FATALER FEHLER beim Initialisieren des DB-Pools: {e}")
    raise RuntimeError(f"Datenbankverbindung fehlgeschlagen: {e}")

@contextmanager
def get_db_connection():
    """Holt eine Verbindung aus dem Pool und gibt sie sicher zurück."""
    conn = connection_pool.getconn()
    try:
        yield conn
    finally:
        # KORREKTUR: Immer Rollback aufrufen, um offene (Lese-)Transaktionen 
        # sicher zu beenden, bevor die Connection zurück in den Pool geht.
        # Commit wurde ggf. schon im Erfolgsfall vom Nutzer aufgerufen.
        try:
            conn.rollback()
        except Exception:
            pass
        connection_pool.putconn(conn)