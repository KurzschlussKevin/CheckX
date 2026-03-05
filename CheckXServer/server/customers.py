from database import get_db_connection  # Geändert von get_db_conn auf get_db_connection
from fastapi import HTTPException
from pydantic import BaseModel
from typing import Optional, List

class CustomerModel(BaseModel):
    id: Optional[int] = None
    company_name: str
    street: str = ""
    house_number: str = ""
    zip_code: str = ""
    city: str = ""
    country: str = "Deutschland"
    has_billing_address: bool = False
    billing_street: str = ""
    billing_house_number: str = ""
    billing_zip_code: str = ""
    billing_city: str = ""
    cp1_firstname: str = ""
    cp1_lastname: str = ""
    cp1_phone: str = ""
    cp1_email: str = ""
    cp2_firstname: str = ""
    cp2_lastname: str = ""
    cp2_phone: str = ""
    cp2_email: str = ""

# NEU: Mit Preis
class CustomerTarget(BaseModel):
    service_id: int
    target_amount: int
    price: float = 0.0

# --- INIT ---
def init_customers_table():
    with get_db_connection() as conn:
        cur = conn.cursor()
        
        # 1. Haupttabelle
        cur.execute("""
            CREATE TABLE IF NOT EXISTS customers (
                id SERIAL PRIMARY KEY,
                company_name VARCHAR(150) NOT NULL,
                street VARCHAR(100),
                house_number VARCHAR(20),
                zip_code VARCHAR(10),
                city VARCHAR(100),
                country VARCHAR(50) DEFAULT 'Deutschland',
                email VARCHAR(100),
                phone VARCHAR(50),
                
                -- Weitere Felder
                has_billing_address BOOLEAN DEFAULT FALSE,
                billing_street VARCHAR(100),
                billing_house_number VARCHAR(20),
                billing_zip_code VARCHAR(10),
                billing_city VARCHAR(100),
                cp1_firstname VARCHAR(100),
                cp1_lastname VARCHAR(100),
                cp1_phone VARCHAR(50),
                cp1_email VARCHAR(100),
                cp2_firstname VARCHAR(100),
                cp2_lastname VARCHAR(100),
                cp2_phone VARCHAR(50),
                cp2_email VARCHAR(100),
                
                active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        
        # 2. Verknüpfungstabelle (JETZT MIT PREIS)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS customer_targets (
                id SERIAL PRIMARY KEY,
                customer_id INTEGER REFERENCES customers(id) ON DELETE CASCADE,
                service_id INTEGER REFERENCES services(id),
                target_amount INTEGER DEFAULT 0,
                price DECIMAL(10, 2) DEFAULT 0.00,
                UNIQUE(customer_id, service_id)
            );
        """)
        
        conn.commit()

# --- API ---
def create_customer(c: CustomerModel):
    with get_db_connection() as conn:
        cur = conn.cursor()
        try:
            cur.execute("""
                INSERT INTO customers (
                    company_name, street, house_number, zip_code, city, country,
                    has_billing_address, billing_street, billing_house_number, billing_zip_code, billing_city,
                    cp1_firstname, cp1_lastname, cp1_phone, cp1_email,
                    cp2_firstname, cp2_lastname, cp2_phone, cp2_email
                ) VALUES (
                    %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, %s, %s, %s
                ) RETURNING id
            """, (
                c.company_name, c.street, c.house_number, c.zip_code, c.city, c.country,
                c.has_billing_address, c.billing_street, c.billing_house_number, c.billing_zip_code, c.billing_city,
                c.cp1_firstname, c.cp1_lastname, c.cp1_phone, c.cp1_email,
                c.cp2_firstname, c.cp2_lastname, c.cp2_phone, c.cp2_email
            ))
            new_id = cur.fetchone()['id']
            conn.commit()
            return {"status": "success", "id": new_id, "message": "Kunde angelegt"}
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=str(e))

def get_active_customers():
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM customers WHERE active=true ORDER BY company_name ASC")
        return cur.fetchall()

def update_customer(c: CustomerModel):
    if not c.id:
        raise HTTPException(status_code=400, detail="Kunden-ID fehlt")
        
    with get_db_connection() as conn:
        cur = conn.cursor()
        try:
            cur.execute("""
                UPDATE customers SET 
                    company_name = %s, street = %s, house_number = %s, zip_code = %s, city = %s, country = %s,
                    has_billing_address = %s, billing_street = %s, billing_house_number = %s, billing_zip_code = %s, billing_city = %s,
                    cp1_firstname = %s, cp1_lastname = %s, cp1_phone = %s, cp1_email = %s,
                    cp2_firstname = %s, cp2_lastname = %s, cp2_phone = %s, cp2_email = %s
                WHERE id = %s
            """, (
                c.company_name, c.street, c.house_number, c.zip_code, c.city, c.country,
                c.has_billing_address, c.billing_street, c.billing_house_number, c.billing_zip_code, c.billing_city,
                c.cp1_firstname, c.cp1_lastname, c.cp1_phone, c.cp1_email,
                c.cp2_firstname, c.cp2_lastname, c.cp2_phone, c.cp2_email,
                c.id
            ))
            
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Kunde nicht gefunden")
                
            conn.commit()
            return {"status": "success", "message": "Kunde erfolgreich aktualisiert"}
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=str(e))

# --- ZIELE VERWALTEN (MIT PREIS) ---
def set_customer_targets(customer_id: int, targets: List[CustomerTarget]):
    with get_db_connection() as conn:
        cur = conn.cursor()
        try:
            cur.execute("DELETE FROM customer_targets WHERE customer_id = %s", (customer_id,))
            for t in targets:
                cur.execute("""
                    INSERT INTO customer_targets (customer_id, service_id, target_amount, price) 
                    VALUES (%s, %s, %s, %s)
                """, (customer_id, t.service_id, t.target_amount, t.price))
            conn.commit()
            return {"status": "success"}
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=str(e))

def get_customer_targets(customer_id: int):
    with get_db_connection() as conn:
        cur = conn.cursor()
        # Wir laden den Preis mit
        cur.execute("""
            SELECT t.service_id, s.name, t.target_amount, t.price
            FROM customer_targets t
            JOIN services s ON t.service_id = s.id
            WHERE t.customer_id = %s
        """, (customer_id,))
        return cur.fetchall()