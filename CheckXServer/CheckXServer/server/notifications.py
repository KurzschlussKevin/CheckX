from database import get_db_connection

def add_notification(emp_id_str, message, msg_type="info"):
    """Erstellt eine Benachrichtigung für einen Mitarbeiter (via P-Nummer)."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO notifications (employee_id, message, type)
            VALUES ((SELECT id FROM employees WHERE emp_id = %s), %s, %s)
        """, (emp_id_str, message, msg_type))
        conn.commit()

def get_unread_notifications(emp_id_str):
    """Holt alle ungelesenen Nachrichten eines Nutzers."""
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT id, message, type, created_at 
            FROM notifications 
            WHERE employee_id = (SELECT id FROM employees WHERE emp_id = %s)
            AND is_read = FALSE
            ORDER BY created_at DESC
        """, (emp_id_str,))
        return cur.fetchall()

def mark_as_read(notification_id):
    with get_db_connection() as conn:
        cur = conn.cursor()
        cur.execute("UPDATE notifications SET is_read = TRUE WHERE id = %s", (notification_id,))
        conn.commit()