from database import get_db_conn
from fastapi import HTTPException
from pydantic import BaseModel
from typing import List

# Ein einzelner Posten (z.B. "50x Leitungsroller")
class PerformanceDetail(BaseModel):
    service_id: int
    amount: int

# Der Tagesbericht (Kopfdaten + Liste der Posten)
class DailyPerformance(BaseModel):
    emp_id: str
    customer_id: int
    date_entry: str
    notes: str = ""
    details: List[PerformanceDetail]

def init_performance_table():
    conn = get_db_conn()
    cur = conn.cursor()
    
    # 1. Kopfdaten (Wer, Wann, Wo)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS daily_performance (
            id SERIAL PRIMARY KEY,
            employee_id INTEGER REFERENCES employees(id),
            customer_id INTEGER REFERENCES customers(id),
            date_entry DATE NOT NULL,
            notes TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    
    # 2. Detaildaten (Was genau wurde geprüft?)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS performance_details (
            id SERIAL PRIMARY KEY,
            performance_id INTEGER REFERENCES daily_performance(id) ON DELETE CASCADE,
            service_id INTEGER REFERENCES services(id),
            amount INTEGER NOT NULL
        );
    """)
    conn.commit()
    conn.close()

def add_performance_entry(data: DailyPerformance):
    conn = get_db_conn()
    cur = conn.cursor()
    
    cur.execute("SELECT id FROM employees WHERE emp_id = %s", (data.emp_id,))
    emp = cur.fetchone()
    if not emp:
        conn.close(); raise HTTPException(status_code=404, detail="Mitarbeiter unbekannt")
    
    try:
        # Kopf anlegen
        cur.execute("""
            INSERT INTO daily_performance (employee_id, customer_id, date_entry, notes)
            VALUES (%s, %s, %s, %s) RETURNING id
        """, (emp['id'], data.customer_id, data.date_entry, data.notes))
        perf_id = cur.fetchone()['id']
        
        # Details anlegen
        for d in data.details:
            if d.amount > 0:
                cur.execute("""
                    INSERT INTO performance_details (performance_id, service_id, amount)
                    VALUES (%s, %s, %s)
                """, (perf_id, d.service_id, d.amount))
        
        conn.commit()
        return {"status": "success"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

def get_customer_progress(customer_id: int):
    conn = get_db_conn()
    cur = conn.cursor()
    
    # Die Magie: Wir vergleichen SOLL (customer_targets) mit IST (performance_details)
    cur.execute("""
        SELECT 
            s.name, 
            t.target_amount as target,
            COALESCE(SUM(p.amount), 0) as done
        FROM customer_targets t
        JOIN services s ON t.service_id = s.id
        LEFT JOIN (
            SELECT pd.service_id, pd.amount 
            FROM performance_details pd
            JOIN daily_performance dp ON pd.performance_id = dp.id
            WHERE dp.customer_id = %s
        ) p ON p.service_id = t.service_id
        WHERE t.customer_id = %s
        GROUP BY s.name, t.target_amount
    """, (customer_id, customer_id))
    
    rows = cur.fetchall()
    conn.close()
    return rows