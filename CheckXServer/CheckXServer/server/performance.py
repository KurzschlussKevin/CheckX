from database import get_db_connection  # Geändert von get_db_conn auf get_db_connection
from fastapi import HTTPException
from pydantic import BaseModel
from typing import List

# Ein einzelner Posten (z.B. "50x Leitungsroller")
class PerformanceDetail(BaseModel):
    service_id: int
    amount: int

# Der Tagesbericht
class DailyPerformance(BaseModel):
    emp_id: str
    customer_id: int
    date_entry: str
    notes: str = ""
    details: List[PerformanceDetail]

def init_performance_table():
    with get_db_connection() as conn:
        cur = conn.cursor()
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
        cur.execute("""
            CREATE TABLE IF NOT EXISTS performance_details (
                id SERIAL PRIMARY KEY,
                performance_id INTEGER REFERENCES daily_performance(id) ON DELETE CASCADE,
                service_id INTEGER REFERENCES services(id),
                amount INTEGER NOT NULL
            );
        """)
        conn.commit()

def add_performance_entry(data: DailyPerformance):
    with get_db_connection() as conn:
        cur = conn.cursor()
        
        cur.execute("SELECT id FROM employees WHERE emp_id = %s", (data.emp_id,))
        emp = cur.fetchone()
        if not emp:
            raise HTTPException(status_code=404, detail="Mitarbeiter unbekannt")
        
        try:
            cur.execute("""
                INSERT INTO daily_performance (employee_id, customer_id, date_entry, notes)
                VALUES (%s, %s, %s, %s) RETURNING id
            """, (emp['id'], data.customer_id, data.date_entry, data.notes))
            perf_id = cur.fetchone()['id']
            
            for d in data.details:
                if d.amount > 0:
                    cur.execute("""
                        INSERT INTO performance_details (performance_id, service_id, amount)
                        VALUES (%s, %s, %s)
                    """, (perf_id, d.service_id, d.amount))
            
            conn.commit()
            return {"status": "success", "id": perf_id}
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=str(e))

def get_performance_by_employee(emp_id: str):
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT p.*, c.company_name 
            FROM daily_performance p
            JOIN employees e ON p.employee_id = e.id
            JOIN customers c ON p.customer_id = c.id
            WHERE e.emp_id = %s
            ORDER BY p.date_entry DESC LIMIT 50
        """, (emp_id,))
        return cur.fetchall()

def get_customer_progress(customer_id: int):
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT 
                s.name, 
                t.target_amount as target,
                t.price,
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
            GROUP BY s.name, t.target_amount, t.price
        """, (customer_id, customer_id))
        return cur.fetchall()

# NEU: Daten für den PDF Bericht sammeln
def get_report_data(performance_id: int):
    with get_db_connection() as conn:
        cur = conn.cursor()
        
        # 1. Kopfdaten
        cur.execute("""
            SELECT 
                p.id, p.date_entry, p.notes,
                c.company_name, c.street, c.house_number, c.zip_code, c.city,
                e.first_name, e.last_name, e.emp_id, p.customer_id
            FROM daily_performance p
            JOIN customers c ON p.customer_id = c.id
            JOIN employees e ON p.employee_id = e.id
            WHERE p.id = %s
        """, (performance_id,))
        head = cur.fetchone()
        
        if not head:
            return None

        # 2. Positionen
        cur.execute("""
            SELECT pd.amount as current_amount, s.name, s.id as service_id
            FROM performance_details pd
            JOIN services s ON pd.service_id = s.id
            WHERE pd.performance_id = %s
        """, (performance_id,))
        lines = cur.fetchall()
        
        positions = []
        for i, line in enumerate(lines):
            # Target holen
            cur.execute("""
                SELECT target_amount FROM customer_targets 
                WHERE customer_id = %s AND service_id = %s
            """, (head['customer_id'], line['service_id']))
            target_res = cur.fetchone()
            target = target_res['target_amount'] if target_res else 0
            
            # Total Done bis heute
            cur.execute("""
                SELECT SUM(pd.amount) as total 
                FROM performance_details pd
                JOIN daily_performance p ON pd.performance_id = p.id
                WHERE p.customer_id = %s AND pd.service_id = %s
            """, (head['customer_id'], line['service_id']))
            done_res = cur.fetchone()
            total_done = done_res['total'] if done_res and done_res['total'] else 0
            
            positions.append({
                "pos": i + 1,
                "name": line['name'],
                "target": target,
                "current": line['current_amount'],
                "rest": target - total_done
            })
            
    return {"meta": head, "lines": positions}