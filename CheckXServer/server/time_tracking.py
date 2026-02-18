from database import get_db_conn
from datetime import datetime, timedelta
from fastapi import HTTPException

def start_timer(data):
    conn = get_db_conn()
    cur = conn.cursor()
    
    # Prüfen, ob für diesen User bereits ein Timer läuft
    cur.execute("SELECT id FROM time_entries WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s) AND status = 'running'", (data.emp_id,))
    if cur.fetchone():
        conn.close()
        raise HTTPException(status_code=400, detail="Timer läuft bereits!")

    start_dt = datetime.fromtimestamp(data.start_time)
    
    cur.execute("""
        INSERT INTO time_entries (employee_id, project, start_time, status)
        VALUES ((SELECT id FROM employees WHERE emp_id = %s), %s, %s, 'running')
    """, (data.emp_id, data.project, start_dt))
    
    conn.commit()
    conn.close()
    return {"status": "started"}

def stop_timer(data):
    conn = get_db_conn()
    cur = conn.cursor()
    end_dt = datetime.fromtimestamp(data.end_time)
    
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

def add_manual_entry(emp_id, date_str, duration_mins, project):
    conn = get_db_conn()
    cur = conn.cursor()
    try:
        # Wir kombinieren das Datum mit einer Standard-Startzeit (08:00 Uhr)
        # und berechnen die Endzeit basierend auf den Minuten.
        start_ts_str = f"{date_str} 08:00:00"
        
        cur.execute("""
            INSERT INTO time_entries (employee_id, project, start_time, end_time, notes, status, duration_minutes)
            VALUES (
                (SELECT id FROM employees WHERE emp_id = %s), 
                %s, 
                %s::timestamp, 
                (%s::timestamp + (%s || ' minutes')::interval),
                'Manuelle Nacherfassung',
                'open',
                %s
            )
        """, (emp_id, project, start_ts_str, start_ts_str, duration_mins, duration_mins))
        
        conn.commit()
        return {"status": "success"}
    except Exception as e:
        print(f"Fehler bei manueller Zeit: {e}")
        return {"status": "error", "message": str(e)}
    finally:
        conn.close()


def get_daily_stats(emp_id, date_str):
    conn = get_db_conn()
    cur = conn.cursor()
    try:
        # Wir berechnen die Minuten direkt aus start_time und end_time
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
        print(f"Fehler bei Stats: {e}")
        return {"total_minutes": 0}
    finally:
        conn.close()