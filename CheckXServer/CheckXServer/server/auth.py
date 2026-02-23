from fastapi import HTTPException
from passlib.hash import bcrypt
from database import get_db_connection
from datetime import datetime, timedelta
from jose import jwt, JWTError
import os
import random
from dotenv import load_dotenv
from fastapi_mail import ConnectionConfig, FastMail, MessageSchema, MessageType

# Lädt die Variablen aus der .env Datei
load_dotenv()

# --- KONFIGURATION ---
# Sicherheitsprüfung: Server stoppt, wenn kein Key vorhanden ist
SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("FEHLER: SECRET_KEY ist nicht in der .env gesetzt! Der Server wurde aus Sicherheitsgründen gestoppt.")

ALGORITHM = "HS256"
EXPIRE_DAYS = int(os.getenv("ACCESS_TOKEN_EXPIRE_DAYS", 30))

# E-Mail Konfiguration für fastapi-mail
conf = ConnectionConfig(
    MAIL_USERNAME = os.getenv("MAIL_USERNAME"),
    MAIL_PASSWORD = os.getenv("MAIL_PASSWORD"),
    MAIL_FROM = os.getenv("MAIL_FROM"),
    MAIL_PORT = int(os.getenv("MAIL_PORT", 587)),
    MAIL_SERVER = os.getenv("MAIL_SERVER"),
    MAIL_STARTTLS = True,
    MAIL_SSL_TLS = False,
    USE_CREDENTIALS = True
)

# --- TOKEN LOGIK ---

def create_access_token(data: dict):
    """
    Generiert einen verschlüsselten JWT-Token für den normalen Login.
    """
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def create_password_reset_token(email: str):
    """
    Erstellt einen kurzlebigen Token (15 Min) speziell für den Passwort-Reset.
    """
    expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode = {"exp": expire, "sub": email, "type": "password_reset"}
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

# --- E-MAIL VERSAND ---

async def send_reset_email(email: str, token: str):
    """
    Verschickt die E-Mail mit dem Reset-Token asynchron.
    """
    # Hinweis: Der Link muss später auf deine Domain oder dein Godot-Protokoll zeigen
    reset_link = f"checkx://reset-password?token={token}"
    
    message = MessageSchema(
        subject="CheckX: Passwort zurücksetzen",
        recipients=[email],
        body=f"""Hallo,

Sie haben eine Anfrage zum Zurücksetzen Ihres Passworts für CheckX gestellt.
Bitte nutzen Sie den folgenden Link oder geben Sie den Code in der App ein:

Link: {reset_link}

Dieser Link ist aus Sicherheitsgründen nur 15 Minuten gültig.
Falls Sie diese Anfrage nicht gestellt haben, können Sie diese E-Mail ignorieren.""",
        subtype=MessageType.plain
    )
    
    fm = FastMail(conf)
    await fm.send_message(message)

# --- BENUTZERVERWALTUNG ---

def register_user(user_data):
    """
    Registriert einen neuen Mitarbeiter und legt automatisch Urlaubsquoten an.
    """
    with get_db_connection() as conn:
        cur = conn.cursor()
        
        # Prüfen, ob Email bereits existiert
        cur.execute("SELECT id FROM employees WHERE email = %s", (user_data.email,))
        if cur.fetchone():
            raise HTTPException(status_code=400, detail="Email bereits vergeben")
        
        # Passwort hashen und Personal-Nummer generieren
        hashed_pw = bcrypt.hash(user_data.password)
        new_emp_id = f"P-{random.randint(1000, 9999)}"
        
        try:
            # Mitarbeiter in die Datenbank schreiben
            cur.execute("""
                INSERT INTO employees (emp_id, email, password_hash, first_name, last_name, role)
                VALUES (%s, %s, %s, %s, %s, 'Prüfer') RETURNING id
            """, (new_emp_id, user_data.email, hashed_pw, user_data.first_name, user_data.last_name))
            
            new_id = cur.fetchone()['id']
            
            # Standard-Urlaubstage (30 Tage) für das aktuelle Jahr vergeben
            cur.execute("INSERT INTO quotas (employee_id, year, vacation_days_total) VALUES (%s, %s, 30)", 
                        (new_id, datetime.now().year))
            
            conn.commit()
            return {"status": "success"}
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=str(e))

def login_user(login_data):
    """
    Prüft die Anmeldedaten und gibt bei Erfolg den JWT-Token und die Nutzerdaten zurück.
    """
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM employees WHERE email = %s", (login_data.email,))
        emp = cur.fetchone()
    
    # Nutzer prüfen und Passwort verifizieren
    if not emp or not bcrypt.verify(login_data.password, emp['password_hash']):
        raise HTTPException(status_code=401, detail="Zugangsdaten falsch")
    
    # JWT Token erstellen (Inhalt: Personal-ID und Rolle)
    access_token = create_access_token(
        data={"sub": emp['emp_id'], "role": emp['role']}
    )
    
    # Die Antwortstruktur für Godot
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "emp_id": emp['emp_id'], 
            "name": f"{emp['first_name']} {emp['last_name']}", 
            "role": emp['role']
        }
    }

def reset_password_in_db(token: str, new_password: str):
    """
    Validiert den Token und überschreibt das Passwort in der Datenbank.
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "password_reset":
            raise HTTPException(status_code=400, detail="Ungültiger Token-Typ")
        
        email = payload.get("sub")
    except JWTError:
        raise HTTPException(status_code=401, detail="Token abgelaufen oder ungültig")
    
    hashed_pw = bcrypt.hash(new_password)
    
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("UPDATE employees SET password_hash = %s WHERE email = %s", (hashed_pw, email))
        conn.commit()
        
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Benutzer nicht gefunden")
            
    return {"status": "success", "message": "Passwort wurde erfolgreich geändert"}