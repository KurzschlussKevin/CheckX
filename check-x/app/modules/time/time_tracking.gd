extends Control

var uid = "" 
var blink_timer = 0.0

func _ready():
	uid = Store.get_current_user_id()
	
	# 1. Signale verbinden
	if has_node("%StartBtn"):
		%StartBtn.pressed.connect(_toggle_timer)
	if has_node("%VacBtn"):
		%VacBtn.pressed.connect(func(): if has_node("%VacationPopup"): %VacationPopup.open(uid))
	
	# 2. Untermodule initialisieren
	if has_node("%CalendarPanel"):
		%CalendarPanel.setup(uid)
		%CalendarPanel.request_manual.connect(func(d): if has_node("%ManualPopup"): %ManualPopup.open(uid, d))
	
	if has_node("%ManualPopup"):
		# WICHTIG: Hier wird nach dem Speichern aktualisiert
		%ManualPopup.entry_saved.connect(func(): 
			_refresh_all()
			_update_stats()
		)
	
	if has_node("%DateLabel"):
		%DateLabel.text = Time.get_date_string_from_system()
	
	# 3. INITIALDATEN BEIM START LADEN <-- Das hat gefehlt!
	_update_ui_state()
	_fetch_customers()
	_update_stats() # Ruft die heutigen Minuten direkt beim Öffnen ab

func _process(delta):
	if Store.is_timer_running(uid):
		var dur = Time.get_unix_time_from_system() - Store.get_timer_start(uid)
		var hours = int(dur / 3600)
		var minutes = int(fmod(dur, 3600) / 60)
		var seconds = int(fmod(dur, 60))
		
		if has_node("%TimerLabel"):
			%TimerLabel.text = "%02d:%02d:%02d" % [hours, minutes, seconds]
		
		if has_node("%Bar"):
			%Bar.value = dur / 3600.0
			
		blink_timer += delta
		if has_node("%PulseDot"):
			%PulseDot.visible = true
			%PulseDot.modulate.a = 0.3 + abs(sin(blink_timer * 4.0)) * 0.7
	else:
		if has_node("%PulseDot"):
			%PulseDot.visible = false

func _toggle_timer():
	if Store.is_timer_running(uid):
		var notes = ""
		if has_node("%NotesInput"):
			notes = %NotesInput.text
			%NotesInput.text = ""
		Store.stop_timer("", notes)
		_refresh_all()
	else:
		var customer = "Allgemein"
		if has_node("%CustomerOption"):
			customer = %CustomerOption.get_item_text(%CustomerOption.selected)
		Store.start_timer(customer)
	_update_ui_state()

func _refresh_all():
	if has_node("%CalendarPanel"):
		%CalendarPanel.refresh()

func _update_ui_state():
	var running = Store.is_timer_running(uid)
	if has_node("%StartBtn"):
		%StartBtn.text = "STOPP" if running else "START"
	if has_node("%CustomerOption"):
		%CustomerOption.disabled = running
	if has_node("%StatusLabel"):
		%StatusLabel.text = "AKTIV" if running else "BEREIT"

func _fetch_customers():
	var url = Store.get_api_url() + "/customers"
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200 and has_node("%CustomerOption"):
			var customers = JSON.parse_string(body.get_string_from_utf8())
			%CustomerOption.clear()
			if customers is Array:
				for c in customers:
					%CustomerOption.add_item(c.get("company_name", "Kunde"))
		http.queue_free()
	)
	http.request(url)

func _update_stats():
	if uid == "": return
	
	var date_today = Time.get_date_string_from_system()
	var url = Store.get_api_url() + "/time/stats/daily?emp_id=" + uid + "&date=" + date_today
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json and json.has("total_minutes"):
				var total = int(json["total_minutes"])
				var h = total / 60
				var m = total % 60
				
				# UI-Update
				if has_node("%StatTodayLabel"):
					%StatTodayLabel.text = str(h) + "h " + str(m).pad_zeros(2) + "m"
				
				# Den Fortschrittsbalken ebenfalls füllen (Soll 8h = 480 Min)
				if has_node("%Bar"):
					%Bar.value = float(total) / 60.0 
		http.queue_free()
	)
	http.request(url)
