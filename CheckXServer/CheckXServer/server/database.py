import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager

# Datenbank-Konfiguration
DB_CONFIG = {
    "dbname": "checkx_db",
    "user": "postgres",
    "password": "KevSebKB020012", 
    "host": "localhost",
    "port": "5432"
}

# Initialisierung des Connection Pools (min 1, max 10 Verbindungen)
try:
    connection_pool = psycopg2.pool.ThreadedConnectionPool(
        1, 10, **DB_CONFIG, cursor_factory=RealDictCursor
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
        # Dies stellt sicher, dass die Verbindung IMMER zurückgegeben wird
        connection_pool.putconn(conn)