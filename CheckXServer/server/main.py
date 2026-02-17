from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, List
import auth
import employees
import absences # Dieses Modul muss im Server-Ordner existieren
import database

app = FastAPI(title="CheckX API")

# --- DATENMODELLE (PYDANTIC) ---

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

# --- ROUTEN: ZEITERFASSUNG ---

@app.post("/time/start")
def route_time_start(entry: TimeEntry):
    # Logik für Start (Konsolenausgabe zur Prüfung)
    print(f"Timer Start: {entry.emp_id} für Projekt {entry.project}")
    return {"status": "ok"}

@app.post("/time/stop")
def route_time_stop(entry: TimeEntry):
    # Logik für Stop
    print(f"Timer Stop: {entry.emp_id}")
    return {"status": "ok"}

# --- ROUTEN: ADMIN & URLAUB (ABSENCES) ---

@app.post("/time/request_vacation")
def route_request_vacation(req: VacationRequest):
    """Mitarbeiter beantragt Urlaub"""
    return absences.create_vacation_request(req)

@app.get("/admin/pending_absences")
def route_get_pending():
    """Admin fragt offene Anträge ab"""
    return absences.get_pending_requests()

@app.post("/admin/approve_absence")
def route_approve(absence_id: int, status: str, admin_id: str):
    """Admin genehmigt oder lehnt Antrag ab"""
    # status: 'approved' oder 'rejected'
    return absences.update_absence_status(absence_id, status, admin_id)

# --- SYSTEM-START ---

@app.get("/")
def health_check():
    return {"status": "online", "message": "CheckX Backend ist bereit"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)