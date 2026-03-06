from database import get_db_connection  # Geändert von get_db_conn auf get_db_connection
from fastapi import HTTPException
from pydantic import BaseModel
from typing import List, Optional

# --- MODELLE ---
class TemplateItem(BaseModel):
    service_id: int
    target_amount: int
    price: float

class TemplateCreate(BaseModel):
    name: str
    items: List[TemplateItem]

# --- INIT ---
def init_templates_table():
    with get_db_connection() as conn:
        cur = conn.cursor()
        
        # Tabelle für den Vorlagen-Namen
        cur.execute("""
            CREATE TABLE IF NOT EXISTS templates (
                id SERIAL PRIMARY KEY,
                name VARCHAR(150) NOT NULL UNIQUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        
        # Tabelle für den Inhalt der Vorlage
        cur.execute("""
            CREATE TABLE IF NOT EXISTS template_items (
                id SERIAL PRIMARY KEY,
                template_id INTEGER REFERENCES templates(id) ON DELETE CASCADE,
                service_id INTEGER REFERENCES services(id) ON DELETE CASCADE,
                default_amount INTEGER DEFAULT 0,
                default_price DECIMAL(10, 2) DEFAULT 0.00
            );
        """)
        conn.commit()

# --- API ---
def get_all_templates():
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT id, name FROM templates ORDER BY name ASC")
        return cur.fetchall()

def get_template_details(template_id: int):
    with get_db_connection() as conn:
        cur = conn.cursor()
        # Wir holen die Items und joinen die Service-Namen dazu
        cur.execute("""
            SELECT t.service_id, s.name, t.default_amount, t.default_price
            FROM template_items t
            JOIN services s ON t.service_id = s.id
            WHERE t.template_id = %s
        """, (template_id,))
        return cur.fetchall()

def create_template(data: TemplateCreate):
    with get_db_connection() as conn:
        cur = conn.cursor()
        try:
            # 1. Vorlage erstellen
            cur.execute("INSERT INTO templates (name) VALUES (%s) RETURNING id", (data.name,))
            tid = cur.fetchone()['id']
            
            # 2. Items einfügen
            for item in data.items:
                cur.execute("""
                    INSERT INTO template_items (template_id, service_id, default_amount, default_price)
                    VALUES (%s, %s, %s, %s)
                """, (tid, item.service_id, item.target_amount, item.price))
                
            conn.commit()
            return {"status": "success", "id": tid, "message": "Vorlage gespeichert"}
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=str(e))