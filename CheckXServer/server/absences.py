from fastapi import HTTPException
from database import get_db_conn
from datetime import datetime

# 1. Urlaub beantragen mit Mapping für den Datenbank-Enum
def create_vacation_request(data):
    conn = get_db_conn()
    cur = conn.cursor()
    
    # MAPPING: UI-Text (Godot) -> DB-Enum (Postgres)
    # Hier werden alle moeglichen Texte aus deinem Godot-OptionButton abgefangen
    type_mapping = {
        "erholungsurlaub": "erholung",
        "sonderurlaub": "sonderurlaub",
        "krankheit": "krankheit",
        "gleitzeit": "gleitzeit"
    }
    
    # Wert umwandeln oder Standard 'erholung' nutzen
    raw_type = data.vacation_type.lower()
    db_type = type_mapping.get(raw_type, "erholung")
    
    try:
        cur.execute("""
            INSERT INTO absences (employee_id, start_date, end_date, type, status)
            VALUES (
                (SELECT id FROM employees WHERE emp_id = %s), 
                %s, %s, %s, 'pending'
            )
        """, (data.emp_id, data.start_date, data.end_date, db_type))
        
        conn.commit()
        return {"status": "success", "message": "Urlaubsantrag eingereicht."}
    except Exception as e:
        conn.rollback()
        print(f"Fehler in create_vacation_request: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

# 2. Alle offenen Anträge für den Admin auflisten
def get_pending_requests():
    conn = get_db_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT a.id, e.first_name, e.last_name, e.emp_id, a.start_date, a.end_date, a.type
        FROM absences a
        JOIN employees e ON a.employee_id = e.id
        WHERE a.status = 'pending'
        ORDER BY a.created_at ASC
    """)
    requests = cur.fetchall()
    conn.close()
    return requests

# 3. Antrag bestätigen oder ablehnen
def update_absence_status(absence_id: int, new_status: str, admin_emp_id: str):
    conn = get_db_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE absences 
            SET status = %s, 
                approved_by = (SELECT id FROM employees WHERE emp_id = %s)
            WHERE id = %s
        """, (new_status, admin_emp_id, absence_id))
        conn.commit()
        return {"status": "success"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()