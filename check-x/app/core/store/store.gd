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
	if token.is_empty(): return
	
	var url = get_api_url() + "/notifications/me"
	var http = HTTPRequest.new()
	add_child(http)
	
	# KORREKTUR: Timeout setzen! Wenn der Server nach 10s nicht antwortet, abbrechen.
	http.timeout = 10.0
	
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200 and body.size() > 0:
			var notes = JSON.parse_string(body.get_string_from_utf8())
			if notes is Array:
				for n in notes:
					emit_signal("notification_received", n)
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
	
	# Passwort für Verschlüsselung generieren (Geräte-ID nutzen)
	var key = OS.get_unique_id()
	var file = FileAccess.open_encrypted_with_pass(TOKEN_PATH, FileAccess.WRITE, key)
	
	if file:
		var data_to_save = {
			"token": token,
			"user": current_user
		}
		file.store_var(data_to_save)
		file.close() # Datei schließen nicht vergessen
		print(">>> [STORE] Sitzung verschlüsselt gespeichert.")

func load_token() -> void:
	if FileAccess.file_exists(TOKEN_PATH):
		var key = OS.get_unique_id()
		var file = FileAccess.open_encrypted_with_pass(TOKEN_PATH, FileAccess.READ, key)
		if file:
			var data = file.get_var()
			file.close()
			token = data.get("token", "")
			current_user = data.get("user", {})
			if not token.is_empty():
				fetch_all_data()
			print(">>> [STORE] Verschlüsselte Sitzung geladen.")

func clear_session() -> void:
	token = ""
	current_user = {}
	time_entries = []
	# KORREKTUR: Alle verbleibenden State-Variablen leeren!
	employees = []
	active_timer_state.clear()
	current_user_data.clear()
	
	if FileAccess.file_exists(TOKEN_PATH):
		DirAccess.remove_absolute(TOKEN_PATH)
	print(">>> [STORE] Sitzung komplett gelöscht.")

# Hilfsfunktion für Header inkl. JWT Token
func _get_auth_headers() -> Array:
	var headers = ["Content-Type: application/json"]
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	return headers

# --- URL MANAGEMENT ---
func get_api_url() -> String:
	# Nutzt die neue API_URL Konstante aus Config, falls vorhanden, sonst Fallback
	if "API_URL" in Config:
		return Config.API_URL
	return Config.get_value("network", "api_url", "http://127.0.0.1:8000").trim_suffix("/")

# --- AUTHENTIFIZIERUNG ---

func login(email: String, password: String) -> void:
	var url = get_api_url() + "/auth/login"
	var body = JSON.stringify({"email": email, "password": password})
	var headers = ["Content-Type: application/json"]
	
	var err = login_http.request(url, headers, HTTPClient.METHOD_POST, body)
	# KORREKTUR: Bei sofortigem Netzwerkfehler manuell den Vorgang abbrechen
	if err != OK:
		emit_signal("login_completed", false, "Netzwerkfehler. Bitte Internetverbindung prüfen.", {})

func register(first_name: String, last_name: String, email: String, password: String) -> void:
	var url = get_api_url() + "/auth/register"
	var body = JSON.stringify({
		"first_name": first_name,
		"last_name": last_name,
		"email": email,
		"password": password
	})
	var headers = ["Content-Type: application/json"]
	
	var err = login_http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		emit_signal("login_completed", false, "Netzwerkfehler. Bitte Internetverbindung prüfen.", {})

func _on_login_request_completed(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	var json = JSON.parse_string(body_str)
	
	if response_code == 200:
		# KORREKTUR: Typen-Check verhindert Crash bei fehlerhaftem JSON
		if json is Dictionary and json.has("access_token"):
			token = json.get("access_token", "")
			current_user = json.get("user", {})
			save_token(token, current_user)
			fetch_all_data()
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
	var err = http.request(url, _get_auth_headers())
	if err != OK: http.queue_free() # NEU HINZUGEFÜGT

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
				var found_running = false
				for entry in time_entries:
					if entry.get("status") == "running":
						var start_unix = entry.get("start_unix", 0)
						if start_unix > 0:
							active_timer_state[emp_id] = start_unix
							found_running = true
							break
				if not found_running and active_timer_state.has(emp_id):
					active_timer_state.erase(emp_id)
				emit_signal("data_updated")
		http.queue_free()
	)
	var err = http.request(url, _get_auth_headers())
	if err != OK: http.queue_free() # NEU HINZUGEFÜGT

func _on_data_request_completed(_result, response_code, _headers, body):
	# Fallback für http_client falls nötig
	pass

# --- PROFIL & EINSTELLUNGEN ---

func update_profile(updated_data: Dictionary) -> void:
	var emp_id = get_current_user_id()
	if emp_id.is_empty(): return
	
	var url = get_api_url() + "/employees/" + str(emp_id)
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		# KORREKTUR: Lokale Speicherung NUR, wenn der Server 200 OK meldet!
		if code == 200:
			for key in updated_data:
				current_user[key] = updated_data[key]
			save_token(token, current_user)
			print("Profil-Update auf Server erfolgreich.")
			emit_signal("data_updated")
		else:
			print("Profil-Update fehlgeschlagen. Lokale Daten bleiben unverändert.")
		http.queue_free()
	)
	
	var err = http.request(url, _get_auth_headers(), HTTPClient.METHOD_PUT, JSON.stringify(updated_data))
	if err != OK:
		print("Netzwerkfehler beim Profil-Update.")
		http.queue_free()

func update_employee(emp_dict: Dictionary, new_values: Dictionary) -> void:
	"""
	Hilfsfunktion zum lokalen Aktualisieren von Mitarbeiterlisten.
	"""
	for key in new_values:
		emp_dict[key] = new_values[key]
	emit_signal("data_updated")

# --- ZEITERFASSUNG ---

func start_timer(project: String = "Allgemein") -> void:
	var emp_id = get_current_user_id()
	if emp_id.is_empty(): return
	active_timer_state[emp_id] = Time.get_unix_time_from_system()
	var url = get_api_url() + "/time/start"
	var body = {"emp_id": emp_id, "project": project, "start_time": active_timer_state[emp_id]}
	_send_post(url, body)

# Erweitert um das Argument 'break_min' und 'end_time'
func stop_timer(project: String = "", notes: String = "", break_min: int = 0):
	var emp_id = get_current_user_id()
	var url = get_api_url() + "/time/stop"
	var http = HTTPRequest.new()
	add_child(http)
	
	var payload = {
		"emp_id": emp_id,
		"project": project,
		"notes": notes,
		"break_minutes": break_min,
		"end_time": Time.get_unix_time_from_system() # <-- DAS HAT GEFEHLT!
	}
	
	# --- NEU: Sobald der Server den Stopp bestätigt hat, Liste neu laden ---
	http.request_completed.connect(func(_r, code, _h, _b):
		fetch_time_entries() # Holt die brandaktuellen Daten vom Server
		http.queue_free()
	)
	
	var json_payload = JSON.stringify(payload)
	http.request(url, _get_auth_headers(), HTTPClient.METHOD_POST, json_payload)
	
	# Lokalen Status sofort zurücksetzen, damit die UI schnell reagiert
	if active_timer_state.has(emp_id):
		active_timer_state.erase(emp_id)
		
	if current_user:
		current_user["timer_running"] = false
		current_user["timer_start"] = 0

func _send_post(url: String, data: Dictionary) -> void:
	var json_str = JSON.stringify(data)
	var temp_client = HTTPRequest.new()
	add_child(temp_client)
	
	temp_client.request_completed.connect(func(_r, code, _h, body_bytes):
		fetch_time_entries() # Daten nach Änderungen neu laden
		temp_client.queue_free()
	)
	
	var err = temp_client.request(url, _get_auth_headers(), HTTPClient.METHOD_POST, json_str)
	
	# KORREKTUR: Memory-Leak verhindern, wenn Request gar nicht erst raus geht
	if err != OK:
		print("Netzwerkfehler in _send_post: ", err)
		temp_client.queue_free()
		emit_signal("notification_received", {"message": "Netzwerkfehler. Aktion fehlgeschlagen.", "type": "error"})
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

func add_manual_entry(emp_id: String, date_str: String, minutes: int, project: String, break_min: int = 0, type: String = "Manuell") -> void:
	var url = get_api_url() + "/time/manual"
	
	# Der Payload enthält nun auch die break_minutes für die neue Datenbank-Spalte
	var body = {
		"emp_id": emp_id, 
		"date": date_str, 
		"duration_minutes": minutes, 
		"project": project, 
		"break_minutes": break_min,
		"type": type
	}
	
	_send_post(url, body)

func is_day_locked(emp_id: String, date_str: String, callback: Callable) -> void:
	var url = get_api_url() + "/time/is_locked?emp_id=" + emp_id + "&date=" + date_str
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		# KORREKTUR: "Fail-Closed" Ansatz - Bei Fehler (nicht 200) ist der Tag sicherheitshalber gesperrt (true)
		var locked = true 
		if code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json is Dictionary: locked = json.get("is_locked", true)
		callback.call(locked)
		http.queue_free()
	)
	var err = http.request(url, _get_auth_headers())
	if err != OK:
		callback.call(true) # Bei Netzwerkfehler: Tag bleibt gesperrt!
		http.queue_free()

func submit_day(emp_id: String, date_str: String, callback: Callable) -> void:
	var url = get_api_url() + "/time/submit_day"
	var body = {"emp_id": emp_id, "date": date_str}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _body_bytes):
		fetch_time_entries()
		callback.call(code == 200)
		http.queue_free()
	)
	var err = http.request(url, _get_auth_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		callback.call(false) # Callback sofort auflösen
		http.queue_free()

func request_correction(emp_id: String, date_str: String, note: String, callback: Callable) -> void:
	var url = get_api_url() + "/time/request_correction"
	var body = {"emp_id": emp_id, "date": date_str, "note": note}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _body_bytes):
		fetch_time_entries()
		callback.call(code == 200)
		http.queue_free()
	)
	var err = http.request(url, _get_auth_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		callback.call(false)
		http.queue_free()

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
