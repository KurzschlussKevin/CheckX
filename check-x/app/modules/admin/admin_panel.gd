extends Control

# --- UI REFERENZEN ---
# Es wird empfohlen, in der .tscn zwei ScrollContainer/VBoxen zu haben:
# %RequestList (für Urlaub) und %TimeApprovalList (für Stunden)
@onready var request_list = %RequestList
@onready var time_approval_list = %TimeApprovalList

func _ready():
	refresh_all()

func refresh_all():
	refresh_requests() # Urlaub laden
	refresh_time_approvals() # Stunden laden

# --- TEIL 1: URLAUBSVERWALTUNG ---

func refresh_requests():
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

func _add_request_row(req: Dictionary):
	var panel = PanelContainer.new()
	var h_box = HBoxContainer.new()
	h_box.set("theme_override_constants/separation", 15)
	
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
	# admin_id wird im Backend nun aus dem Token gelesen, wir senden sie zur Sicherheit noch mit
	var admin_id = Store.get_current_user_id()
	var url = Store.get_api_url() + "/admin/approve_absence?absence_id=%s&status=%s&admin_id=%s" % [str(abs_id), status, admin_id]
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b): 
		if code == 200: refresh_requests()
	)
	http.request(url, Store._get_auth_headers(), HTTPClient.METHOD_POST)


# --- TEIL 2: STUNDENFREIGABE (NEU) ---

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

func _add_time_approval_row(entry: Dictionary):
	var panel = PanelContainer.new()
	var h_box = HBoxContainer.new()
	h_box.set("theme_override_constants/separation", 15)
	
	var info = Label.new()
	var fn = entry.get("first_name", "")
	var ln = entry.get("last_name", "")
	var date = entry.get("date", "")
	
	info.text = " %s %s: Arbeitstag %s eingereicht" % [fn, ln, date]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn_approve = Button.new()
	btn_approve.text = " Stunden freigeben "
	btn_approve.modulate = Color.PALE_GREEN
	btn_approve.pressed.connect(func(): _approve_work_day(entry.get("emp_id"), date))
	
	h_box.add_child(info)
	h_box.add_child(btn_approve)
	panel.add_child(h_box)
	time_approval_list.add_child(panel)

func _approve_work_day(emp_id: String, date_str: String):
	var url = Store.get_api_url() + "/time/admin/approve_day"
	var body = JSON.stringify({
		"emp_id": emp_id,
		"date": date_str
	})
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b):
		if code == 200: refresh_time_approvals()
	)
	http.request(url, Store._get_auth_headers(), HTTPClient.METHOD_POST, body)
