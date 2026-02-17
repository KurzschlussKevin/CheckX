from fastapi import FastAPI
from pydantic import BaseModel
import auth
import employees

app = FastAPI(title="CheckX API")

# Modelle für die Datenübertragung
class UserRegister(BaseModel):
    first_name: str
    last_name: str
    email: str
    password: str

class UserLogin(BaseModel):
    email: str
    password: str

# ROUTES
@app.post("/auth/register")
def route_register(user: UserRegister):
    return auth.register_user(user)

@app.post("/auth/login")
def route_login(user: UserLogin):
    return auth.login_user(user)

@app.get("/employees")
def route_get_employees():
    return employees.list_all_employees()