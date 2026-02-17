extends Node

# Signale für die UI
signal data_updated
signal login_completed(success: bool, message: String)

# Lokaler Cache für die UI
var employees = []
var time_entries = []
var active_timer_state = {} 
var current_user = {} 

# HTTP Client Nodes
var http_client: HTTPRequest
var login_http: HTTPRequest

func _ready() -> void:
	# Separate Clients für parallele Anfragen
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_data_request_completed)
	
	login_http = HTTPRequest.new()
	add_child(login_http)
	login_http.request_completed.connect(_on_login_request_completed)

# --- URL MANAGEMENT ---
func get_api_url() -> String:
	var url = Config.get_value("system", "server_url", "http://127.0.0.1:8000")
	return url.trim_suffix("/")

# --- AUTHENTIFIZIERUNG (LOGIN & REGISTER) ---

func login(email: String, password: String) -> void:
	var url = get_api_url() + "/auth/login"
	var body = JSON.stringify({"email": email, "password": password})
	var headers = ["Content-Type: application/json"]
	
	print("Login Versuch bei: ", url)
	login_http.request(url, headers, HTTPClient.METHOD_POST, body)

# NEU: Die fehlende Register-Funktion
func register(first_name: String, last_name: String, email: String, password: String) -> void:
	var url = get_api_url() + "/auth/register"
	var body = JSON.stringify({
		"first_name": first_name,
		"last_name": last_name,
		"email": email,
		"password": password
	})
	var headers = ["Content-Type: application/json"]
	
	print("Registrierung Versuch bei: ", url)
	login_http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_login_request_completed(_result, response_code, _headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200:
		if json and json.has("user"):
			# Login war erfolgreich
			current_user = json["user"]
			fetch_employees() 
			emit_signal("login_completed", true, "Willkommen " + current_user.get("name", ""))
		else:
			# Registrierung war erfolgreich (Server schickt kein User-Objekt zurück)
			emit_signal("login_completed", true, "Konto erfolgreich erstellt! Bitte einloggen.")
	else:
		# Fehlerbehandlung: Versuche die Fehlermeldung vom Server (Python) zu lesen
		var error_msg = "Fehler: " + str(response_code)
		if json is Dictionary and json.has("detail"):
			error_msg = json["detail"]
		
		if response_code == 401:
			error_msg = "Zugangsdaten falsch"
		elif response_code == 0:
			error_msg = "Server nicht erreichbar!"
			
		emit_signal("login_completed", false, error_msg)

func get_current_user_id() -> String:
	return current_user.get("emp_id", "")

# --- DATEN LADEN ---
func fetch_employees() -> void:
	var url = get_api_url() + "/employees"
	http_client.request(url)

func _on_data_request_completed(_result, response_code, _headers, body):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json is Array:
			employees = json
			emit_signal("data_updated")
			print("Mitarbeiterliste aktualisiert: ", employees.size())

# --- ZEITERFASSUNG ---
func start_timer(project: String = "Allgemein") -> void:
	var emp_id = get_current_user_id()
	if emp_id.is_empty(): return
	
	active_timer_state[emp_id] = Time.get_unix_time_from_system()
	
	var url = get_api_url() + "/time/start"
	var body = {
		"emp_id": emp_id,
		"project": project,
		"start_time": Time.get_unix_time_from_system()
	}
	_send_post(url, body)

func stop_timer(_project: String, notes: String = "") -> void:
	# _project mit Unterstrich versehen, um die Warnung zu beheben
	var emp_id = get_current_user_id()
	if emp_id.is_empty(): return
	
	active_timer_state.erase(emp_id)
	
	var url = get_api_url() + "/time/stop"
	var body = {
		"emp_id": emp_id,
		"end_time": Time.get_unix_time_from_system(),
		"notes": notes
	}
	_send_post(url, body)

func _send_post(url: String, data: Dictionary) -> void:
	var json = JSON.stringify(data)
	var headers = ["Content-Type: application/json"]
	var temp_client = HTTPRequest.new()
	add_child(temp_client)
	temp_client.request_completed.connect(func(_r, _c, _h, _b): temp_client.queue_free())
	temp_client.request(url, headers, HTTPClient.METHOD_POST, json)

# --- UI HELPER ---
func get_all_employees() -> Array: return employees
func get_employee_count() -> int: return employees.size()
func is_timer_running(emp_id: String) -> bool: return active_timer_state.has(emp_id)
func get_timer_start(emp_id: String) -> float: return active_timer_state.get(emp_id, 0.0)


# --- ABFRAGEN (CACHE) ---

# Gibt alle Einträge für einen bestimmten Mitarbeiter an einem Datum zurück
func get_entries_for_date(emp_id: String, date_str: String) -> Array:
	return time_entries.filter(func(e): 
		return str(e.get("emp_id")) == emp_id and e.get("date") == date_str
	)

# Gibt die gesamte Historie eines Mitarbeiters zurück
func get_entries_by_employee(emp_id: String) -> Array:
	return time_entries.filter(func(e): 
		return str(e.get("emp_id")) == emp_id
	)

func request_vacation(emp_id: String, start_date: String, end_date: String, type: String) -> void:
	var url = get_api_url() + "/time/request_vacation"
	var body = {
		"emp_id": emp_id,
		"start_date": start_date,
		"end_date": end_date,
		"vacation_type": type
	}
	_send_post(url, body)
