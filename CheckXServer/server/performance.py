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
    # KORREKTUR: Validierung gegen leere Berichte hinzugefügt
    if not data.details or len(data.details) == 0:
        raise HTTPException(status_code=400, detail="Es müssen Materialien angegeben werden!")

    # Prüfen ob überhaupt >0 Einträge dabei sind (falls alles auf 0 steht)
    valid_items = [d for d in data.details if d.amount > 0]
    if not valid_items:
        raise HTTPException(status_code=400, detail="Die Menge aller Materialien ist 0. Bericht wird nicht gespeichert.")

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
            
            for d in valid_items:
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
        with conn.cursor() as cur:
            # 1. Kopfdaten
            cur.execute("""
                SELECT 
                    p.id, p.date_entry, p.notes,
                    c.company_name, c.street, c.house_number, c.zip_code, c.city,
                    e.first_name, e.last_name, e.emp_id, p.customer_id,
                    c.cp1_firstname, c.cp1_lastname
                FROM daily_performance p
                JOIN customers c ON p.customer_id = c.id
                JOIN employees e ON p.employee_id = e.id
                WHERE p.id = %s
            """, (performance_id,))
            head = cur.fetchone()
            
            if not head:
                return None

            # 2. Alle Positionen inkl. Soll und Gesamt-Ist in EINER Abfrage
            cur.execute("""
                SELECT 
                    pd.amount as current_amount, 
                    s.name, 
                    s.id as service_id,
                    COALESCE(ct.target_amount, 0) as target,
                    COALESCE((
                        SELECT SUM(pd2.amount) 
                        FROM performance_details pd2
                        JOIN daily_performance dp2 ON pd2.performance_id = dp2.id
                        WHERE dp2.customer_id = %s AND pd2.service_id = s.id
                    ), 0) as total_done_so_far
                FROM performance_details pd
                JOIN services s ON pd.service_id = s.id
                LEFT JOIN customer_targets ct ON (ct.customer_id = %s AND ct.service_id = s.id)
                WHERE pd.performance_id = %s
            """, (head['customer_id'], head['customer_id'], performance_id))
            
            rows = cur.fetchall()
            positions = []
            for i, row in enumerate(rows):
                positions.append({
                    "pos": i + 1,
                    "name": row['name'],
                    "target": row['target'],
                    "current": row['current_amount'],
                    "rest": row['target'] - row['total_done_so_far']
                })
                
    return {"meta": head, "lines": positions}