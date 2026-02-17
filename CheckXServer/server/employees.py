from database import get_db_conn

def list_all_employees():
    conn = get_db_conn()
    cur = conn.cursor()
    cur.execute("SELECT first_name, last_name, role, department, email, emp_id, skills FROM employees")
    rows = cur.fetchall()
    conn.close()
    
    return [
        {
            "name": f"{r['first_name']} {r['last_name']}", 
            "role": r['role'], 
            "dept": r['department'], 
            "mail": r['email'], 
            "emp_id": r['emp_id'], 
            "skills": r['skills'] or []
        } for r in rows
    ]