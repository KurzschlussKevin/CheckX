from fastapi import HTTPException
from passlib.hash import bcrypt
from database import get_db_connection  # Geändert von get_db_conn auf get_db_connection
from datetime import datetime
import random

def register_user(user_data):
    # Nutzen des Context Managers für automatische Rückgabe zum Pool
    with get_db_connection() as conn:
        cur = conn.cursor()
        
        cur.execute("SELECT id FROM employees WHERE email = %s", (user_data.email,))
        if cur.fetchone():
            # Da wir im 'with'-Block sind, wird die Verbindung beim raise automatisch freigegeben
            raise HTTPException(status_code=400, detail="Email bereits vergeben")
        
        hashed_pw = bcrypt.hash(user_data.password)
        new_emp_id = f"P-{random.randint(1000, 9999)}"
        
        try:
            cur.execute("""
                INSERT INTO employees (emp_id, email, password_hash, first_name, last_name, role)
                VALUES (%s, %s, %s, %s, %s, 'Prüfer') RETURNING id
            """, (new_emp_id, user_data.email, hashed_pw, user_data.first_name, user_data.last_name))
            
            new_id = cur.fetchone()['id']
            cur.execute("INSERT INTO quotas (employee_id, year, vacation_days_total) VALUES (%s, %s, 30)", 
                        (new_id, datetime.now().year))
            
            conn.commit()
            return {"status": "success"}
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=str(e))

def login_user(login_data):
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM employees WHERE email = %s", (login_data.email,))
        emp = cur.fetchone()
    
    # Der Block ist hier beendet, die Verbindung ist bereits zurück im Pool
    if not emp or not bcrypt.verify(login_data.password, emp['password_hash']):
        raise HTTPException(status_code=401, detail="Zugangsdaten falsch")
    
    return {
        "status": "success", 
        "user": {
            "emp_id": emp['emp_id'], 
            "name": f"{emp['first_name']} {emp['last_name']}", 
            "role": emp['role']
        }
    }