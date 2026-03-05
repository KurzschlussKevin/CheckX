from fastapi import HTTPException
from database import get_db_connection
from datetime import datetime
from notifications import add_notification

def create_vacation_request(data):
    """Erstellt einen neuen Urlaubsantrag in der Datenbank."""
    # KORREKTUR: Datum validieren
    try:
        start_dt = datetime.strptime(data.start_date, "%Y-%m-%d")
        end_dt = datetime.strptime(data.end_date, "%Y-%m-%d")
        if end_dt < start_dt:
            raise HTTPException(status_code=400, detail="Enddatum darf nicht vor dem Startdatum liegen.")
    except ValueError:
        raise HTTPException(status_code=400, detail="Ungültiges Datumsformat.")

    with get_db_connection() as conn:
        cur = conn.cursor()
        
        cur.execute("SELECT id FROM employees WHERE emp_id = %s", (data.emp_id,))
        emp_row = cur.fetchone()
        
        if not emp_row:
            raise HTTPException(status_code=404, detail="Mitarbeiter nicht gefunden")

        internal_id = emp_row['id']
        
        # KORREKTUR: Überschneidungen prüfen (optional aber dringend empfohlen)
        cur.execute("""
            SELECT id FROM absences 
            WHERE employee_id = %s AND status != 'rejected'
            AND (start_date <= %s AND end_date >= %s)
        """, (internal_id, data.end_date, data.start_date))
        
        if cur.fetchone():
            raise HTTPException(status_code=400, detail="Es existiert bereits ein Antrag für diesen Zeitraum.")
        
        type_mapping = {
            "erholungsurlaub": "erholung",
            "sonderurlaub": "sonderurlaub",
            "krankheit": "krankheit",
            "gleitzeit": "gleitzeit"
        }
        db_type = type_mapping.get(data.vacation_type.lower(), "erholung")

        try:
            cur.execute("""
                INSERT INTO absences (employee_id, start_date, end_date, type, status)
                VALUES (%s, %s, %s, %s, 'pending')
            """, (internal_id, data.start_date, data.end_date, db_type))
            
            conn.commit()
            return {"status": "success", "message": "Urlaubsantrag eingereicht."}
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=str(e))

def get_pending_requests():
    """Holt alle ausstehenden Urlaubsanträge für das Admin-Panel."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT a.id, e.first_name, e.last_name, e.emp_id, a.start_date, a.end_date, a.type
            FROM absences a
            JOIN employees e ON a.employee_id = e.id
            WHERE a.status = 'pending'
            ORDER BY a.created_at ASC
        """)
        return cur.fetchall()

def update_absence_status(absence_id, new_status, admin_emp_id):
    """Aktualisiert den Status eines Antrags und sendet eine Benachrichtigung."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        try:
            # 1. Mitarbeiter-ID und Dates für die Benachrichtigung finden
            cur.execute("""
                SELECT e.emp_id, e.id as internal_id, a.start_date, a.end_date, a.type
                FROM employees e 
                JOIN absences a ON a.employee_id = e.id 
                WHERE a.id = %s
            """, (absence_id,))
            target_emp = cur.fetchone()
            
            # KORREKTUR/ARCHITEKTUR: Wenn Urlaub genehmigt wird, ziehen wir die Basis-Tage ab!
            if new_status == "approved" and target_emp and target_emp['type'] == 'erholung':
                # Eine simple Berechnung der Differenz in Tagen (Vorsicht: Wochenenden sind hier vorerst inkludiert)
                delta_days = (target_emp['end_date'] - target_emp['start_date']).days + 1
                
                # Urlaubskonto aktualisieren
                cur.execute("""
                    UPDATE quotas 
                    SET vacation_days_taken = vacation_days_taken + %s
                    WHERE employee_id = %s AND year = %s
                """, (delta_days, target_emp['internal_id'], datetime.now().year))

            # 2. Status Update
            cur.execute("""
                UPDATE absences 
                SET status = %s, 
                    approved_by = (SELECT id FROM employees WHERE emp_id = %s)
                WHERE id = %s
            """, (new_status, admin_emp_id, absence_id))
            
            # 3. Benachrichtigung senden
            if target_emp:
                status_text = "genehmigt" if new_status == "approved" else "abgelehnt"
                add_notification(
                    target_emp['emp_id'], 
                    f"Dein Urlaubsantrag wurde {status_text}.", 
                    "vacation"
                )
            
            conn.commit()
            return {"status": "success"}
            
        except Exception as e:
            conn.rollback()
            print(f"Fehler beim Update des Urlaubsstatus: {e}")
            raise HTTPException(status_code=500, detail=str(e))

def get_user_absences(emp_id):
    """Holt alle Anträge eines spezifischen Mitarbeiters."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT start_date, end_date, type, status 
            FROM absences 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            ORDER BY start_date DESC
        """, (emp_id,))
        return cur.fetchall()

def get_approved_absences_in_range(year: int, month: int):
    """Holt alle genehmigten Urlaube für die Kalenderansicht."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        month_str = f"{year}-{month:02d}"
        
        cur.execute("""
            SELECT e.first_name, e.last_name, a.start_date, a.end_date, a.type
            FROM absences a
            JOIN employees e ON a.employee_id = e.id
            WHERE a.status = 'approved'
            AND (
                TO_CHAR(a.start_date, 'YYYY-MM') = %s 
                OR TO_CHAR(a.end_date, 'YYYY-MM') = %s
                OR (a.start_date < TO_DATE(%s, 'YYYY-MM') AND a.end_date > (TO_DATE(%s, 'YYYY-MM') + INTERVAL '1 month'))
            )
            ORDER BY a.start_date ASC
        """, (month_str, month_str, month_str, month_str))
        
        return cur.fetchall()