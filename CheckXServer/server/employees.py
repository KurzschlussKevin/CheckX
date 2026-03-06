from fastapi import APIRouter, Depends, HTTPException
from database import get_db_connection
from auth import get_current_user

router = APIRouter(prefix="/employees", tags=["employees"])

# --- MITARBEITER LISTE ---
@router.get("")
async def list_employees():
    """Listet alle Mitarbeiter mit allen Details auf"""
    with get_db_connection() as conn:
        cur = conn.cursor()
        # Wichtig: 'phone' und 'department' müssen im SELECT stehen
        cur.execute("SELECT first_name, last_name, role, department, email, emp_id, skills, phone FROM employees")
        rows = cur.fetchall()
    
    return [
        {
            "name": f"{r['first_name']} {r['last_name']}", 
            "role": r['role'], 
            "dept": r['department'], 
            "mail": r['email'], 
            "emp_id": r['emp_id'], 
            "phone": r['phone'] if r['phone'] else "", # Sicherstellen, dass None zu "" wird
            "skills": r['skills'] or []
        } for r in rows
    ]

# --- PROFIL-UPDATE (Admin-Schutz + Dept + Phone) ---
@router.put("/{emp_id}")
async def update_employee_profile(emp_id: str, data: dict, current_user: dict = Depends(get_current_user)):
    """Aktualisiert das Profil. Admins dürfen alles, Nutzer nur sich selbst."""
    
    # KORREKTUR: Erlaube Zugriff, wenn es der eigene Account ist ODER der User Admin ist
    is_admin = current_user.get("role") == "Admin"
    is_self = str(current_user.get("sub")) == str(emp_id)

    if not is_self and not is_admin:
        raise HTTPException(status_code=403, detail="Keine Berechtigung für dieses Profil.")

    name = data.get("name", "").strip()
    email = data.get("email", "").strip()
    job_title_input = data.get("job_title", "").strip() 
    department_input = data.get("dept", "").strip()    
    phone_input = data.get("phone", "").strip()       

    if not name or not email:
        raise HTTPException(status_code=400, detail="Name und E-Mail sind Pflichtfelder.")

    name_parts = name.split(" ", 1)
    f_name = name_parts[0]
    l_name = name_parts[1] if len(name_parts) > 1 else ""

    with get_db_connection() as conn:
        cur = conn.cursor()
        
        cur.execute("SELECT role FROM employees WHERE emp_id = %s", (emp_id,))
        db_user = cur.fetchone()
        if not db_user:
            raise HTTPException(status_code=404, detail="Mitarbeiter nicht gefunden")
            
        current_db_role = db_user['role']

        # Nur Admins dürfen die Rolle ändern
        if is_admin and job_title_input:
            allowed_roles = ['Admin', 'Prüfer', 'Einkauf', 'Logistik'] 
            final_role = job_title_input if job_title_input in allowed_roles else current_db_role
        else:
            final_role = current_db_role

        try:
            cur.execute("""
                UPDATE employees 
                SET first_name = %s, 
                    last_name = %s, 
                    email = %s, 
                    role = %s,
                    department = %s,
                    phone = %s
                WHERE emp_id = %s
            """, (f_name, l_name, email, final_role, department_input, phone_input, emp_id))
            conn.commit()
            return {"status": "success", "message": "Profil erfolgreich aktualisiert"}
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=f"Datenbank-Fehler: {str(e)}")