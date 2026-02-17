from database import get_db_conn
from datetime import datetime
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