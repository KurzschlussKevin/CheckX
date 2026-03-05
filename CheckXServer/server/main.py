from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks, File, UploadFile, Form
from fastapi.responses import FileResponse
from jose import jwt, JWTError
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from fastapi import Request
import uuid
import os
import shutil
import uvicorn

# Module imports
import auth
import employees
import absences 
import database
import customers 
import performance 
import time_tracking
import services
import templates
import pdf_generator
import dashboard
import bug_system
import notifications

# Import der zentralen Auth-Funktionen aus dem auth-Modul
from auth import get_current_user, oauth2_scheme
# Import von spezifischen Funktionen für die Zeiterfassung
from time_tracking import get_locked_days_for_month

app = FastAPI(title="CheckX API")

# --- AUTH-HILFSFUNKTIONEN ---

def require_admin(current_user: dict = Depends(get_current_user)):
    """Prüft, ob der aktuelle Nutzer Admin-Rechte hat."""
    if current_user.get("role") != "Admin":
        raise HTTPException(status_code=403, detail="Admin-Rechte erforderlich")
    return current_user

# --- DATENMODELLE ---

class UserRegister(BaseModel):
    first_name: str
    last_name: str
    email: str
    password: str

class UserLogin(BaseModel):
    email: str
    password: str

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

class UserUpdate(BaseModel):
    name: str
    email: EmailStr
    job_title: Optional[str] = ""
    dept: Optional[str] = ""    # Neu hinzugefügt
    phone: Optional[str] = ""   # Neu hinzugefügt

class TimerData(BaseModel):
    emp_id: str
    project: Optional[str] = ""
    start_time: Optional[float] = None
    end_time: Optional[float] = None
    notes: Optional[str] = ""
    # NEU: Feld für die Pause beim Stoppen des Timers
    break_minutes: Optional[int] = 0

class ManualEntryData(BaseModel):
    emp_id: str
    date: str
    duration_minutes: int # KORREKTUR: Umbenannt von duration passend zu Store.gd
    project: str
    break_minutes: Optional[int] = 0 # NEU: Für die manuelle Pause

class SubmitDayData(BaseModel):
    emp_id: str
    date: str

class VacationRequest(BaseModel):
    emp_id: str
    start_date: str
    end_date: str
    vacation_type: str

class CorrectionData(BaseModel):
    emp_id: str
    date: str
    note: str

# --- ROUTEN: AUTHENTIFIZIERUNG ---

@app.post("/auth/register")
async def route_register(user: UserRegister, request: Request):
    # 1. Prüfen, wie viele User existieren
    with database.get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) as count FROM employees")
        user_count = cur.fetchone()['count']
    
    # 2. Wenn die DB leer ist -> Erster User wird Admin
    if user_count == 0:
        return auth.register_user(user, is_initial_setup=True)
    
    # 3. Wenn die DB NICHT leer ist -> Token manuell prüfen
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Login erforderlich, um weitere Nutzer anzulegen")
    
    # Token extrahieren (hinter dem Wort 'Bearer ')
    token = auth_header.split(" ")[1]
    
    # Den User über die bestehende auth-Funktion prüfen
    current_user = auth.get_current_user(token)
    
    if current_user.get("role") != "Admin":
        raise HTTPException(status_code=403, detail="Nur Admins dürfen Nutzer registrieren")
        
    return auth.register_user(user, is_initial_setup=False)
@app.post("/auth/login")
def route_login(user: UserLogin):
    return auth.login_user(user)

@app.post("/auth/forgot-password")
async def route_forgot_password(request: ForgotPasswordRequest, background_tasks: BackgroundTasks):
    with database.get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT email FROM employees WHERE email = %s", (request.email,))
        user = cur.fetchone()
    
    if not user:
        return {"status": "success", "message": "Falls die Email existiert, wurde ein Link versendet."}

    token = auth.create_password_reset_token(request.email)
    background_tasks.add_task(auth.send_reset_email, request.email, token)
    return {"status": "success", "message": "Email mit Reset-Link wurde versendet."}

@app.post("/auth/reset-password")
def route_reset_password(data: ResetPasswordRequest):
    return auth.reset_password_in_db(data.token, data.new_password)

# --- ROUTEN: MITARBEITER ---

@app.get("/employees")
async def route_get_employees(current_user: dict = Depends(get_current_user)):
    return await employees.list_employees()

@app.put("/employees/{emp_id}")
async def route_update_profile(emp_id: str, data: UserUpdate, current_user: dict = Depends(get_current_user)):
    return await employees.update_employee_profile(emp_id, data.dict(), current_user)

# --- ROUTEN: SERVICES (KATALOG) ---

@app.get("/services")
def route_get_services(current_user: dict = Depends(get_current_user)):
    return services.get_all_services()

@app.post("/services")
def route_create_service(s: services.ServiceModel, admin: dict = Depends(require_admin)):
    return services.create_service(s)

# --- ROUTEN: VORLAGEN (TEMPLATES) ---

@app.get("/templates")
def route_get_templates(current_user: dict = Depends(get_current_user)):
    return templates.get_all_templates()

@app.get("/templates/{tid}")
def route_get_template_details(tid: int, current_user: dict = Depends(get_current_user)):
    return templates.get_template_details(tid)

@app.post("/templates")
def route_create_template(t: templates.TemplateCreate, admin: dict = Depends(require_admin)):
    return templates.create_template(t)

# --- NEU: ROUTEN FÜR PDF VORLAGEN (UPLOAD / DOWNLOAD) ---

@app.post("/templates/upload_pdf")
async def route_upload_pdf(
    template_type: str = Form(...),
    file: UploadFile = File(...),
    admin: dict = Depends(require_admin)
):
    """Admin lädt eine neue PDF-Vorlage hoch (mit strikten Sicherheitsprüfungen)"""
    if template_type not in ["timesheet", "invoice"]:
        raise HTTPException(status_code=400, detail="Ungültiger Vorlagen-Typ")
        
    # KORREKTUR 1: MIME-Type Sicherheits-Check
    if file.content_type not in ["application/pdf", "application/x-pdf"]:
        raise HTTPException(status_code=415, detail="Nur PDF-Dateien sind erlaubt!")
    
    os.makedirs("pdf_templates", exist_ok=True)
    file_path = f"pdf_templates/{template_type}.pdf"
    
    MAX_FILE_SIZE = 5 * 1024 * 1024
    file_content = await file.read() 
    
    if len(file_content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="Datei zu groß (Max 5MB erlaubt)")
        
    # KORREKTUR 2: Überprüfung der Magic Bytes (PDFs starten auf Byte-Ebene zwingend mit %PDF)
    if not file_content.startswith(b"%PDF"):
        raise HTTPException(status_code=415, detail="Dateiinhalt ist kein gültiges PDF-Format!")
        
    with open(file_path, "wb") as buffer:
        buffer.write(file_content)
        
    return {"status": "success", "message": f"{template_type} erfolgreich hochgeladen"}
    # ---------------------------------------------------
        
    return {"status": "success", "message": f"{template_type} erfolgreich hochgeladen"}

@app.get("/templates/download_pdf/{template_type}")
async def route_download_pdf(template_type: str, current_user: dict = Depends(get_current_user)):
    """Nutzer laden die aktuelle PDF-Vorlage herunter"""
    if template_type not in ["timesheet", "invoice"]:
        raise HTTPException(status_code=400, detail="Ungültiger Vorlagen-Typ")
    
    file_path = f"pdf_templates/{template_type}.pdf"
    
    # Prüfen, ob der Admin überhaupt schon eine Datei hochgeladen hat
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Noch keine Vorlage auf dem Server vorhanden")
        
    # Sende die Datei als Download an den Client
    return FileResponse(file_path, filename=f"{template_type}.pdf", media_type="application/pdf")

# --- ROUTEN: KUNDEN ---

@app.get("/customers")
def route_get_customers(current_user: dict = Depends(get_current_user)):
    return customers.get_active_customers()

@app.post("/customers")
def route_create_customer(c: customers.CustomerModel, admin: dict = Depends(require_admin)):
    return customers.create_customer(c)

@app.put("/customers")
def route_update_customer(c: customers.CustomerModel, admin: dict = Depends(require_admin)):
    return customers.update_customer(c)

@app.post("/customers/{cid}/targets")
def route_set_targets(cid: int, targets: List[customers.CustomerTarget], admin: dict = Depends(require_admin)):
    return customers.set_customer_targets(cid, targets)

@app.get("/customers/{cid}/targets")
def route_get_targets(cid: int, current_user: dict = Depends(get_current_user)):
    return customers.get_customer_targets(cid)

# --- ROUTEN: PERFORMANCE (LEISTUNG) ---

@app.post("/performance")
def route_add_performance(p: performance.DailyPerformance, current_user: dict = Depends(get_current_user)):
    return performance.add_performance_entry(p)

@app.get("/performance/me")
def route_get_my_performance(emp_id: str, current_user: dict = Depends(get_current_user)):
    # SICHERHEITS-CHECK: Nur eigene Daten oder Admin
    if current_user.get("sub") != emp_id and current_user.get("role") != "Admin":
        raise HTTPException(status_code=403, detail="Keine Berechtigung für diese Performance-Daten")
    return performance.get_performance_by_employee(emp_id)

@app.get("/performance/progress")
def route_get_progress(customer_id: int, current_user: dict = Depends(get_current_user)):
    return performance.get_customer_progress(customer_id)

# --- ROUTEN: PDF EXPORT ---

@app.get("/export/pdf/performance/{pid}")
def route_export_pdf(pid: int, background_tasks: BackgroundTasks, current_user: dict = Depends(get_current_user)):
    # KORREKTUR NEU: Besitzer des Berichts ermitteln und Berechtigung prüfen (IDOR-Schutz)
    with database.get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT e.emp_id FROM performance p
            JOIN employees e ON p.employee_id = e.id
            WHERE p.id = %s
        """, (pid,))
        owner = cur.fetchone()
        
    if not owner:
        raise HTTPException(status_code=404, detail="Bericht nicht gefunden")
        
    # Nur der Ersteller selbst oder ein Admin darf den Bericht als PDF laden
    if owner['emp_id'] != current_user.get("sub") and current_user.get("role") != "Admin":
        raise HTTPException(status_code=403, detail="Keine Berechtigung, diesen Bericht zu exportieren.")

    # Daten laden
    data = performance.get_report_data(pid)
    if not data:
        raise HTTPException(status_code=404, detail="Bericht nicht gefunden")
    
    os.makedirs("temp", exist_ok=True)
    
    # BEREITS BEHOBEN: Eindeutigen Dateinamen pro Request generieren
    import uuid # Falls uuid oben im Dokument noch nicht importiert wurde
    unique_id = uuid.uuid4().hex
    filename = f"Montagebericht_{pid}_{unique_id}.pdf"
    filepath = f"temp/{filename}"
    
    pdf_generator.create_performance_pdf(data, filepath)
    
    # Datei nach dem Senden löschen
    background_tasks.add_task(os.remove, filepath)
    
    # Der Download-Name für den Nutzer bleibt sauber
    return FileResponse(filepath, filename=f"Montagebericht_{pid}.pdf", media_type='application/pdf')

@app.get("/export/pdf/timesheet")
def route_export_timesheet(year: int, month: int, current_user: dict = Depends(get_current_user)):
    emp_id = current_user["sub"]
    
    # 1. Hole den echten Vor- und Nachnamen aus der Datenbank
    with database.get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT first_name, last_name FROM employees WHERE emp_id = %s", (emp_id,))
        user_row = cur.fetchone()
        if user_row:
            emp_name = f"{user_row['first_name']} {user_row['last_name']}"
        else:
            emp_name = "Mitarbeiter"
    
    # 2. Hole die Einträge
    entries = time_tracking.get_entries_by_employee_and_month(emp_id, year, month)
    
    # 3. Pfade definieren
    template_path = "pdf_templates/timesheet.pdf"
    if not os.path.exists(template_path):
        raise HTTPException(status_code=404, detail="Keine Stundenzettel-Vorlage auf dem Server gefunden.")
        
    os.makedirs("temp", exist_ok=True)
    filename = f"timesheet_temp_{emp_id}.pdf"
    filepath = f"temp/{filename}"
    
    # 4. PDF generieren lassen (NEU: Wir übergeben emp_id als Personalnummer!)
    pdf_generator.generate_timesheet_acroform(emp_name, emp_id, year, month, entries, template_path, filepath)
    
    # 5. An den Nutzer senden
    return FileResponse(filepath, filename=filename, media_type='application/pdf')

# --- ROUTEN: ZEITERFASSUNG ---

@app.post("/time/start")
async def route_time_start(entry: TimerData, current_user: dict = Depends(get_current_user)):
    return time_tracking.start_timer(entry)

@app.post("/time/stop")
async def route_time_stop(entry: TimerData, current_user: dict = Depends(get_current_user)):
    return time_tracking.stop_timer(entry)

@app.post("/time/manual")
async def route_add_manual(data: ManualEntryData, current_user: dict = Depends(get_current_user)):
    # KORREKTUR: Nutze duration_minutes und break_minutes passend zum neuen ManualEntryData Modell
    return time_tracking.add_manual_entry(data.emp_id, data.date, data.duration_minutes, data.project, data.break_minutes)

@app.get("/time/stats/daily")
async def route_daily_stats(emp_id: str, date: str, current_user: dict = Depends(get_current_user)):
    return time_tracking.get_daily_stats(emp_id, date)

@app.get("/time/is_locked")
async def route_check_locked(emp_id: str, date: str, current_user: dict = Depends(get_current_user)):
    return time_tracking.check_is_locked(emp_id, date)

@app.post("/time/submit_day")
async def route_submit_day(data: SubmitDayData, current_user: dict = Depends(get_current_user)):
    return time_tracking.submit_day(data.emp_id, data.date)

@app.post("/time/request_correction")
async def route_request_correction(data: CorrectionData, current_user: dict = Depends(get_current_user)):
    return time_tracking.request_correction(data.emp_id, data.date, data.note)

@app.get("/time/locked_days")
def locked_days(emp_id: str, month: int, year: int, current_user: dict = Depends(get_current_user)):
    return get_locked_days_for_month(emp_id, month, year)

# --- ADMIN-PANEL ROUTEN (GESCHÜTZT) ---

@app.get("/admin/pending_absences")
def route_get_pending(admin: dict = Depends(require_admin)):
    return absences.get_pending_requests()

@app.post("/admin/approve_absence")
def route_approve(absence_id: int, status: str, admin: dict = Depends(require_admin)):
    return absences.update_absence_status(absence_id, status, admin["sub"])

@app.get("/admin/pending_times")
def route_get_pending_times(admin: dict = Depends(require_admin)):
    return time_tracking.get_all_pending_submissions()

@app.post("/time/admin/approve_day")
async def route_admin_approve_day(data: SubmitDayData, admin: dict = Depends(require_admin)):
    return time_tracking.admin_approve_full_day(data.emp_id, data.date)

# --- ROUTEN: URLAUB ---

@app.post("/time/request_vacation")
def route_request_vacation(req: VacationRequest, current_user: dict = Depends(get_current_user)):
    return absences.create_vacation_request(req)

@app.get("/absences/me")
def route_my_absences(emp_id: str, current_user: dict = Depends(get_current_user)):
    # SICHERHEITS-CHECK: Nur eigene Daten oder Admin
    if current_user.get("sub") != emp_id and current_user.get("role") != "Admin":
        raise HTTPException(status_code=403, detail="Keine Berechtigung für diese Abwesenheitsdaten")
    return absences.get_user_absences(emp_id)

@app.get("/absences/calendar")
def route_team_calendar(year: int, month: int, current_user: dict = Depends(get_current_user)):
    return absences.get_approved_absences_in_range(year, month)

# --- DASHBOARD & SYSTEM ---

@app.get("/dashboard/stats")
def route_get_dashboard_stats(emp_id: str, current_user: dict = Depends(get_current_user)):
    # SICHERHEITS-CHECK: Nur eigene Daten oder Admin
    if current_user.get("sub") != emp_id and current_user.get("role") != "Admin":
        raise HTTPException(status_code=403, detail="Keine Berechtigung für diese Statistiken")
    return dashboard.get_stats(emp_id)

@app.post("/system/report_bug")
async def route_report_bug(data: bug_system.BugReportData):
    return bug_system.save_bug_report(data)

# --- NOTIFICATIONS ---

@app.get("/notifications/me")
def route_get_my_notifications(current_user: dict = Depends(get_current_user)):
    return notifications.get_unread_notifications(current_user["sub"])

@app.post("/notifications/{nid}/read")
def route_mark_read(nid: int, current_user: dict = Depends(get_current_user)):
    notifications.mark_as_read(nid)
    return {"status": "ok"}

@app.get("/notifications/history")
def route_get_notification_history(current_user: dict = Depends(get_current_user)):
    from psycopg2.extras import RealDictCursor
    with database.get_db_connection() as conn:
        # Cursor explizit als RealDictCursor für JSON-Kompatibilität
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT id, message, type, is_read, created_at 
            FROM notifications 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            ORDER BY created_at DESC LIMIT 20
        """, (current_user["sub"],))
        return cur.fetchall()

@app.post("/time/admin/reject_day")
async def route_admin_reject_day(data: CorrectionData, admin: dict = Depends(require_admin)):
    return time_tracking.admin_reject_day(data.emp_id, data.date, data.note)

@app.get("/time/entries")
async def route_get_time_entries(emp_id: str, current_user: dict = Depends(get_current_user)):
    # Sicherheitsscheck: Nur eigene Daten oder Admin darf zugreifen
    if current_user.get("sub") != emp_id and current_user.get("role") != "Admin":
        raise HTTPException(status_code=403, detail="Keine Berechtigung für diese Daten")
    
    return time_tracking.get_entries_by_employee(emp_id)

@app.get("/admin/pending_corrections")
async def route_get_pending_corrections(admin: dict = Depends(require_admin)):
    return time_tracking.get_pending_corrections()

# --- STARTUP ---

@app.on_event("startup")
def on_startup():
    services.init_services_table()
    templates.init_templates_table()
    customers.init_customers_table()
    performance.init_performance_table()

@app.get("/")
def health_check():
    return {"status": "online", "message": "CheckX Backend ist bereit"}

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)