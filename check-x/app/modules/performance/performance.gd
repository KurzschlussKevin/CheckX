extends Control

# Haupt-UI
@onready var customer_opt = %CustomerOption
@onready var table_container = %TableContainer
@onready var search_input = %SearchInput
@onready var notes_input = %NotesInput
@onready var status_label = %StatusLabel
@onready var history_list = %HistoryList
@onready var progress_bar = %ProgressBar
@onready var progress_label = %ProgressLabel
@onready var export_btn = %ExportPdfBtn # NEU

# Popup & Vorlagen
@onready var popup = %CustomerPopup
@onready var target_container = %TargetListContainer
@onready var new_service_input = %NewServiceInput
@onready var create_service_btn = %CreateServiceBtn
@onready var template_opt = %TemplateOption
@onready var template_name_inp = %TemplateNameInput
@onready var save_template_btn = %SaveTemplateBtn
@onready var load_template_btn = %LoadTemplateBtn

# Popup Inputs (Adresse & Kontakt)
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
var last_saved_report_id = -1 # ID des letzten Berichts für den Export

# --- FARBEN FÜR ZEBRA-LOOK ---
const COLOR_ROW_A = Color(0.08, 0.08, 0.10, 1.0) # Sehr dunkel
const COLOR_ROW_B = Color(0.16, 0.16, 0.20, 1.0) # Deutlich heller (Grau/Blau)

func _ready():
	current_uid = Store.get_current_user_id()
	
	%SaveBtn.pressed.connect(_on_save_performance)
	%ManageBtn.pressed.connect(_open_customer_popup)
	%CancelCustomerBtn.pressed.connect(func(): popup.visible = false)
	%SaveCustomerBtn.pressed.connect(_on_save_customer)
	export_btn.pressed.connect(_on_export_pdf) # NEU
	
	customer_opt.item_selected.connect(_on_customer_selected)
	check_billing.toggled.connect(func(v): billing_grid.visible = v)
	search_input.text_changed.connect(_on_search_text_changed)
	
	create_service_btn.pressed.connect(_create_new_service_type)
	save_template_btn.pressed.connect(_on_save_template)
	load_template_btn.pressed.connect(_on_load_template)
	
	_fetch_customers()
	_fetch_services()
	_fetch_history()
	_fetch_templates()

func _fetch_services():
	var url = Store.get_api_url() + "/services"
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, c, _h, b):
		if c == 200: all_services_cache = JSON.parse_string(b.get_string_from_utf8())
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

# --- INTELLIGENTE SUCHE & FILTER ---
func _on_search_text_changed(txt):
	var filter = txt.to_lower()
	var visible_count = 0
	for child in table_container.get_children():
		if child is PanelContainer and child.has_meta("service_name"):
			var s_name = child.get_meta("service_name").to_lower()
			if filter.is_empty() or filter in s_name:
				child.visible = true
				_apply_row_color(child, visible_count % 2 != 0)
				visible_count += 1
			else:
				child.visible = false

func _apply_row_color(panel: PanelContainer, is_highlighted: bool):
	var style = panel.get_theme_stylebox("panel").duplicate()
	style.bg_color = COLOR_ROW_B if is_highlighted else COLOR_ROW_A
	panel.add_theme_stylebox_override("panel", style)

# --- TABELLE BAUEN ---
func _on_customer_selected(idx):
	var cid = customer_opt.get_item_id(idx)
	if cid <= 0: return
	
	for c in table_container.get_children(): c.queue_free()
	last_saved_report_id = -1 # Reset
	
	var url = Store.get_api_url() + "/performance/progress?customer_id=" + str(cid)
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var list = JSON.parse_string(body.get_string_from_utf8())
			var total_target = 0
			var total_done = 0
			
			for i in range(list.size()):
				_add_performance_row(list[i], i % 2 != 0)
				total_target += int(list[i].target)
				total_done += int(list[i].done)
			
			progress_bar.max_value = total_target if total_target > 0 else 1
			progress_bar.value = total_done
			progress_label.text = "Gesamtfortschritt: %d / %d" % [total_done, total_target]
		http.queue_free()
	)
	http.request(url)

func _add_performance_row(item, is_darker):
	var s_id = -1
	for s in all_services_cache:
		if s.name == item.name: s_id = s.id; break
	if s_id == -1: return
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ROW_B if is_darker else COLOR_ROW_A
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 8; style.content_margin_bottom = 8
	style.corner_radius_top_left = 4; style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4; style.corner_radius_bottom_left = 4
	
	panel.add_theme_stylebox_override("panel", style)
	panel.set_meta("service_name", item.name)
	panel.set_meta("service_id", s_id)
	
	var row = HBoxContainer.new()
	row.set("theme_override_constants/separation", 15)
	
	# 1. Name
	var lbl_name = Label.new()
	lbl_name.text = item.name
	lbl_name.custom_minimum_size = Vector2(250, 0)
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_color_override("font_color", Color.WHITE)
	
	# 2. Preis
	var lbl_price = Label.new()
	lbl_price.text = "%.2f €" % item.get("price", 0.0)
	lbl_price.custom_minimum_size = Vector2(100, 0)
	lbl_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_price.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	# 3. Soll
	var lbl_target = Label.new()
	lbl_target.text = str(item.target)
	lbl_target.custom_minimum_size = Vector2(80, 0)
	lbl_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_target.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	# 4. Ist
	var lbl_done = Label.new()
	lbl_done.text = str(item.done)
	lbl_done.custom_minimum_size = Vector2(80, 0)
	lbl_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_done.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	# 5. Rest
	var rest = int(item.target) - int(item.done)
	if rest < 0: rest = 0
	var lbl_rest = Label.new()
	lbl_rest.text = str(rest)
	lbl_rest.custom_minimum_size = Vector2(80, 0)
	lbl_rest.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if rest == 0:
		lbl_rest.add_theme_color_override("font_color", Color.GREEN)
	else:
		lbl_rest.add_theme_color_override("font_color", Color(1, 0.7, 0.4))
	
	# 6. Eingabe
	var spin = SpinBox.new()
	spin.min_value = 0; spin.max_value = 5000
	spin.custom_minimum_size = Vector2(120, 0)
	spin.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	row.add_child(lbl_name)
	row.add_child(lbl_price)
	row.add_child(lbl_target)
	row.add_child(lbl_done)
	row.add_child(lbl_rest)
	row.add_child(spin)
	
	panel.add_child(row)
	table_container.add_child(panel)

# --- SPEICHERN ---
func _on_save_performance():
	var cid = customer_opt.get_item_id(customer_opt.selected)
	if cid <= 0:
		status_label.text = "Kein Kunde gewählt!"; status_label.modulate = Color.RED; return
	
	var details = []
	for panel in table_container.get_children():
		if panel.visible and panel.has_meta("service_id"):
			var row = panel.get_child(0)
			
			# FIX: Wir suchen einfach nach IRGENDEINER SpinBox in der Zeile.
			# In der Hauptansicht gibt es pro Zeile nur eine (die für die Menge).
			for child in row.get_children():
				if child is SpinBox:
					if child.value > 0:
						details.append({
							"service_id": panel.get_meta("service_id"), 
							"amount": int(child.value)
						})
					# Sobald wir die Box gefunden haben, können wir zur nächsten Zeile springen
					break 
	
	if details.is_empty(): 
		status_label.text = "Keine Mengen eingetragen!" 
		status_label.modulate = Color.YELLOW
		return

	var payload = {
		"emp_id": current_uid, "customer_id": cid,
		"date_entry": Time.get_date_string_from_system(),
		"notes": notes_input.text, "details": details
	}
	
	# Button sperren
	%SaveBtn.disabled = true
	%SaveBtn.text = "Speichere..."
	
	var url = Store.get_api_url() + "/performance"
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, c, _h, b):
		%SaveBtn.disabled = false
		%SaveBtn.text = "SPEICHERN"
		
		if c == 200:
			var resp = JSON.parse_string(b.get_string_from_utf8())
			var new_id = int(resp.get("id")) # ID merken
			
			status_label.text = "Gespeichert ✔ PDF bereit."
			status_label.modulate = Color.GREEN
			notes_input.text = ""
			search_input.text = ""
			
			# Liste neu laden (setzt ID auf -1)
			_on_customer_selected(customer_opt.selected)
			
			# ID wiederherstellen für den Export-Button
			last_saved_report_id = new_id 
			
		else:
			status_label.text = "Fehler: " + str(c)
			status_label.modulate = Color.RED
		http.queue_free()
	)
	var headers = ["Content-Type: application/json"]
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

# --- PDF EXPORT (NEU) ---
func _on_export_pdf():
	if last_saved_report_id == -1:
		status_label.text = "Erst speichern!"
		status_label.modulate = Color.YELLOW
		return
		
	var url = Store.get_api_url() + "/export/pdf/performance/" + str(last_saved_report_id)
	OS.shell_open(url) # Öffnet Standard-Browser/PDF-Viewer

# --- VORLAGEN LOGIK ---
func _fetch_templates():
	template_opt.clear()
	template_opt.add_item("Vorlage wählen...", -1)
	var url = Store.get_api_url() + "/templates"
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, c, _h, b):
		if c == 200:
			var data = JSON.parse_string(b.get_string_from_utf8())
			for t in data: template_opt.add_item(t.name, t.id)
		http.queue_free()
	)
	http.request(url)

func _on_save_template():
	var t_name = template_name_inp.text
	if t_name.is_empty(): return
	
	var items = []
	for panel in target_container.get_children():
		var row = panel.get_child(0)
		var amount = row.get_child(1).value
		var price = row.get_child(2).value
		items.append({
			"service_id": panel.get_meta("service_id"),
			"target_amount": int(amount),
			"price": float(price)
		})
	
	var url = Store.get_api_url() + "/templates"
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, c, _h, _b):
		if c == 200:
			template_name_inp.text = ""
			_fetch_templates()
		http.queue_free()
	)
	var headers = ["Content-Type: application/json"]
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify({"name": t_name, "items": items}))

func _on_load_template():
	var tid = template_opt.get_item_id(template_opt.selected)
	if tid <= 0: return
	
	var url = Store.get_api_url() + "/templates/" + str(tid)
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, c, _h, b):
		if c == 200:
			var items = JSON.parse_string(b.get_string_from_utf8())
			for child in target_container.get_children(): child.queue_free()
			for i in range(items.size()):
				var item = items[i]
				_add_target_row_ui(item.name, item.service_id, item.default_amount, item.default_price, i % 2 != 0)
		http.queue_free()
	)
	http.request(url)

# --- POPUP HELPER ---
func _open_customer_popup():
	popup.visible = true

func _add_target_row_ui(s_name, id, amount, price, is_darker):
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ROW_B if is_darker else COLOR_ROW_A
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 5; style.content_margin_bottom = 5
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	panel.set_meta("service_id", id)
	
	var row = HBoxContainer.new()
	row.set("theme_override_constants/separation", 10)
	
	var lbl = Label.new()
	lbl.text = s_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var spin_amount = SpinBox.new()
	spin_amount.max_value = 100000
	spin_amount.value = amount
	spin_amount.custom_minimum_size = Vector2(100, 0)
	
	var spin_price = SpinBox.new()
	spin_price.max_value = 1000
	spin_price.step = 0.01
	spin_price.value = price
	spin_price.custom_minimum_size = Vector2(100, 0)
	
	# Löschen Button (Wie gewünscht)
	var del_btn = Button.new()
	del_btn.text = "✖"
	del_btn.custom_minimum_size = Vector2(30, 0)
	del_btn.modulate = Color(1, 0.4, 0.4)
	del_btn.flat = true
	del_btn.pressed.connect(func(): panel.queue_free())
	
	row.add_child(lbl)
	row.add_child(spin_amount)
	row.add_child(spin_price)
	row.add_child(del_btn)
	
	panel.add_child(row)
	target_container.add_child(panel)

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
			var idx = target_container.get_child_count()
			_add_target_row_ui(txt, 999, 0, 0.0, idx % 2 != 0)
		http.queue_free()
	)
	var headers = ["Content-Type: application/json"]
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify({"name": txt}))

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
		"cp2_firstname": "" if !cp2_first else cp2_first.text,
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
	for panel in target_container.get_children():
		if panel is PanelContainer:
			var row = panel.get_child(0)
			var spin_amount = row.get_child(1)
			var spin_price = row.get_child(2)
			
			if spin_amount.value > 0 or spin_price.value > 0:
				targets.append({
					"service_id": panel.get_meta("service_id"),
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
