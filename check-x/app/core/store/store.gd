extends Node

# Signale für die UI
signal data_updated
signal login_completed(success: bool, message: String, data: Dictionary)
signal notification_received(message_data: Dictionary) # Signal für Toasts

# Lokaler Cache für die UI und Sitzungsdaten
var token: String = ""
var current_user: Dictionary = {}
var employees: Array = []
var time_entries: Array = [] # WICHTIG: Wird nun befüllt
var active_timer_state: Dictionary = {} 
var current_user_data: Dictionary = {}

const TOKEN_PATH = "user://auth_token.dat"

# HTTP Client Nodes
var http_client: HTTPRequest
var login_http: HTTPRequest
var notification_timer: Timer # Timer für Polling

func _ready() -> void:
	# Separate Clients für parallele Anfragen
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_data_request_completed)
	
	login_http = HTTPRequest.new()
	add_child(login_http)
	login_http.request_completed.connect(_on_login_request_completed)
	
	# Timer für Benachrichtigungen initialisieren
	notification_timer = Timer.new()
	notification_timer.wait_time = 30.0 # Alle 30 Sekunden prüfen
	notification_timer.timeout.connect(_check_for_notifications)
	add_child(notification_timer)
	notification_timer.start()
	
	print("Nutzer-Daten-Pfad: ", OS.get_user_data_dir())
	# Versuche gespeicherten Token beim Start der App zu laden
	load_token()

# --- NOTIFICATION MANAGEMENT ---

func _check_for_notifications() -> void:
	if token.is_empty(): return # Nur prüfen, wenn eingeloggt
	
	var url = get_api_url() + "/notifications/me"
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var notes = JSON.parse_string(body.get_string_from_utf8())
			if notes is Array:
				for n in notes:
					emit_signal("notification_received", n)
					# Nachricht direkt als gelesen markieren
					_mark_notification_as_read(n.id)
		http.queue_free()
	)
	http.request(url, _get_auth_headers())

func _mark_notification_as_read(notif_id: int) -> void:
	var url = get_api_url() + "/notifications/" + str(notif_id) + "/read"
	_send_post(url, {})

# --- TOKEN MANAGEMENT ---

func save_token(new_token: String, user_info: Dictionary) -> void:
	token = new_token
	current_user = user_info
	var file = FileAccess.open(TOKEN_PATH, FileAccess.WRITE)
	if file:
		var data_to_save = {
			"token": token,
			"user": current_user
		}
		file.store_var(data_to_save)
		print(">>> [STORE] Sitzung permanent gespeichert.")

func load_token() -> void:
	if FileAccess.file_exists(TOKEN_PATH):
		var file = FileAccess.open(TOKEN_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			token = data.get("token", "")
			current_user = data.get("user", {})
			if not token.is_empty():
				fetch_all_data() # Automatisches Laden beim Start
			print(">>> [STORE] Sitzung geladen für: ", current_user.get("name", "Unbekannt"))

func clear_session() -> void:
	token = ""
	current_user = {}
	time_entries = []
	if FileAccess.file_exists(TOKEN_PATH):
		DirAccess.remove_absolute(TOKEN_PATH)
	print(">>> [STORE] Sitzung gelöscht.")

# Hilfsfunktion für Header inkl. JWT Token
func _get_auth_headers() -> Array:
	var headers = ["Content-Type: application/json"]
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	return headers

# --- URL MANAGEMENT ---
func get_api_url() -> String:
	var url = Config.get_value("system", "server_url", "http://127.0.0.1:8000")
	return url.trim_suffix("/")

# --- AUTHENTIFIZIERUNG ---

func login(email: String, password: String) -> void:
	var url = get_api_url() + "/auth/login"
	var body = JSON.stringify({"email": email, "password": password})
	var headers = ["Content-Type: application/json"]
	login_http.request(url, headers, HTTPClient.METHOD_POST, body)

func register(first_name: String, last_name: String, email: String, password: String) -> void:
	var url = get_api_url() + "/auth/register"
	var body = JSON.stringify({
		"first_name": first_name,
		"last_name": last_name,
		"email": email,
		"password": password
	})
	var headers = ["Content-Type: application/json"]
	login_http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_login_request_completed(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	var json = JSON.parse_string(body_str)
	
	if response_code == 200:
		if json and json.has("access_token"):
			token = json.get("access_token", "")
			current_user = json.get("user", {})
			save_token(token, current_user)
			fetch_all_data() # Lädt Mitarbeiter UND Zeiteinträge
			emit_signal("login_completed", true, "Willkommen " + current_user.get("name", ""), json)
		else:
			emit_signal("login_completed", true, "Konto erfolgreich erstellt! Bitte einloggen.", {})
	else:
		var error_msg = "Fehler: " + str(response_code)
		if json is Dictionary and json.has("detail"):
			error_msg = json["detail"]
		emit_signal("login_completed", false, error_msg, {})

func get_current_user_id() -> String:
	return current_user.get("emp_id", "")

# --- DATEN LADEN (ZENTRAL) ---

func fetch_all_data() -> void:
	fetch_employees()
	fetch_time_entries()

func fetch_employees() -> void:
	var url = get_api_url() + "/employees"
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json is Array:
				employees = json
				emit_signal("data_updated")
		http.queue_free()
	)
	http.request(url, _get_auth_headers())

func fetch_time_entries() -> void:
	var emp_id = get_current_user_id()
	if emp_id.is_empty(): return
	
	var url = get_api_url() + "/time/entries?emp_id=" + emp_id
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json is Array:
				time_entries = json
				emit_signal("data_updated")
		http.queue_free()
	)
	http.request(url, _get_auth_headers())

func _on_data_request_completed(_result, response_code, _headers, body):
	# Fallback für http_client falls nötig
	pass

# --- ZEITERFASSUNG ---

func start_timer(project: String = "Allgemein") -> void:
	var emp_id = get_current_user_id()
	if emp_id.is_empty(): return
	active_timer_state[emp_id] = Time.get_unix_time_from_system()
	var url = get_api_url() + "/time/start"
	var body = {"emp_id": emp_id, "project": project, "start_time": active_timer_state[emp_id]}
	_send_post(url, body)

func stop_timer(_project: String, notes: String = "") -> void:
	var emp_id = get_current_user_id()
	if emp_id.is_empty(): return
	active_timer_state.erase(emp_id)
	var url = get_api_url() + "/time/stop"
	var body = {"emp_id": emp_id, "end_time": Time.get_unix_time_from_system(), "notes": notes}
	_send_post(url, body)

func _send_post(url: String, data: Dictionary) -> void:
	var json_str = JSON.stringify(data)
	var temp_client = HTTPRequest.new()
	add_child(temp_client)
	temp_client.request_completed.connect(func(_r, code, _h, body_bytes):
		fetch_time_entries() # Daten nach Änderungen neu laden
		temp_client.queue_free()
	)
	temp_client.request(url, _get_auth_headers(), HTTPClient.METHOD_POST, json_str)

# --- UI HELPER & ABFRAGEN ---

func get_all_employees() -> Array: return employees
func get_employee_count() -> int: return employees.size()
func is_timer_running(emp_id: String) -> bool: return active_timer_state.has(emp_id)
func get_timer_start(emp_id: String) -> float: return active_timer_state.get(emp_id, 0.0)
func get_current_user_data() -> Dictionary: return current_user

func get_entries_for_date(emp_id: String, date_str: String) -> Array:
	return time_entries.filter(func(e): 
		return str(e.get("emp_id")) == emp_id and e.get("date") == date_str
	)

func request_vacation(emp_id: String, start_date: String, end_date: String, type: String) -> void:
	var url = get_api_url() + "/time/request_vacation"
	var body = {"emp_id": emp_id, "start_date": start_date, "end_date": end_date, "vacation_type": type}
	_send_post(url, body)

func add_manual_entry(emp_id: String, date_str: String, minutes: int, project: String, type: String = "Manuell") -> void:
	var url = get_api_url() + "/time/manual"
	var body = {"emp_id": emp_id, "date": date_str, "duration": minutes, "project": project, "type": type}
	_send_post(url, body)

func is_day_locked(emp_id: String, date_str: String, callback: Callable) -> void:
	var url = get_api_url() + "/time/is_locked?emp_id=" + emp_id + "&date=" + date_str
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		var locked = false
		if code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json is Dictionary: locked = json.get("is_locked", false)
		callback.call(locked)
		http.queue_free()
	)
	http.request(url, _get_auth_headers())

func submit_day(emp_id: String, date_str: String, callback: Callable) -> void:
	var url = get_api_url() + "/time/submit_day"
	var body = {"emp_id": emp_id, "date": date_str}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body_bytes):
		fetch_time_entries()
		callback.call(code == 200)
		http.queue_free()
	)
	http.request(url, _get_auth_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func request_correction(emp_id: String, date_str: String, note: String, callback: Callable) -> void:
	var url = get_api_url() + "/time/request_correction"
	var body = {"emp_id": emp_id, "date": date_str, "note": note}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body_bytes):
		fetch_time_entries()
		callback.call(code == 200)
		http.queue_free()
	)
	http.request(url, _get_auth_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func get_entries_by_employee(emp_id: String) -> Array:
	return time_entries.filter(func(e): 
		return str(e.get("emp_id")) == emp_id
	)

func get_locked_days_for_month(emp_id: String, month: int, year: int, callback: Callable) -> void:
	var url = get_api_url() + "/time/locked_days?emp_id=" + emp_id + "&month=" + str(month) + "&year=" + str(year)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		var locked_days = []
		if code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json is Dictionary: locked_days = json.get("locked_days", [])
		callback.call(locked_days)
		http.queue_free()
	)
	http.request(url, _get_auth_headers())

func fetch_notification_history(callback: Callable) -> void:
	var url = get_api_url() + "/notifications/history"
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		var history = []
		if code == 200:
			history = JSON.parse_string(body.get_string_from_utf8())
		callback.call(history)
		http.queue_free()
	)
	http.request(url, _get_auth_headers())

func admin_reject_day(emp_id: String, date_str: String, reason: String, callback: Callable) -> void:
	var url = get_api_url() + "/time/admin/reject_day"
	var body = {"emp_id": emp_id, "date": date_str, "note": reason}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body_bytes):
		callback.call(code == 200)
		http.queue_free()
	)
	http.request(url, _get_auth_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
