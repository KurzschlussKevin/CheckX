extends Node

# Dies ist dein lokaler Cache.
var employees = [
	{
		"name": "Max Admin", "role": "Admin", "dept": "SYS", 
		"mail": "admin@checkx.de", "phone": "+49 123 4567", 
		"emp_id": "001", "skills": ["Security", "Linux"], "bday": true
	},
	{
		"name": "Erika Office", "role": "BackOffice", "dept": "HQ", 
		"mail": "office@checkx.de", "phone": "+49 234 5678", 
		"emp_id": "022", "skills": ["Planung", "Orga"], "bday": false
	},
	{
		"name": "Kevin Prüf", "role": "Prüfer", "dept": "QA", 
		"mail": "check@checkx.de", "phone": "+49 987 6543", 
		"emp_id": "089", "skills": ["ISO-Audit"], "bday": false
	}
]

# --- API FÜR DEINE UI ---

func get_all_employees() -> Array:
	return employees

func add_employee(data: Dictionary) -> void:
	employees.append(data)

func update_employee(original_ref: Dictionary, new_data: Dictionary) -> void:
	original_ref.merge(new_data, true)

func get_employee_count() -> int:
	return employees.size()


# --- ZEITERFASSUNG ---

var time_entries = []
var active_sessions = {} 

func start_timer(emp_id: String) -> void:
	active_sessions[emp_id] = Time.get_unix_time_from_system()

# KORRIGIERT: Akzeptiert jetzt 'notes' als 3. Parameter
func stop_timer(emp_id: String, project: String, notes: String = "") -> void:
	if not active_sessions.has(emp_id): return
	var start = active_sessions[emp_id]
	var end = Time.get_unix_time_from_system()
	
	var entry = _create_entry_struct(emp_id, start, end, project, "open", notes)
	time_entries.append(entry)
	active_sessions.erase(emp_id)

# KORRIGIERT: Akzeptiert jetzt 'notes'
func add_manual_entry(emp_id: String, date_str: String, duration_min: int, project: String, notes: String = "") -> void:
	var now = Time.get_unix_time_from_system()
	var entry = _create_entry_struct(emp_id, now, now + (duration_min * 60), project, "open", notes)
	entry["date"] = date_str 
	time_entries.append(entry)

func request_change(entry_id: String, reason: String) -> void:
	for e in time_entries:
		if e.id == entry_id:
			e.status = "request_change"
			e.change_reason = reason

func admin_approve_entry(entry_id: String) -> void:
	for e in time_entries:
		if e.id == entry_id:
			e.status = "locked"
			e.change_reason = ""

# Hilfsfunktion
func _create_entry_struct(emp_id, start, end, proj, status, notes = "") -> Dictionary:
	return {
		"id": str(randi()),
		"emp_id": emp_id,
		"start": start,
		"end": end,
		"duration": end - start,
		"project": proj,
		"notes": notes, # Neues Feld
		"date": Time.get_date_string_from_system(),
		"status": status,
		"change_reason": ""
	}

func get_entries_for_date(emp_id: String, date_str: String) -> Array:
	return time_entries.filter(func(e): return e.emp_id == emp_id and e.date == date_str)

func is_timer_running(emp_id: String) -> bool: return active_sessions.has(emp_id)
func get_timer_start(emp_id: String) -> float: return active_sessions.get(emp_id, 0.0)
func get_entries_by_employee(emp_id: String) -> Array: return time_entries.filter(func(e): return e.emp_id == emp_id)
