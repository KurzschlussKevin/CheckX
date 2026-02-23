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
    """Aktualisiert das Profil. Rolle nur änderbar durch Admins. Rest für alle frei."""
    
    # 1. Sicherheitscheck: Darf der User das überhaupt? (Nur eigenes Profil)
    # Wir nutzen 'sub', da dies die emp_id im JWT-Token ist
    if str(current_user.get("sub")) != str(emp_id):
        raise HTTPException(status_code=403, detail="Keine Berechtigung für dieses Profil.")

    # 2. Daten aus dem Request extrahieren
    name = data.get("name", "").strip()
    email = data.get("email", "").strip()
    job_title_input = data.get("job_title", "").strip() # Dies ist die 'role' (Admin/Prüfer)
    department_input = data.get("dept", "").strip()    # Freitext Abteilung
    phone_input = data.get("phone", "").strip()       # Mobilnummer

    if not name or not email:
        raise HTTPException(status_code=400, detail="Name und E-Mail sind Pflichtfelder.")

    # Namen für die DB aufteilen (Vorname, Nachname)
    name_parts = name.split(" ", 1)
    f_name = name_parts[0]
    l_name = name_parts[1] if len(name_parts) > 1 else ""

    with get_db_connection() as conn:
        cur = conn.cursor()
        
        # 3. Rollen-Logik bestimmen
        # Wir holen die aktuelle Rolle aus der DB, falls der User kein Admin ist
        cur.execute("SELECT role FROM employees WHERE emp_id = %s", (emp_id,))
        db_user = cur.fetchone()
        current_db_role = db_user['role'] if db_user else "Prüfer"

        # Nur Admins dürfen die Rolle (job_title_input) ändern
        if current_user.get("role") == "Admin" and job_title_input:
            # Liste der erlaubten ENUM-Werte in deiner DB
            allowed_roles = ['Admin', 'Prüfer', 'Einkauf', 'Logistik'] 
            
            if job_title_input in allowed_roles:
                final_role = job_title_input
            else:
                final_role = current_db_role # Bei falscher Eingabe alte Rolle behalten
        else:
            # Nicht-Admins behalten immer ihre aktuelle Rolle
            final_role = current_db_role

        try:
            # 4. Datenbank Update ausführen
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
            
            # Debug-Ausgabe in der Konsole
            print(f">>> Profil Update Erfolg für {emp_id}: Rolle={final_role}, Dept={department_input}")
            
            return {
                "status": "success", 
                "message": "Profil erfolgreich aktualisiert",
                "role_saved": final_role
            }
            
        except Exception as e:
            conn.rollback()
            print(f">>> DB-FEHLER beim Profil-Update: {e}")
            raise HTTPException(status_code=500, detail="Datenbank-Fehler beim Speichern.")