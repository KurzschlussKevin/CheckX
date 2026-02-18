from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import Optional, List
from database import get_db_conn
import os
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

class TimeEntry(BaseModel):
    emp_id: str
    project: str
    start_time: Optional[float] = None
    end_time: Optional[float] = None
    notes: Optional[str] = ""

class VacationRequest(BaseModel):
    emp_id: str
    start_date: str
    end_date: str
    vacation_type: str

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
    # 1. Daten aus der DB holen
    data = performance.get_report_data(pid)
    if not data:
        raise HTTPException(status_code=404, detail="Bericht nicht gefunden")
    
    # 2. Temp-Ordner sicherstellen
    if not os.path.exists("temp"):
        os.makedirs("temp")
    
    filename = f"Montagebericht_{pid}.pdf"
    filepath = f"temp/{filename}"
    
    # 3. PDF generieren
    pdf_generator.create_performance_pdf(data, filepath)
    
    # 4. Als Datei zurückgeben
    return FileResponse(filepath, filename=filename, media_type='application/pdf')

# --- ROUTEN: ZEITERFASSUNG & URLAUB ---

@app.post("/time/start")
def route_time_start(entry: TimeEntry):
    return time_tracking.start_timer(entry)

@app.post("/time/stop")
def route_time_stop(entry: TimeEntry):
    return time_tracking.stop_timer(entry)

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

@app.post("/time/manual")
async def route_add_manual_time(data: dict):
    from time_tracking import add_manual_entry
    # Wir reichen die Daten an eine Funktion in der time_tracking.py weiter
    return add_manual_entry(
        data.get("emp_id"),
        data.get("date"),
        data.get("duration"),
        data.get("project")
    )

@app.get("/time/stats/daily")
async def route_daily_stats(emp_id: str, date: str):
    from time_tracking import get_daily_stats
    return get_daily_stats(emp_id, date)

# --- ADMIN ZEIT-FREIGABE ---

@app.post("/time/submit")
async def route_submit_time(data: dict):
    from time_tracking import submit_times_for_approval
    return submit_times_for_approval(data.get("emp_id"), data.get("date"))

@app.post("/time/admin/approve")
async def route_admin_approve(data: dict):
    from time_tracking import admin_approve_time
    return admin_approve_time(data.get("entry_id"))

@app.get("/time/is_locked")
async def route_check_locked(emp_id: str, date: str):
    from database import get_db_conn
    try:
        conn = get_db_conn()
        cur = conn.cursor()
        cur.execute("""
            SELECT is_locked FROM time_entries 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND start_time::date = %s::date
            LIMIT 1
        """, (emp_id, date))
        row = cur.fetchone()
        conn.close()
        
        # Falls kein Eintrag existiert, ist er logischerweise auch nicht gesperrt
        is_locked = row['is_locked'] if row and 'is_locked' in row else False
        return {"is_locked": is_locked}
    except Exception as e:
        print(f"Fehler bei is_locked Abfrage: {e}")
        return {"is_locked": False, "error": str(e)}

@app.post("/time/submit_day")
async def route_submit_day(data: dict):
    from time_tracking import submit_day
    return submit_day(data.get("emp_id"), data.get("date"))
# --- SYSTEM-START ---

@app.on_event("startup")
def on_startup():
    # Die Reihenfolge ist wichtig, da Tabellen voneinander abhängen (Foreign Keys)
    services.init_services_table()
    templates.init_templates_table()
    customers.init_customers_table()
    performance.init_performance_table()

@app.get("/")
def health_check():
    return {"status": "online", "message": "CheckX Backend ist bereit"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)