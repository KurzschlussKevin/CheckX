import psycopg2
from psycopg2.extras import RealDictCursor

DB_CONFIG = {
    "dbname": "checkx_db",
    "user": "postgres",
    "password": "KevSebKB020012", 
    "host": "localhost",
    "port": "5432"
}

def get_db_conn():
    return psycopg2.connect(**DB_CONFIG, cursor_factory=RealDictCursor)