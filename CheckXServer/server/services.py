from database import get_db_connection  # Geändert von get_db_conn auf get_db_connection
from fastapi import HTTPException
from pydantic import BaseModel
from typing import Optional, List

class ServiceModel(BaseModel):
    id: Optional[int] = None
    name: str
    description: Optional[str] = ""

def init_services_table():
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS services (
                id SERIAL PRIMARY KEY,
                name VARCHAR(200) NOT NULL UNIQUE,
                description TEXT,
                active BOOLEAN DEFAULT TRUE
            );
        """)
        # Beispiel-Daten
        cur.execute("SELECT count(*) as cnt FROM services")
        if cur.fetchone()['cnt'] == 0:
            cur.execute("""
                INSERT INTO services (name) VALUES 
                ('Ortsveränderliche Geräte 230V'),
                ('Ortsveränderliche Geräte 400V'),
                ('Leitungsroller 230V'),
                ('Verteiler Pauschale 12'),
                ('Maschine TYP A')
            """)
            conn.commit()
        conn.commit()

def get_all_services():
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM services WHERE active = true ORDER BY name ASC")
        return cur.fetchall()

def create_service(service: ServiceModel):
    with get_db_connection() as conn:
        cur = conn.cursor()
        try:
            cur.execute("INSERT INTO services (name, description) VALUES (%s, %s) RETURNING id", 
                       (service.name, service.description))
            new_id = cur.fetchone()['id']
            conn.commit()
            return {"status": "success", "id": new_id, "message": "Leistungstyp angelegt"}
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail="Fehler: Name existiert evtl. schon.")