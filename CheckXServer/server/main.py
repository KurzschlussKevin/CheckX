from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import Optional, List
from database import get_db_conn
from time_tracking import check_is_locked
from time_tracking import get_locked_days_for_month
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

app = FastAPI(title="CheckX API")

# --- DATENMODELLE ---

class UserRegister(BaseModel):
    first_name: str
    last_name: str
    email: str
    password: str

class UserLogin(BaseModel):
    email: str
    password: str

# UPDATE: Erweiterte Modelle für die Zeiterfassung
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
def route_get_employees():
    return employees.list_all_employees()

# --- ROUTEN: SERVICES (KATALOG) ---

@app.get("/services")
def route_get_services():
    return services.get_all_services()

@app.post("/services")
def route_create_service(s: services.ServiceModel):
    return services.create_service(s)

# --- ROUTEN: VORLAGEN (TEMPLATES) ---

@app.get("/templates")
def route_get_templates():
    return templates.get_all_templates()

@app.get("/templates/{tid}")
def route_get_template_details(tid: int):
    return templates.get_template_details(tid)

@app.post("/templates")
def route_create_template(t: templates.TemplateCreate):
    return templates.create_template(t)

# --- ROUTEN: KUNDEN ---

@app.get("/customers")
def route_get_customers():
    return customers.get_active_customers()

@app.post("/customers")
def route_create_customer(c: customers.CustomerModel):
    return customers.create_customer(c)

@app.put("/customers")
def route_update_customer(c: customers.CustomerModel):
    return customers.update_customer(c)

@app.post("/customers/{cid}/targets")
def route_set_targets(cid: int, targets: List[customers.CustomerTarget]):
    return customers.set_customer_targets(cid, targets)

@app.get("/customers/{cid}/targets")
def route_get_targets(cid: int):
    return customers.get_customer_targets(cid)

# --- ROUTEN: PERFORMANCE (LEISTUNG) ---

@app.post("/performance")
def route_add_performance(p: performance.DailyPerformance):
    return performance.add_performance_entry(p)

@app.get("/performance/me")
def route_get_my_performance(emp_id: str):
    return performance.get_performance_by_employee(emp_id)

@app.get("/performance/progress")
def route_get_progress(customer_id: int):
    return performance.get_customer_progress(customer_id)

# --- ROUTEN: PDF EXPORT ---

@app.get("/export/pdf/performance/{pid}")
def route_export_pdf(pid: int):
    data = performance.get_report_data(pid)
    if not data:
        raise HTTPException(status_code=404, detail="Bericht nicht gefunden")
    
    if not os.path.exists("temp"):
        os.makedirs("temp")
    
    filename = f"Montagebericht_{pid}.pdf"
    filepath = f"temp/{filename}"
    
    pdf_generator.create_performance_pdf(data, filepath)
    return FileResponse(filepath, filename=filename, media_type='application/pdf')

# --- ROUTEN: ZEITERFASSUNG (AKTUALISIERT) ---

@app.post("/time/start")
async def route_time_start(entry: TimerData):
    return time_tracking.start_timer(entry)

@app.post("/time/stop")
async def route_time_stop(entry: TimerData):
    return time_tracking.stop_timer(entry)

@app.post("/time/manual")
async def route_add_manual(data: ManualEntryData):
    return time_tracking.add_manual_entry(data.emp_id, data.date, data.duration, data.project)

@app.get("/time/stats/daily")
async def route_daily_stats(emp_id: str, date: str):
    return time_tracking.get_daily_stats(emp_id, date)

# --- NEUE ROUTEN: SPERREN & WORKFLOW ---

@app.get("/time/is_locked")
async def route_check_locked(emp_id: str, date: str):
    # Ruft die Logik aus time_tracking.py auf
    return time_tracking.check_is_locked(emp_id, date)

@app.post("/time/submit_day")
async def route_submit_day(data: SubmitDayData):
    return time_tracking.submit_day(data.emp_id, data.date)

@app.post("/time/admin/approve_day")
async def route_admin_approve_day(data: SubmitDayData):
    return time_tracking.admin_approve_full_day(data.emp_id, data.date)

@app.post("/time/request_correction")
async def route_request_correction(data: CorrectionData):
    from time_tracking import request_correction
    return request_correction(data.emp_id, data.date, data.note)

@app.get("/time/is_locked")
def is_locked(emp_id: str, date: str):
    return check_is_locked(emp_id, date)

@app.get("/time/locked_days")
def locked_days(emp_id: str, month: int, year: int):
    return get_locked_days_for_month(emp_id, month, year)

# --- ROUTEN: URLAUB ---

@app.post("/time/request_vacation")
def route_request_vacation(req: VacationRequest):
    return absences.create_vacation_request(req)

@app.get("/admin/pending_absences")
def route_get_pending():
    return absences.get_pending_requests()

@app.post("/admin/approve_absence")
def route_approve(absence_id: int, status: str, admin_id: str):
    return absences.update_absence_status(absence_id, status, admin_id)

@app.get("/absences/me")
def route_my_absences(emp_id: str):
    return absences.get_user_absences(emp_id)

@app.get("/absences/calendar")
def route_team_calendar(year: int, month: int):
    return absences.get_approved_absences_in_range(year, month)

# --- DASHBOARD ---
@app.get("/dashboard/stats")
def route_get_dashboard_stats(emp_id: str):
    return dashboard.get_stats(emp_id)

# --- SYSTEM-START ---

@app.on_event("startup")
def on_startup():
    # Tabellen initialisieren
    services.init_services_table()
    templates.init_templates_table()
    customers.init_customers_table()
    performance.init_performance_table()

@app.get("/")
def health_check():
    return {"status": "online", "message": "CheckX Backend ist bereit"}

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)