from fastapi import FastAPI, HTTPException, Depends
from fastapi.responses import FileResponse
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from pydantic import BaseModel
from typing import Optional, List
import os
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
import notifications # Neuer Import

# Import von spezifischen Funktionen für die Zeiterfassung
from time_tracking import get_locked_days_for_month

app = FastAPI(title="CheckX API")

# Konfiguration für OAuth2 / JWT
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

# --- AUTH-HILFSFUNKTIONEN ---

def get_current_user(token: str = Depends(oauth2_scheme)):
    """Validiert den JWT-Token und gibt die Payload zurück."""
    try:
        payload = jwt.decode(token, auth.SECRET_KEY, algorithms=[auth.ALGORITHM])
        emp_id: str = payload.get("sub")
        if emp_id is None:
            raise HTTPException(status_code=401, detail="Ungültiger Token")
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Sitzung abgelaufen oder ungültig")

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

class TimerData(BaseModel):
    emp_id: str
    project: Optional[str] = ""
    start_time: Optional[float] = None
    end_time: Optional[float] = None
    notes: Optional[str] = ""

class ManualEntryData(BaseModel):
    emp_id: str
    date: str
    duration: int
    project: str

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
def route_register(user: UserRegister):
    return auth.register_user(user)

@app.post("/auth/login")
def route_login(user: UserLogin):
    return auth.login_user(user)

# --- ROUTEN: MITARBEITER ---

@app.get("/employees")
def route_get_employees(current_user: dict = Depends(get_current_user)):
    return employees.list_all_employees()

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
    return performance.get_performance_by_employee(emp_id)

@app.get("/performance/progress")
def route_get_progress(customer_id: int, current_user: dict = Depends(get_current_user)):
    return performance.get_customer_progress(customer_id)

# --- ROUTEN: PDF EXPORT ---

@app.get("/export/pdf/performance/{pid}")
def route_export_pdf(pid: int, current_user: dict = Depends(get_current_user)):
    data = performance.get_report_data(pid)
    if not data:
        raise HTTPException(status_code=404, detail="Bericht nicht gefunden")
    
    if not os.path.exists("temp"):
        os.makedirs("temp")
    
    filename = f"Montagebericht_{pid}.pdf"
    filepath = f"temp/{filename}"
    
    pdf_generator.create_performance_pdf(data, filepath)
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
    return time_tracking.add_manual_entry(data.emp_id, data.date, data.duration, data.project)

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
    # Wir nehmen die admin_id aus dem Token (sub)
    return absences.update_absence_status(absence_id, status, admin["sub"])

@app.get("/admin/pending_times")
def route_get_pending_times(admin: dict = Depends(require_admin)):
    """Holt alle eingereichten Arbeitstage, die auf Freigabe warten."""
    return time_tracking.get_all_pending_submissions()

@app.post("/time/admin/approve_day")
async def route_admin_approve_day(data: SubmitDayData, admin: dict = Depends(require_admin)):
    return time_tracking.admin_approve_full_day(data.emp_id, data.date)

# --- ROUTEN: URLAUB (Nutzer) ---

@app.post("/time/request_vacation")
def route_request_vacation(req: VacationRequest, current_user: dict = Depends(get_current_user)):
    return absences.create_vacation_request(req)

@app.get("/absences/me")
def route_my_absences(emp_id: str, current_user: dict = Depends(get_current_user)):
    return absences.get_user_absences(emp_id)

@app.get("/absences/calendar")
def route_team_calendar(year: int, month: int, current_user: dict = Depends(get_current_user)):
    return absences.get_approved_absences_in_range(year, month)

# --- DASHBOARD & SYSTEM ---

@app.get("/dashboard/stats")
def route_get_dashboard_stats(emp_id: str, current_user: dict = Depends(get_current_user)):
    return dashboard.get_stats(emp_id)

@app.post("/system/report_bug")
async def route_report_bug(data: bug_system.BugReportData):
    # Bug Reports lassen wir ohne Auth zu, falls die App mal gar nicht einloggt
    return bug_system.save_bug_report(data)

# --- NOTIFICATION ---
@app.get("/notifications/me")
def route_get_my_notifications(current_user: dict = Depends(get_current_user)):
    return notifications.get_unread_notifications(current_user["sub"])

@app.post("/notifications/{nid}/read")
def route_mark_read(nid: int, current_user: dict = Depends(get_current_user)):
    notifications.mark_as_read(nid)
    return {"status": "ok"}

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