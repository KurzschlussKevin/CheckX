extends Control

@onready var request_list = %RequestList

func _ready():
	refresh_requests()

func refresh_requests():
	# Liste leeren
	for child in request_list.get_children():
		child.queue_free()
	
	var url = Store.get_api_url() + "/admin/pending_absences"
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_requests_loaded)
	http.request(url)

func _on_requests_loaded(_result, response_code, _headers, body):
	if response_code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Array:
			for req in data:
				_add_request_row(req)

func _add_request_row(req):
	# Erstellt eine Zeile pro Antrag: [Name/Datum] [OK-Button] [X-Button]
	var panel = PanelContainer.new()
	var h_box = HBoxContainer.new()
	h_box.set("theme_override_constants/separation", 15)
	
	var info = Label.new()
	# Index-Mapping: absences.py liefert (id, vorname, nachname, emp_id, start, end, typ)
	info.text = " %s %s (%s): %s bis %s" % [req[1], req[2], req[6], req[4], req[5]]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn_ok = Button.new()
	btn_ok.text = " Genehmigen "
	btn_ok.modulate = Color.GREEN
	btn_ok.pressed.connect(func(): _update_status(req[0], "approved"))
	
	var btn_no = Button.new()
	btn_no.text = " Ablehnen "
	btn_no.modulate = Color.RED
	btn_no.pressed.connect(func(): _update_status(req[0], "rejected"))
	
	h_box.add_child(info)
	h_box.add_child(btn_ok)
	h_box.add_child(btn_no)
	panel.add_child(h_box)
	request_list.add_child(panel)

func _update_status(abs_id, status):
	var admin_id = Store.get_current_user_id()
	# Query-Parameter für den Endpoint
	var url = Store.get_api_url() + "/admin/approve_absence?absence_id=%d&status=%s&admin_id=%s" % [abs_id, status, admin_id]
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, _b): 
		if code == 200: refresh_requests()
	)
	http.request(url, [], HTTPClient.METHOD_POST)
