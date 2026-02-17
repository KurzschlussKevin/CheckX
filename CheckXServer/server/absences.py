from fastapi import HTTPException
from database import get_db_conn
from datetime import datetime

def create_vacation_request(data):
    conn = get_db_conn()
    cur = conn.cursor()
    
    # 1. Interne ID des Mitarbeiters anhand der emp_id (P-XXXX) finden
    cur.execute("SELECT id FROM employees WHERE emp_id = %s", (data.emp_id,))
    emp_row = cur.fetchone()
    
    if not emp_row:
        conn.close()
        print(f"Fehler: Mitarbeiter {data.emp_id} nicht gefunden.")
        raise HTTPException(status_code=404, detail="Mitarbeiter nicht gefunden")

    internal_id = emp_row['id']
    
    # 2. Mapping für Datenbank-Enums (UI-Text -> DB-Wert)
    type_mapping = {
        "erholungsurlaub": "erholung",
        "sonderurlaub": "sonderurlaub",
        "krankheit": "krankheit",
        "gleitzeit": "gleitzeit"
    }
    db_type = type_mapping.get(data.vacation_type.lower(), "erholung")

    try:
        cur.execute("""
            INSERT INTO absences (employee_id, start_date, end_date, type, status)
            VALUES (%s, %s, %s, %s, 'pending')
        """, (internal_id, data.start_date, data.end_date, db_type))
        
        conn.commit()
        return {"status": "success", "message": "Urlaubsantrag eingereicht."}
    except Exception as e:
        conn.rollback()
        print(f"Datenbankfehler: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

def get_pending_requests():
    conn = get_db_conn()
    cur = conn.cursor()
    # JOIN stellt sicher, dass nur Anträge mit existierenden Mitarbeitern geladen werden
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

def update_absence_status(absence_id, new_status, admin_emp_id):
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

def get_user_absences(emp_id):
    conn = get_db_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT start_date, end_date, type, status 
        FROM absences 
        WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
        ORDER BY start_date DESC
    """, (emp_id,))
    data = cur.fetchall()
    conn.close()
    return data

def get_all_approved_absences():
    conn = get_db_conn()
    cur = conn.cursor()
    # Wir laden Namen, Zeitraum und Typ für den Team-Kalender
    cur.execute("""
        SELECT e.first_name, e.last_name, a.start_date, a.end_date, a.type
        FROM absences a
        JOIN employees e ON a.employee_id = e.id
        WHERE a.status = 'approved'
        ORDER BY a.start_date ASC
    """)
    data = cur.fetchall()
    conn.close()
    return data