from database import get_db_conn
from datetime import datetime
from fastapi import HTTPException

# --- TIMER FUNKTIONEN ---

def start_timer(data):
    conn = get_db_conn()
    cur = conn.cursor()
    
    # Prüfen, ob für diesen User bereits ein Timer läuft
    cur.execute("SELECT id FROM time_entries WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s) AND status = 'running'", (data.emp_id,))
    if cur.fetchone():
        conn.close()
        raise HTTPException(status_code=400, detail="Timer läuft bereits!")

    start_dt = datetime.fromtimestamp(data.start_time)
    
    # Neuen Eintrag erstellen (immer 'open' und ungesperrt am Anfang)
    cur.execute("""
        INSERT INTO time_entries (employee_id, project, start_time, status, approval_status, is_locked)
        VALUES ((SELECT id FROM employees WHERE emp_id = %s), %s, %s, 'running', 'open', FALSE)
    """, (data.emp_id, data.project, start_dt))
    
    conn.commit()
    conn.close()
    return {"status": "started"}

def stop_timer(data):
    conn = get_db_conn()
    cur = conn.cursor()
    end_dt = datetime.fromtimestamp(data.end_time)
    
    # Timer beenden und Dauer berechnen
    cur.execute("""
        UPDATE time_entries 
        SET end_time = %s, notes = %s, status = 'open',
            duration_minutes = EXTRACT(EPOCH FROM (%s - start_time))/60
        WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s) 
        AND status = 'running'
    """, (end_dt, data.notes, end_dt, data.emp_id))
    
    conn.commit()
    conn.close()
    return {"status": "stopped"}

# --- MANUELLE EINGABE ---

def add_manual_entry(emp_id, date_str, duration_mins, project):
    # ZUERST: Prüfen, ob der Tag gesperrt ist!
    if check_is_locked(emp_id, date_str)["is_locked"]:
        return {"status": "error", "message": "Dieser Tag ist bereits eingereicht oder genehmigt. Keine Änderungen mehr möglich."}

    conn = get_db_conn()
    cur = conn.cursor()
    try:
        # Wir setzen Start auf 08:00 und berechnen Ende automatisch
        start_ts_str = f"{date_str} 08:00:00"
        
        # HIER WAR DER FEHLER: Wir haben am Ende der execute-Funktion EINMAL zu viel 'duration_mins' übergeben!
        cur.execute("""
            INSERT INTO time_entries (employee_id, project, start_time, end_time, notes, status, duration_minutes, approval_status, is_locked)
            VALUES (
                (SELECT id FROM employees WHERE emp_id = %s), 
                %s, 
                %s::timestamp, 
                (%s::timestamp + (%s || ' minutes')::interval),
                'Manuelle Nacherfassung',
                'open',
                %s,
                'open',
                FALSE
            )
        """, (emp_id, project, start_ts_str, start_ts_str, duration_mins, duration_mins)) # <--- Hier waren vorher 7 statt 6 Variablen!
        
        conn.commit()
        return {"status": "success"}
    except Exception as e:
        print(f"Fehler bei manueller Zeit: {e}")
        return {"status": "error", "message": str(e)}
    finally:
        conn.close()

# --- STATISTIKEN & CHECK ---

def get_daily_stats(emp_id, date_str):
    conn = get_db_conn()
    cur = conn.cursor()
    try:
        # Summiere die Minuten für den Tag
        cur.execute("""
            SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (end_time - start_time))/60), 0) as total_mins
            FROM time_entries 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date
            AND end_time IS NOT NULL
        """, (emp_id, date_str))
        
        row = cur.fetchone()
        minutes = int(row['total_mins']) if row else 0
        return {"total_minutes": minutes}
    except Exception as e:
        return {"total_minutes": 0}
    finally:
        conn.close()

def check_is_locked(emp_id, date_str):
    """Prüft, ob ein Tag für Bearbeitung gesperrt ist."""
    conn = get_db_conn()
    cur = conn.cursor()
    try:
        # Ein Tag ist gesperrt, wenn:
        # 1. Das Feld 'is_locked' TRUE ist (Admin-Sperre)
        # 2. ODER der Status 'submitted' (Eingereicht) ist
        # 3. ODER der Status 'approved' (Genehmigt) ist
        cur.execute("""
            SELECT 1 FROM time_entries 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date
            AND (is_locked = TRUE OR approval_status IN ('submitted', 'approved'))
            LIMIT 1
        """, (emp_id, date_str))
        row = cur.fetchone()
        return {"is_locked": True if row else False}
    finally:
        conn.close()

# --- WORKFLOW & FREIGABE ---

def submit_day(emp_id, date_str):
    """Mitarbeiter reicht den Tag ein."""
    conn = get_db_conn()
    cur = conn.cursor()
    try:
        # Check: Timer darf an DIESEM TAG nicht laufen
        cur.execute("""
            SELECT 1 FROM time_entries 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date 
            AND status = 'running'
        """, (emp_id, date_str))
        if cur.fetchone():
             return {"status": "error", "message": f"Bitte erst den laufenden Timer für den {date_str} stoppen!"}

        # Status auf 'submitted' setzen
        cur.execute("""
            UPDATE time_entries 
            SET approval_status = 'submitted'
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date
            AND approval_status = 'open'
        """, (emp_id, date_str))
        
        if cur.rowcount == 0:
            return {"status": "error", "message": "Keine offenen Zeiten für diesen Tag in der Datenbank gefunden!"}

        conn.commit()
        return {"status": "success", "message": "Tag eingereicht"}
    except Exception as e:
        return {"status": "error", "message": str(e)}
    finally:
        conn.close()

def admin_approve_full_day(emp_id, date_str):
    """Admin bestätigt den Tag -> endgültig gesperrt."""
    conn = get_db_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE time_entries 
            SET approval_status = 'approved', is_locked = TRUE 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date
        """, (emp_id, date_str))
        conn.commit()
        return {"status": "success"}
    except Exception as e:
        return {"status": "error", "message": str(e)}
    finally:
        conn.close()

def request_correction(emp_id, date_str, note):
    """Setzt den Status auf 'correction_requested', damit der User wieder bearbeiten kann (oder Admin benachrichtigt wird)."""
    conn = get_db_conn()
    cur = conn.cursor()
    try:
        # Wir setzen den Status zurück auf 'correction_requested' und entsperren (is_locked = FALSE)
        cur.execute("""
            UPDATE time_entries 
            SET approval_status = 'correction_requested', is_locked = FALSE, notes = notes || ' [Korrektur: ' || %s || ']'
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date
        """, (note, emp_id, date_str))
        conn.commit()
        return {"status": "success", "message": "Korrektur beantragt. Tag ist wieder offen."}
    except Exception as e:
        return {"status": "error", "message": str(e)}
    finally:
        conn.close()

def get_locked_days_for_month(emp_id, month, year):
    conn = get_db_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            SELECT DISTINCT TO_CHAR(start_time, 'YYYY-MM-DD') as d
            FROM time_entries 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND EXTRACT(MONTH FROM start_time) = %s
            AND EXTRACT(YEAR FROM start_time) = %s
            AND (is_locked = TRUE OR approval_status IN ('submitted', 'approved'))
        """, (emp_id, month, year))
        
        rows = cur.fetchall()
        # Datum-Strings extrahieren
        locked_dates = [row['d'] for row in rows if row['d']]
        return {"locked_days": locked_dates}
    except Exception as e:
        print(f"Fehler bei get_locked_days_for_month: {e}")
        return {"locked_days": []}
    finally:
        conn.close()