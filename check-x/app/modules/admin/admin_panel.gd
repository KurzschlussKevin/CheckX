extends Control

# --- UI REFERENZEN ---
# Es wird empfohlen, in der .tscn drei ScrollContainer/VBoxen zu haben:
# %RequestList (für Urlaub), %TimeApprovalList (für Stunden) 
# und %CorrectionList (für Korrekturanfragen)
@onready var request_list = %RequestList
@onready var time_approval_list = %TimeApprovalList
# Falls %CorrectionList nicht in der Szene ist, nutzen wir die Time-Liste als Fallback
@onready var correction_list = %CorrectionList if has_node("%CorrectionList") else %TimeApprovalList

func _ready():
	refresh_all()
	# Button oben rechts verbinden, falls er in der Szene existiert
	if has_node("%RefreshAllBtn"):
		%RefreshAllBtn.pressed.connect(refresh_all)

func refresh_all():
	refresh_requests()         # Urlaub laden
	refresh_time_approvals()   # Normale Stunden laden
	refresh_correction_requests() # Korrekturanfragen laden

# --- TEIL 1: URLAUBSVERWALTUNG ---

func refresh_requests():
	if not request_list: return
	for child in request_list.get_children():
		child.queue_free()
	
	var url = Store.get_api_url() + "/admin/pending_absences"
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_requests_loaded)
	# WICHTIG: Nutzt jetzt Store._get_auth_headers() für JWT
	http.request(url, Store._get_auth_headers())

func _on_requests_loaded(_result, response_code, _headers, body):
	if response_code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Array:
			for req in data:
				_add_request_row(req)
	else:
		ErrorHandler.report("Admin / Urlaub", "Fehler beim Laden der Urlaubsanträge (Code: %d)" % response_code)

func _add_request_row(req: Dictionary):
	var panel = PanelContainer.new()
	var h_box = HBoxContainer.new()
	h_box.add_theme_constant_override("separation", 15)
	
	var info = Label.new()
	var fn = req.get("first_name", "")
	var ln = req.get("last_name", "")
	var type = req.get("type", "Urlaub")
	var start = req.get("start_date", "")
	var end = req.get("end_date", "")
	
	info.text = " %s %s (%s): %s bis %s" % [fn, ln, type, start, end]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn_ok = Button.new()
	btn_ok.text = " Genehmigen "
	btn_ok.modulate = Color.GREEN
	btn_ok.pressed.connect(func(): _update_status(req.get("id"), "approved"))
	
	var btn_no = Button.new()
	btn_no.text = " Ablehnen "
	btn_no.modulate = Color.RED
	btn_no.pressed.connect(func(): _update_status(req.get("id"), "rejected"))
	
	h_box.add_child(info)
	h_box.add_child(btn_ok)
	h_box.add_child(btn_no)
	panel.add_child(h_box)
	request_list.add_child(panel)

func _update_status(abs_id, status):
	var admin_id = Store.get_current_user_id()
	var url = Store.get_api_url() + "/admin/approve_absence?absence_id=%s&status=%s&admin_id=%s" % [str(abs_id), status, admin_id]
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		if code == 200: 
			refresh_requests()
		else:
			ErrorHandler.report("Admin / Urlaub", "Status-Update fehlgeschlagen.")
		http.queue_free() # FEHLER BEHOBEN: Node immer löschen!
	)
	var err = http.request(url, Store._get_auth_headers(), HTTPClient.METHOD_POST)
	if err != OK:
		ErrorHandler.report("Netzwerk", "Fehler beim Senden der Anfrage.")
		http.queue_free()

# --- TEIL 2: STUNDENFREIGABE ---

func refresh_time_approvals():
	if not time_approval_list: return
	for child in time_approval_list.get_children():
		child.queue_free()
	
	var url = Store.get_api_url() + "/admin/pending_times"
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_time_approvals_loaded)
	http.request(url, Store._get_auth_headers())

func _on_time_approvals_loaded(_result, response_code, _headers, body):
	if response_code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Array:
			for entry in data:
				_add_time_approval_row(entry)
	else:
		ErrorHandler.report("Admin / Stunden", "Fehler beim Laden der Zeitbuchungen.")

func _add_time_approval_row(entry: Dictionary):
	var panel = PanelContainer.new()
	var h_box = HBoxContainer.new()
	h_box.add_theme_constant_override("separation", 15)
	
	var info = Label.new()
	var fn = entry.get("first_name", "")
	var ln = entry.get("last_name", "")
	var date = entry.get("date", "")
	
	info.text = " %s %s: Arbeitstag %s eingereicht" % [fn, ln, date]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn_approve = Button.new()
	btn_approve.text = " Freigeben "
	btn_approve.modulate = Color.PALE_GREEN
	btn_approve.pressed.connect(func(): _approve_work_day(entry.get("emp_id"), date))
	
	var btn_reject = Button.new()
	btn_reject.text = " Ablehnen "
	btn_reject.modulate = Color.ORANGE_RED
	btn_reject.pressed.connect(func(): _prompt_rejection(entry.get("emp_id"), date))
	
	h_box.add_child(info)
	h_box.add_child(btn_approve)
	h_box.add_child(btn_reject)
	panel.add_child(h_box)
	time_approval_list.add_child(panel)

func _approve_work_day(emp_id: String, date_str: String):
	var url = Store.get_api_url() + "/time/admin/approve_day"
	var body = JSON.stringify({"emp_id": emp_id, "date": date_str})
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		if code == 200: 
			refresh_all() 
		else:
			ErrorHandler.report("Admin / Freigabe", "Konnte Tag nicht freigeben.")
		http.queue_free() # FEHLER BEHOBEN
	)
	var err = http.request(url, Store._get_auth_headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		ErrorHandler.report("Netzwerk", "Keine Verbindung zum Server.")
		http.queue_free()

# --- TEIL 3: KORREKTUR-ANFRAGEN ---

func refresh_correction_requests():
	if not correction_list: return
	# Verhindert doppeltes Leeren, falls correction_list dieselbe Node wie time_approval_list ist
	if correction_list != time_approval_list:
		for child in correction_list.get_children():
			child.queue_free()
	
	var url = Store.get_api_url() + "/admin/pending_corrections"
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_corrections_loaded)
	http.request(url, Store._get_auth_headers())

func _on_corrections_loaded(_result, response_code, _headers, body):
	if response_code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Array:
			for entry in data:
				_add_correction_row(entry)
	else:
		# Nur melden, wenn es kein 404 ist (Endpunkt-Existenz-Check)
		if response_code != 404 and response_code != 0:
			ErrorHandler.report("Admin / Korrekturen", "Fehler beim Laden der Korrekturanfragen.")

func _add_correction_row(entry: Dictionary):
	var panel = PanelContainer.new()
	# Optische Abhebung: Lila-Ton für Korrekturanfragen
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.25, 0.8)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	var h_box = HBoxContainer.new()
	h_box.add_theme_constant_override("separation", 15)
	
	var info = Label.new()
	var fn = entry.get("first_name", "")
	var ln = entry.get("last_name", "")
	var date = entry.get("date", "")
	var reason = entry.get("notes", "Kein Grund angegeben")
	
	info.text = " [KORREKTUR] %s %s: %s\n Grund: %s" % [fn, ln, date, reason]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Option 1: Bearbeitung erlauben (entsperrt den Tag -> wird beim Techniker weiß)
	var btn_allow = Button.new()
	btn_allow.text = " Erlauben "
	btn_allow.modulate = Color.YELLOW
	btn_allow.pressed.connect(func(): _reject_work_day(entry.get("emp_id"), date, "Korrektur genehmigt. Bitte anpassen."))
	
	# Option 2: Korrektur ablehnen (bestätigt den Tag wieder -> bleibt beim Techniker gesperrt)
	var btn_deny = Button.new()
	btn_deny.text = " Ablehnen "
	btn_deny.modulate = Color.LIGHT_CORAL
	btn_deny.pressed.connect(func(): _approve_work_day(entry.get("emp_id"), date))
	
	h_box.add_child(info)
	h_box.add_child(btn_allow)
	h_box.add_child(btn_deny)
	panel.add_child(h_box)
	correction_list.add_child(panel)

# --- HILFSFUNKTIONEN ---

func _prompt_rejection(emp_id: String, date_str: String):
	var dialog = ConfirmationDialog.new()
	dialog.title = "Stunden ablehnen: " + date_str
	var vbox = VBoxContainer.new()
	var label = Label.new()
	label.text = "Bitte gib eine Begründung für die Ablehnung ein:"
	var input = LineEdit.new()
	input.placeholder_text = "Begründung..."
	input.custom_minimum_size.x = 350
	vbox.add_child(label)
	vbox.add_child(input)
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()
	
	dialog.confirmed.connect(func():
		_reject_work_day(emp_id, date_str, input.text)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

func _reject_work_day(emp_id: String, date_str: String, reason: String):
	if reason.strip_edges() == "":
		reason = "Keine Begründung angegeben."
		
	var url = Store.get_api_url() + "/time/admin/reject_day"
	var body = JSON.stringify({"emp_id": emp_id, "date": date_str, "note": reason})
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		if code == 200: 
			refresh_all()
			if Store.has_signal("notification_received"):
				Store.emit_signal("notification_received", {"message": "Tag abgelehnt/entsperrt.", "type": "info"})
		else:
			ErrorHandler.report("Admin / Ablehnung", "Aktion fehlgeschlagen.")
		http.queue_free() # FEHLER BEHOBEN
	)
	var err = http.request(url, Store._get_auth_headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		ErrorHandler.report("Netzwerk", "Keine Verbindung zum Server.")
		http.queue_free()
