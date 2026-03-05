from database import get_db_connection
from datetime import datetime
from fastapi import HTTPException
from psycopg2.extras import RealDictCursor
import psycopg2

# --- TIMER FUNKTIONEN ---

def start_timer(data):
    """Startet einen neuen Timer. Nutzt Unique Index in DB gegen Race Conditions."""
    now = datetime.now()
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.execute("""
                    INSERT INTO time_entries (employee_id, project, start_time, status, approval_status, is_locked)
                    VALUES ((SELECT id FROM employees WHERE emp_id = %s), %s, %s, 'running', 'open', FALSE)
                """, (data.emp_id, data.project, now))
                conn.commit()
                return {"status": "started", "server_time": now.timestamp()}
            except psycopg2.IntegrityError:
                conn.rollback()
                raise HTTPException(status_code=400, detail="Es läuft bereits ein aktiver Timer!")
            except Exception as e:
                conn.rollback()
                raise HTTPException(status_code=500, detail=str(e))

def stop_timer(data):
    """Beendet den laufenden Timer mit der aktuellen Serverzeit gegen Manipulation."""
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            # KORREKTUR: Nutze datetime.now() statt data.end_time vom Client
            server_now = datetime.now()
            
            break_min = getattr(data, 'break_minutes', 0)
            final_notes = data.notes
            if break_min > 0:
                pause_info = f" [Auto-Pause: {break_min} Min abgezogen]"
                final_notes = (final_notes + pause_info) if final_notes else pause_info

            cur.execute("""
                UPDATE time_entries 
                SET end_time = %s, 
                    notes = %s, 
                    status = 'open',
                    duration_minutes = (EXTRACT(EPOCH FROM (%s - start_time))/60) - %s,
                    break_minutes = %s
                WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s) 
                AND status = 'running'
            """, (server_now, final_notes, server_now, break_min, break_min, data.emp_id))
            
            if cur.rowcount == 0:
                conn.rollback()
                return {"status": "error", "message": "Kein aktiver Timer gefunden."}
                
            conn.commit()
            return {"status": "stopped", "applied_break": break_min, "server_time": server_now.timestamp()}

# --- MANUELLE EINGABE ---

# KORREKTUR: break_min als 5. Argument hinzugefügt
def add_manual_entry(emp_id, date_str, duration_mins, project, break_min=0, start_hour="08:00"):
    """Erlaubt das nachträgliche Eintragen von Arbeitszeit inkl. Pause."""
    if check_is_locked(emp_id, date_str)["is_locked"]:
        return {"status": "error", "message": "Dieser Tag ist bereits gesperrt."}

    start_ts_str = f"{date_str} {start_hour}:00"
    
    with get_db_connection() as conn:
        cur = conn.cursor()
        try:
            cur.execute("""
                INSERT INTO time_entries (
                    employee_id, project, start_time, end_time, 
                    notes, status, duration_minutes, break_minutes, 
                    approval_status, is_locked
                )
                VALUES (
                    (SELECT id FROM employees WHERE emp_id = %s), 
                    %s, 
                    %s::timestamp, 
                    (%s::timestamp + (%s || ' minutes')::interval),
                    'Manuelle Nacherfassung',
                    'open',
                    %s,
                    %s,
                    'open',
                    FALSE
                )
            """, (emp_id, project, start_ts_str, start_ts_str, duration_mins, duration_mins, break_min))
            conn.commit()
            return {"status": "success"}
        except Exception as e:
            conn.rollback()
            return {"status": "error", "message": str(e)}

# --- STATISTIKEN & CHECK ---

def get_daily_stats(emp_id, date_str):
    with get_db_connection() as conn:
        cur = conn.cursor()
        # JOIN ist oft performanter als Subquery in der WHERE-Clause
        cur.execute("""
            SELECT COALESCE(SUM(
                (EXTRACT(EPOCH FROM (t.end_time - t.start_time)) / 60.0) - t.break_minutes
            ), 0) as total_mins
            FROM time_entries t
            JOIN employees e ON t.employee_id = e.id
            WHERE e.emp_id = %s AND t.start_time::date = %s::date
            AND t.status != 'running'
        """, (emp_id, date_str))
        row = cur.fetchone()
        return {"total_minutes": float(row['total_mins']) if row else 0.0}

def check_is_locked(emp_id, date_str):
    """Prüft, ob ein Tag für Bearbeitung gesperrt ist."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT 1 FROM time_entries 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date
            AND (is_locked = TRUE OR approval_status IN ('submitted', 'approved', 'correction_pending'))
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
            UPDATE time_entries SET approval_status = 'submitted', is_locked = TRUE
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date AND (approval_status = 'open' OR approval_status = 'rejected')
        """, (emp_id, date_str))
        
        if cur.rowcount == 0:
            return {"status": "error", "message": "Keine einreichbaren Einträge gefunden."}

        conn.commit()
        return {"status": "success"}

def admin_approve_full_day(emp_id, date_str):
    """Admin bestätigt den Tag und sperrt ihn endgültig."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        try:
            cur.execute("""
                UPDATE time_entries 
                SET approval_status = 'approved', is_locked = TRUE 
                WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
                AND start_time::date = %s::date
            """, (emp_id, date_str))
            
            from notifications import add_notification
            add_notification(emp_id, f"Deine Stunden für den {date_str} wurden genehmigt.", "info")
            
            conn.commit()
            return {"status": "success"}
        except Exception as e:
            conn.rollback()
            return {"status": "error", "message": str(e)}

def admin_reject_day(emp_id, date_str, reason):
    """Admin lehnt den Tag ab oder gibt Korrektur frei."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        try:
            cur.execute("""
                UPDATE time_entries 
                SET approval_status = 'rejected', is_locked = FALSE,
                    notes = notes || ' [Info: ' || %s || ']'
                WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
                AND start_time::date = %s::date
            """, (reason, emp_id, date_str))
            
            from notifications import add_notification
            add_notification(emp_id, f"Tag {date_str} wurde freigegeben/abgelehnt: {reason}", "correction")
            
            conn.commit()
            return {"status": "success"}
        except Exception as e:
            conn.rollback()
            return {"status": "error", "message": str(e)}

def request_correction(emp_id, date_str, note):
    """Techniker beantragt Korrektur. Status wird auf 'correction_pending' gesetzt."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        try:
            cur.execute("""
            UPDATE time_entries 
            SET approval_status = 'correction_pending',
                notes = notes || ' [Korrektur-Anfrage: ' || %s || ']'
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date
            AND approval_status != 'approved'  # <--- NEUE ZEILE: Genehmigtes bleibt geschützt!
        """, (note, emp_id, date_str))
            
            conn.commit()
            return {"status": "success", "message": "Anfrage an Admin gesendet."}
            
        except Exception as e:
            conn.rollback()
            return {"status": "error", "message": str(e)}

def get_locked_days_for_month(emp_id, month, year):
    """Liefert eine Liste aller gesperrten Tage eines Monats."""
    with get_db_connection() as conn:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT DISTINCT TO_CHAR(start_time, 'YYYY-MM-DD') as d
            FROM time_entries 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND EXTRACT(MONTH FROM start_time) = %s
            AND EXTRACT(YEAR FROM start_time) = %s
            AND (is_locked = TRUE OR approval_status IN ('submitted', 'approved', 'correction_pending'))
        """, (emp_id, month, year))
        
        rows = cur.fetchall()
        return {"locked_days": [row['d'] for row in rows if row['d']]}

# --- ADMIN-PANEL FUNKTIONEN ---

def get_all_pending_submissions():
    """Holt alle Tage, die zur Prüfung eingereicht wurden."""
    with get_db_connection() as conn:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT DISTINCT e.emp_id, e.first_name, e.last_name, t.start_time::date as date
            FROM time_entries t
            JOIN employees e ON t.employee_id = e.id
            WHERE t.approval_status = 'submitted'
            ORDER BY date DESC
        """)
        return cur.fetchall()

def get_pending_corrections():
    """Holt alle Tage, für die eine Korrektur beantragt wurde."""
    with get_db_connection() as conn:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT e.emp_id, e.first_name, e.last_name, 
                   te.start_time::date as date, te.notes
            FROM time_entries te
            JOIN employees e ON te.employee_id = e.id
            WHERE te.approval_status = 'correction_pending'
            GROUP BY e.emp_id, e.first_name, e.last_name, te.start_time::date, te.notes
            ORDER BY te.start_time::date DESC
        """)
        return cur.fetchall()
    
def get_entries_by_employee(emp_id):
    """Holt alle Einträge eines Mitarbeiters aus der DB inkl. emp_id für Frontend-Filter."""
    with get_db_connection() as conn:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT t.id, e.emp_id, t.project, t.start_time, t.end_time, 
                   t.duration_minutes as duration, t.notes, t.approval_status, 
                   t.status, t.is_locked, 
                   TO_CHAR(t.start_time, 'YYYY-MM-DD') as date,
                   EXTRACT(EPOCH FROM t.start_time) as start_unix
            FROM time_entries t
            JOIN employees e ON t.employee_id = e.id
            WHERE e.emp_id = %s
            ORDER BY t.start_time DESC
        """, (emp_id,))
        return cur.fetchall()

# =========================================================
# NEU: DATEN FÜR PDF-EXPORT (Nach Monat & Jahr)
# =========================================================
def get_entries_by_employee_and_month(emp_id, year, month):
    """Holt alle Einträge eines Mitarbeiters für einen bestimmten Monat und Jahr."""
    with get_db_connection() as conn:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT id, project, start_time, end_time, duration_minutes,
                   notes, approval_status, status, is_locked, break_minutes,
                   TO_CHAR(start_time, 'YYYY-MM-DD') as date
            FROM time_entries
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND EXTRACT(YEAR FROM start_time) = %s
            AND EXTRACT(MONTH FROM start_time) = %s
            ORDER BY start_time ASC
        """, (emp_id, year, month))
        return cur.fetchall()