extends Control

# Haupt-UI
@onready var customer_opt = %CustomerOption
@onready var table_container = %TableContainer
@onready var add_more_opt = %AllServicesOption
@onready var add_more_btn = %AddServiceBtn
@onready var notes_input = %NotesInput
@onready var status_label = %StatusLabel
@onready var history_list = %HistoryList
@onready var progress_bar = %ProgressBar
@onready var progress_label = %ProgressLabel

# Popup
@onready var popup = %CustomerPopup
@onready var target_container = %TargetListContainer
@onready var new_service_input = %NewServiceInput
@onready var create_service_btn = %CreateServiceBtn

# Popup Inputs (Adresse)
@onready var check_billing = %CheckBilling
@onready var billing_grid = %BillingGrid
@onready var inp_name = %InpName
@onready var inp_street = %InpStreet
@onready var inp_house = %InpHouse
@onready var inp_zip = %InpZip
@onready var inp_city = %InpCity
@onready var inp_bill_street = %InpBillStreet
@onready var inp_bill_house = %InpBillHouse
@onready var inp_bill_zip = %InpBillZip
@onready var inp_bill_city = %InpBillCity
@onready var cp1_first = %InpCP1First
@onready var cp1_last = %InpCP1Last
@onready var cp1_mail = %InpCP1Mail
@onready var cp1_phone = %InpCP1Phone
@onready var cp2_first = %InpCP2First
@onready var cp2_last = %InpCP2Last
@onready var cp2_mail = %InpCP2Mail
@onready var cp2_phone = %InpCP2Phone

var current_uid = ""
var all_services_cache = []

func _ready():
	current_uid = Store.get_current_user_id()
	
	%SaveBtn.pressed.connect(_on_save_performance)
	%ManageBtn.pressed.connect(_open_customer_popup)
	%CancelCustomerBtn.pressed.connect(func(): popup.visible = false)
	%SaveCustomerBtn.pressed.connect(_on_save_customer)
	
	customer_opt.item_selected.connect(_on_customer_selected)
	check_billing.toggled.connect(func(v): billing_grid.visible = v)
	
	create_service_btn.pressed.connect(_create_new_service_type)
	add_more_btn.pressed.connect(_add_manual_service_row)
	
	_fetch_customers()
	_fetch_services()
	_fetch_history()

func _fetch_services():
	var url = Store.get_api_url() + "/services"
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, c, _h, b):
		if c == 200:
			all_services_cache = JSON.parse_string(b.get_string_from_utf8())
			_update_add_more_dropdown()
		http.queue_free()
	)
	http.request(url)

func _fetch_customers():
	customer_opt.clear()
	customer_opt.add_item("Bitte Kunden wählen...", -1)
	var url = Store.get_api_url() + "/customers"
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, c, _h, b):
		if c == 200:
			var data = JSON.parse_string(b.get_string_from_utf8())
			for cust in data:
				var lbl = cust.get("company_name", "???")
				if cust.get("city"): lbl += " (%s)" % cust.get("city")
				customer_opt.add_item(lbl, cust.get("id"))
		http.queue_free()
	)
	http.request(url)

# --- TABELLE BAUEN (HAUPTANSICHT) ---
func _on_customer_selected(idx):
	var cid = customer_opt.get_item_id(idx)
	if cid <= 0: return
	
	for c in table_container.get_children(): c.queue_free()
	
	var url = Store.get_api_url() + "/performance/progress?customer_id=" + str(cid)
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var list = JSON.parse_string(body.get_string_from_utf8())
			var total_target = 0
			var total_done = 0
			
			for item in list:
				_add_performance_row(item)
				total_target += int(item.target)
				total_done += int(item.done)
			
			# Statusleiste aktualisieren
			progress_bar.max_value = total_target if total_target > 0 else 1
			progress_bar.value = total_done
			progress_label.text = "Gesamtfortschritt: %d / %d" % [total_done, total_target]
			
		http.queue_free()
	)
	http.request(url)

func _add_performance_row(item):
	# Item hat keys: name, target, done, price
	var s_id = -1
	for s in all_services_cache:
		if s.name == item.name: s_id = s.id; break
	
	if s_id == -1: return
	
	var row = HBoxContainer.new()
	row.set_meta("service_id", s_id)
	row.set("theme_override_constants/separation", 10)
	
	# 1. Name
	var lbl_name = Label.new()
	lbl_name.text = item.name
	lbl_name.custom_minimum_size = Vector2(250, 0)
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 2. Preis (Neu!)
	var lbl_price = Label.new()
	lbl_price.text = "%.2f €" % item.get("price", 0.0)
	lbl_price.custom_minimum_size = Vector2(100, 0)
	lbl_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_price.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	# 3. Soll
	var lbl_target = Label.new()
	lbl_target.text = str(item.target)
	lbl_target.custom_minimum_size = Vector2(80, 0)
	lbl_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_target.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	# 4. Ist
	var lbl_done = Label.new()
	lbl_done.text = str(item.done)
	lbl_done.custom_minimum_size = Vector2(80, 0)
	lbl_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_done.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	# 5. Rest
	var rest = int(item.target) - int(item.done)
	if rest < 0: rest = 0
	var lbl_rest = Label.new()
	lbl_rest.text = str(rest)
	lbl_rest.custom_minimum_size = Vector2(80, 0)
	lbl_rest.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	# 6. Eingabe
	var spin = SpinBox.new()
	spin.min_value = 0
	spin.max_value = 5000
	spin.custom_minimum_size = Vector2(120, 0)
	spin.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	row.add_child(lbl_name)
	row.add_child(lbl_price)
	row.add_child(lbl_target)
	row.add_child(lbl_done)
	row.add_child(lbl_rest)
	row.add_child(spin)
	
	table_container.add_child(row)
	var sep = HSeparator.new(); sep.modulate.a = 0.1
	table_container.add_child(sep)

func _add_manual_service_row():
	var idx = add_more_opt.selected
	var s_id = add_more_opt.get_item_id(idx)
	if s_id == -1: return
	var s_name = add_more_opt.get_item_text(idx)
	_add_performance_row({"name": s_name, "target": 0, "done": 0, "price": 0.0})

func _update_add_more_dropdown():
	add_more_opt.clear()
	add_more_opt.add_item("+ Manuelle Leistung...", -1)
	for s in all_services_cache:
		add_more_opt.add_item(s.name, s.id)

# --- SPEICHERN ---
func _on_save_performance():
	var cid = customer_opt.get_item_id(customer_opt.selected)
	if cid <= 0:
		status_label.text = "Keine Mengen eingetragen!"; status_label.modulate = Color.RED; return
	
	var details = []
	for child in table_container.get_children():
		if child is HBoxContainer and child.has_meta("service_id"):
			var spin = child.get_child(5) 
			if spin.value > 0:
				details.append({
					"service_id": child.get_meta("service_id"),
					"amount": int(spin.value)
				})
	
	if details.is_empty():
		status_label.text = "Keine Mengen eingetragen!"; return

	var payload = {
		"emp_id": current_uid, "customer_id": cid,
		"date_entry": Time.get_date_string_from_system(),
		"notes": notes_input.text, "details": details
	}
	
	var url = Store.get_api_url() + "/performance"
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, c, _h, _b):
		if c == 200:
			status_label.text = "Gespeichert ✔"
			status_label.modulate = Color.GREEN
			notes_input.text = ""
			_on_customer_selected(customer_opt.selected)
			_fetch_history()
		else:
			status_label.text = "Fehler: " + str(c)
			status_label.modulate = Color.RED
		http.queue_free()
	)
	var headers = ["Content-Type: application/json"]
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

# --- POPUP LOGIK (MIT PREIS) ---
func _open_customer_popup():
	popup.visible = true
	for c in target_container.get_children(): c.queue_free()
	
	for s in all_services_cache:
		var row = HBoxContainer.new()
		row.set_meta("service_id", s.id)
		
		var lbl = Label.new()
		lbl.text = s.name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Menge (Soll)
		var spin_amount = SpinBox.new()
		spin_amount.max_value = 100000
		spin_amount.custom_minimum_size = Vector2(100, 0)
		spin_amount.tooltip_text = "Soll-Menge"
		
		# Preis (Neu!)
		var spin_price = SpinBox.new()
		spin_price.max_value = 1000
		spin_price.step = 0.01
		spin_price.custom_minimum_size = Vector2(100, 0)
		spin_price.tooltip_text = "Preis pro Stück"
		
		row.add_child(lbl)
		row.add_child(spin_amount)
		row.add_child(spin_price)
		target_container.add_child(row)

func _on_save_customer():
	if inp_name.text.is_empty(): return
	var data = {
		"company_name": inp_name.text,
		"street": inp_street.text, "house_number": inp_house.text,
		"zip_code": inp_zip.text, "city": inp_city.text,
		"has_billing_address": check_billing.button_pressed,
		"billing_street": inp_bill_street.text, "billing_house_number": inp_bill_house.text,
		"billing_zip_code": inp_bill_zip.text, "billing_city": inp_bill_city.text,
		"cp1_firstname": cp1_first.text, "cp1_lastname": cp1_last.text,
		"cp1_email": cp1_mail.text, "cp1_phone": cp1_phone.text,
		"cp2_firstname": "" if !cp2_first else cp2_first.text, # Fallback, falls leer
		"cp2_lastname": "" if !cp2_last else cp2_last.text,
		"cp2_email": "" if !cp2_mail else cp2_mail.text,
		"cp2_phone": "" if !cp2_phone else cp2_phone.text
	}
	
	var url = Store.get_api_url() + "/customers"
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, c, _h, body):
		if c == 200:
			var resp = JSON.parse_string(body.get_string_from_utf8())
			_save_customer_targets(resp.get("id"))
		http.queue_free()
	)
	var headers = ["Content-Type: application/json"]
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(data))

func _save_customer_targets(cid):
	var targets = []
	for child in target_container.get_children():
		var spin_amount = child.get_child(1)
		var spin_price = child.get_child(2)
		if spin_amount.value > 0:
			targets.append({
				"service_id": child.get_meta("service_id"),
				"target_amount": int(spin_amount.value),
				"price": float(spin_price.value)
			})
	
	var url = Store.get_api_url() + "/customers/%s/targets" % cid
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, c, _h, _b):
		popup.visible = false
		_fetch_customers()
		http.queue_free()
	)
	var headers = ["Content-Type: application/json"]
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(targets))

func _create_new_service_type():
	var txt = new_service_input.text
	if txt.is_empty(): return
	var url = Store.get_api_url() + "/services"
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, c, _h, _b):
		if c == 200:
			new_service_input.text = ""
			_fetch_services()
			await get_tree().create_timer(0.5).timeout
			_open_customer_popup()
		http.queue_free()
	)
	var headers = ["Content-Type: application/json"]
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify({"name": txt}))

func _fetch_history():
	for c in history_list.get_children(): c.queue_free()
	var url = Store.get_api_url() + "/performance/me?emp_id=" + current_uid
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var data = JSON.parse_string(body.get_string_from_utf8())
			for entry in data:
				var lbl = Label.new()
				lbl.text = "%s | %s" % [entry.get("date_entry"), entry.get("company_name")]
				lbl.add_theme_font_size_override("font_size", 12)
				lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
				history_list.add_child(lbl)
				var s = HSeparator.new(); s.modulate.a = 0.1; history_list.add_child(s)
		http.queue_free()
	)
	http.request(url)
