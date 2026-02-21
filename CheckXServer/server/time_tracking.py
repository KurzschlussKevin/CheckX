from database import get_db_connection # Geändert von get_db_conn auf get_db_connection
from datetime import datetime
from fastapi import HTTPException
import psycopg2

# --- TIMER FUNKTIONEN ---

def start_timer(data):
    """Startet einen neuen Timer für einen Mitarbeiter."""
    with get_db_connection() as conn: # Automatische Pool-Verwaltung
        cur = conn.cursor()
        
        # Prüfen, ob für diesen User bereits ein Timer läuft
        cur.execute("""
            SELECT id FROM time_entries 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s) 
            AND status = 'running'
        """, (data.emp_id,))
        
        if cur.fetchone():
            raise HTTPException(status_code=400, detail="Timer läuft bereits!")

        start_dt = datetime.fromtimestamp(data.start_time)
        
        try:
            cur.execute("""
                INSERT INTO time_entries (employee_id, project, start_time, status, approval_status, is_locked)
                VALUES ((SELECT id FROM employees WHERE emp_id = %s), %s, %s, 'running', 'open', FALSE)
            """, (data.emp_id, data.project, start_dt))
            conn.commit()
            return {"status": "started"}
        except psycopg2.IntegrityError:
            conn.rollback()
            raise HTTPException(status_code=400, detail="Sicherheitsstopp: Timer wurde bereits anderweitig gestartet.")

def stop_timer(data):
    """Beendet den laufenden Timer und berechnet die Dauer."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        end_dt = datetime.fromtimestamp(data.end_time)
        
        cur.execute("""
            UPDATE time_entries 
            SET end_time = %s, notes = %s, status = 'open',
                duration_minutes = EXTRACT(EPOCH FROM (%s - start_time))/60
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s) 
            AND status = 'running'
        """, (end_dt, data.notes, end_dt, data.emp_id))
        
        if cur.rowcount == 0:
            conn.rollback()
            return {"status": "error", "message": "Kein aktiver Timer zum Stoppen gefunden."}
            
        conn.commit()
        return {"status": "stopped"}

# --- MANUELLE EINGABE ---

def add_manual_entry(emp_id, date_str, duration_mins, project):
    """Erlaubt das nachträgliche Eintragen von Arbeitszeit."""
    # Check nutzt intern ebenfalls einen eigenen Context Manager
    if check_is_locked(emp_id, date_str)["is_locked"]:
        return {"status": "error", "message": "Dieser Tag ist bereits gesperrt."}

    start_ts_str = f"{date_str} 08:00:00"
    
    with get_db_connection() as conn:
        cur = conn.cursor()
        try:
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
            """, (emp_id, project, start_ts_str, start_ts_str, duration_mins, duration_mins))
            conn.commit()
            return {"status": "success"}
        except Exception as e:
            conn.rollback()
            return {"status": "error", "message": str(e)}

# --- STATISTIKEN & CHECK ---

def get_daily_stats(emp_id, date_str):
    """Summiert die gearbeiteten Minuten eines Tages."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT COALESCE(SUM(duration_minutes), 0) as total_mins
            FROM time_entries 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date
            AND status != 'running'
        """, (emp_id, date_str))
        
        row = cur.fetchone()
        return {"total_minutes": int(row['total_mins']) if row else 0}

def check_is_locked(emp_id, date_str):
    """Prüft, ob ein Tag für Bearbeitung gesperrt ist."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT 1 FROM time_entries 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date
            AND (is_locked = TRUE OR approval_status IN ('submitted', 'approved'))
            LIMIT 1
        """, (emp_id, date_str))
        return {"is_locked": True if cur.fetchone() else False}

# --- WORKFLOW & FREIGABE ---

def submit_day(emp_id, date_str):
    """Mitarbeiter reicht den Tag zur Prüfung ein."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        
        cur.execute("""
            SELECT 1 FROM time_entries 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date AND status = 'running'
        """, (emp_id, date_str))
        
        if cur.fetchone():
             return {"status": "error", "message": "Bitte erst den laufenden Timer stoppen!"}

        cur.execute("""
            UPDATE time_entries SET approval_status = 'submitted'
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date AND approval_status = 'open'
        """, (emp_id, date_str))
        
        if cur.rowcount == 0:
            return {"status": "error", "message": "Keine einreichbaren Einträge gefunden."}

        conn.commit()
        return {"status": "success"}

def admin_approve_full_day(emp_id, date_str):
    """Admin bestätigt den Tag und sperrt ihn endgültig."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            UPDATE time_entries 
            SET approval_status = 'approved', is_locked = TRUE 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date
        """, (emp_id, date_str))
        conn.commit()
        return {"status": "success"}

def request_correction(emp_id, date_str, note):
    """Setzt den Status zurück, damit der Mitarbeiter Korrekturen vornehmen kann."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            UPDATE time_entries 
            SET approval_status = 'correction_requested', is_locked = FALSE, 
                notes = notes || ' [Korrektur: ' || %s || ']'
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date
        """, (note, emp_id, date_str))
        conn.commit()
        return {"status": "success", "message": "Tag zur Korrektur freigegeben."}

def get_locked_days_for_month(emp_id, month, year):
    """Liefert eine Liste aller gesperrten Tage eines Monats."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT DISTINCT TO_CHAR(start_time, 'YYYY-MM-DD') as d
            FROM time_entries 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND EXTRACT(MONTH FROM start_time) = %s
            AND EXTRACT(YEAR FROM start_time) = %s
            AND (is_locked = TRUE OR approval_status IN ('submitted', 'approved'))
        """, (emp_id, month, year))
        
        rows = cur.fetchall()
        return {"locked_days": [row['d'] for row in rows if row['d']]}