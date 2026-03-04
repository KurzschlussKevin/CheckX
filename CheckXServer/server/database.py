import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
import os
from dotenv import load_dotenv

# Lädt .env Variablen
load_dotenv()

# Datenbank-Konfiguration aus Umgebungsvariablen laden
DB_CONFIG = {
    "dbname": os.getenv("DB_NAME", "checkx_db"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"), 
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432")
}

# Sicherheitscheck
if not DB_CONFIG["password"]:
    raise RuntimeError("FEHLER: DB_PASSWORD ist nicht in der .env gesetzt!")

# Initialisierung des Connection Pools (min 2, max 20 für bessere Skalierbarkeit)
try:
    connection_pool = psycopg2.pool.ThreadedConnectionPool(
        2, 20, **DB_CONFIG, cursor_factory=RealDictCursor
    )
    print("Datenbank-Pool erfolgreich initialisiert.")
except Exception as e:
    print(f"Fehler beim Initialisieren des DB-Pools: {e}")

@contextmanager
def get_db_connection():
    """Holt eine Verbindung aus dem Pool und gibt sie sicher zurück."""
    conn = connection_pool.getconn()
    try:
        yield conn
    finally:
        connection_pool.putconn(conn)