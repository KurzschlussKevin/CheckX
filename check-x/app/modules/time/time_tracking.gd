extends Control

var uid = "" 

@onready var customer_opt = %CustomerOption

func _ready():
	uid = Store.get_current_user_id()
	
	%StartBtn.pressed.connect(_toggle_timer)
	%VacBtn.pressed.connect(func(): %VacationPopup.open(uid))
	%PdfBtn.pressed.connect(_export_pdf)
	
	%CalendarPanel.setup(uid)
	%CalendarPanel.request_manual.connect(func(d): %ManualPopup.open(uid, d))
	%ManualPopup.entry_saved.connect(func(): %CalendarPanel.refresh())
	
	%DateLabel.text = Time.get_date_string_from_system()
	
	if Store.is_timer_running(uid):
		%StartBtn.text = "STOP"
		customer_opt.disabled = true
	
	# NEU: Kunden laden statt Projekte
	_fetch_customers()

func _fetch_customers():
	var url = Store.get_api_url() + "/customers"
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var customers = JSON.parse_string(body.get_string_from_utf8())
			customer_opt.clear()
			
			if customers is Array and customers.size() > 0:
				for c in customers:
					# Anzeige: "Müller GmbH (Berlin)"
					var label = c.get("company_name", "Unbekannt")
					if c.get("city"):
						label += " (" + c.get("city") + ")"
					
					customer_opt.add_item(label)
					# Metadaten: Wir speichern den Firmennamen für den Timer
					customer_opt.set_item_metadata(customer_opt.item_count - 1, c.get("company_name"))
			else:
				customer_opt.add_item("Keine Kunden angelegt")
		else:
			customer_opt.add_item("Offline: Intern")
		http.queue_free()
	)
	http.request(url)

func _process(_delta):
	if Store.is_timer_running(uid):
		var dur = Time.get_unix_time_from_system() - Store.get_timer_start(uid)
		var hours = int(dur / 3600)
		var minutes = int(fmod(dur, 3600) / 60)
		var seconds = int(fmod(dur, 60))
		%TimerLabel.text = "%02d:%02d:%02d" % [hours, minutes, seconds]

func _toggle_timer():
	if Store.is_timer_running(uid):
		# STOP
		var notes = %NotesInput.text
		Store.stop_timer("", notes) 
		
		%StartBtn.text = "START"
		%NotesInput.text = ""
		%TimerLabel.text = "00:00:00"
		customer_opt.disabled = false
		%CalendarPanel.refresh()
	else:
		# START
		var selected_idx = customer_opt.selected
		var customer_name = "Allgemein"
		
		if selected_idx >= 0:
			# Wir holen den reinen Firmennamen aus den Metadaten
			var meta = customer_opt.get_item_metadata(selected_idx)
			if meta: customer_name = meta
			else: customer_name = customer_opt.get_item_text(selected_idx)
		
		# Wir nutzen das Feld 'project' in der DB aktuell für den Kundennamen
		Store.start_timer(customer_name)
		
		%StartBtn.text = "STOP"
		customer_opt.disabled = true

func _export_pdf():
	pass
