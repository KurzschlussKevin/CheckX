from database import get_db_conn
from datetime import datetime, timedelta

def get_stats(emp_id: str):
    conn = get_db_conn()
    cur = conn.cursor()
    
    # Datum für Wochenstart (Montag) ermitteln
    today = datetime.now()
    start_of_week = (today - timedelta(days=today.weekday())).strftime('%Y-%m-%d')
    
    stats = {
        "revenue_week": 0.0,
        "hours_week": 0.0,
        "open_tasks": 0 # Platzhalter für später
    }
    
    try:
        # 1. UMSATZ DIESER WOCHE (Menge * Preis aus Targets)
        # Wir verknüpfen: Performance -> Details -> Customer Targets (für den Preis)
        cur.execute("""
            SELECT COALESCE(SUM(pd.amount * ct.price), 0) as revenue
            FROM daily_performance dp
            JOIN performance_details pd ON dp.id = pd.performance_id
            JOIN customer_targets ct ON (dp.customer_id = ct.customer_id AND pd.service_id = ct.service_id)
            JOIN employees e ON dp.employee_id = e.id
            WHERE e.emp_id = %s
            AND dp.date_entry >= %s
        """, (emp_id, start_of_week))
        
        row = cur.fetchone()
        if row and row['revenue']:
            stats['revenue_week'] = float(row['revenue'])

        # 2. ARBEITSSTUNDEN DIESER WOCHE
        # Annahme: time_entries Tabelle hat start_time/end_time als Unix-Timestamp (float)
        # Wir summieren die Differenz (Ende - Start)
        cur.execute("""
            SELECT COALESCE(SUM(t.end_time - t.start_time), 0) as seconds
            FROM time_entries t
            JOIN employees e ON t.employee_id = e.id
            WHERE e.emp_id = %s
            AND t.date >= %s
            AND t.end_time IS NOT NULL
        """, (emp_id, start_of_week))
        
        row_time = cur.fetchone()
        if row_time and row_time['seconds']:
            # Sekunden in Stunden umrechnen
            stats['hours_week'] = round(float(row_time['seconds']) / 3600.0, 1)

    except Exception as e:
        print(f"Dashboard Error: {e}")
        # Wir geben trotzdem die 0-Werte zurück, damit das Dashboard nicht abstürzt
    finally:
        conn.close()
        
    return stats