from database import get_db_connection
from fastapi import HTTPException
from pydantic import BaseModel
from typing import Optional

class BugReportData(BaseModel):
    emp_id: str
    module: str
    error_message: str
    stack_trace: Optional[str] = ""
    device_info: Optional[str] = ""

def save_bug_report(data: BugReportData):
    with get_db_connection() as conn:
        cur = conn.cursor()
        try:
            cur.execute("""
                INSERT INTO bug_reports (employee_id, module, error_message, stack_trace, device_info)
                VALUES ((SELECT id FROM employees WHERE emp_id = %s), %s, %s, %s, %s)
            """, (data.emp_id, data.module, data.error_message, data.stack_trace, data.device_info))
            conn.commit()
            return {"status": "success", "message": "Bug-Report wurde gespeichert."}
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=f"Fehler beim Speichern des Reports: {str(e)}")