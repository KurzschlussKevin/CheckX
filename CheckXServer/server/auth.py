from fastapi import HTTPException
from passlib.hash import bcrypt
from database import get_db_conn
from datetime import datetime
import random

def register_user(user_data):
    conn = get_db_conn()
    cur = conn.cursor()
    
    cur.execute("SELECT id FROM employees WHERE email = %s", (user_data.email,))
    if cur.fetchone():
        conn.close()
        raise HTTPException(status_code=400, detail="Email bereits vergeben")
    
    hashed_pw = bcrypt.hash(user_data.password)
    new_emp_id = f"P-{random.randint(1000, 9999)}"
    
    cur.execute("""
        INSERT INTO employees (emp_id, email, password_hash, first_name, last_name, role)
        VALUES (%s, %s, %s, %s, %s, 'Prüfer') RETURNING id
    """, (new_emp_id, user_data.email, hashed_pw, user_data.first_name, user_data.last_name))
    
    new_id = cur.fetchone()['id']
    cur.execute("INSERT INTO quotas (employee_id, year, vacation_days_total) VALUES (%s, %s, 30)", 
                (new_id, datetime.now().year))
    
    conn.commit()
    conn.close()
    return {"status": "success"}

def login_user(login_data):
    conn = get_db_conn()
    cur = conn.cursor()
    cur.execute("SELECT * FROM employees WHERE email = %s", (login_data.email,))
    emp = cur.fetchone()
    conn.close()
    
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