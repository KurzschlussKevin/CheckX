from fastapi import HTTPException
from passlib.hash import bcrypt
from database import get_db_connection
from datetime import datetime, timedelta
from jose import jwt
import os
import random
from dotenv import load_dotenv

# Lädt die Variablen aus der .env Datei (SECRET_KEY, etc.)
load_dotenv()

# KONFIGURATION
# Falls kein Key in der .env steht, wird ein Fallback genutzt (nicht empfohlen für Produktion)
SECRET_KEY = os.getenv("SECRET_KEY", "fallback_secret_key_12345")
ALGORITHM = "HS256"
# Die Gültigkeit wird aus der .env gelesen (Standard: 30 Tage)
EXPIRE_DAYS = int(os.getenv("ACCESS_TOKEN_EXPIRE_DAYS", 30))

def create_access_token(data: dict):
    """
    Generiert einen verschlüsselten JWT-Token mit Ablaufdatum.
    """
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=EXPIRE_DAYS)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

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
    
    # Die Antwortstruktur, die Godot für die Speicherung der Session benötigt
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "emp_id": emp['emp_id'], 
            "name": f"{emp['first_name']} {emp['last_name']}", 
            "role": emp['role']
        }
    }