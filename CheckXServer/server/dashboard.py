from database import get_db_conn
from datetime import datetime, timedelta

def get_stats(emp_id: str):
    """
    Berechnet die Statistiken für das Dashboard:
    - Wochenumsatz des Mitarbeiters
    - Arbeitsstunden der aktuellen Woche
    - Platzhalter für offene Aufgaben
    """
    conn = get_db_conn()
    cur = conn.cursor()
    
    # Ermittlung des Wochenstarts (Montag 00:00 Uhr)
    today = datetime.now()
    start_of_week = (today - timedelta(days=today.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
    
    stats = {
        "revenue_week": 0.0,
        "hours_week": 0.0,
        "open_tasks": 0
    }
    
    try:
        # 1. UMSATZ DIESER WOCHE
        # Summiert (Menge * Preis) aus den Performance-Berichten des Mitarbeiters seit Wochenbeginn
        cur.execute("""
            SELECT COALESCE(SUM(pd.amount * ct.price), 0) as revenue
            FROM daily_performance dp
            JOIN performance_details pd ON dp.id = pd.performance_id
            JOIN customer_targets ct ON (dp.customer_id = ct.customer_id AND pd.service_id = ct.service_id)
            JOIN employees e ON dp.employee_id = e.id
            WHERE e.emp_id = %s
            AND dp.date_entry >= %s::date
        """, (emp_id, start_of_week.date()))
        
        rev_row = cur.fetchone()
        if rev_row and rev_row['revenue']:
            stats['revenue_week'] = float(rev_row['revenue'])

        # 2. ARBEITSSTUNDEN DIESER WOCHE
        # Korrektur des Fehlers: Umwandlung von Intervall in Sekunden via EPOCH
        cur.execute("""
            SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (t.end_time - t.start_time))), 0) as seconds
            FROM time_entries t
            JOIN employees e ON t.employee_id = e.id
            WHERE e.emp_id = %s
            AND t.start_time >= %s
            AND t.end_time IS NOT NULL
        """, (emp_id, start_of_week))
        
        time_row = cur.fetchone()
        if time_row and time_row['seconds']:
            # Umrechnung: Sekunden / 3600 = Stunden (auf 1 Dezimalstelle gerundet)
            stats['hours_week'] = round(float(time_row['seconds']) / 3600.0, 1)

        # 3. OFFENE AUFGABEN (Beispiel-Logik)
        # Hier könnten Aufgaben gezählt werden, die noch nicht erledigt sind
        cur.execute("""
            SELECT COUNT(*) as task_count 
            FROM performance_details pd
            JOIN daily_performance dp ON pd.performance_id = dp.id
            JOIN employees e ON dp.employee_id = e.id
            WHERE e.emp_id = %s AND dp.date_entry = CURRENT_DATE
        """, (emp_id,))
        
        task_row = cur.fetchone()
        if task_row:
            stats['open_tasks'] = task_row['task_count']

    except Exception as e:
        print(f"Dashboard Error in stats calculation: {e}")
        # Rückgabe der Initialwerte bei Fehlern, um Dashboard-Absturz in Godot zu vermeiden
    finally:
        conn.close()
        
    return stats