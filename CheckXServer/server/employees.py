from database import get_db_connection  # Geändert von get_db_conn auf get_db_connection

def list_all_employees():
    # Nutzen des Context Managers für automatische Rückgabe zum Pool
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT first_name, last_name, role, department, email, emp_id, skills FROM employees")
        rows = cur.fetchall()
    
    # Die Verbindung ist hier bereits sicher im Pool zurückgegeben
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