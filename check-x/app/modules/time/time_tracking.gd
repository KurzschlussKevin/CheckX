extends Control

var uid = "" 
var blink_timer = 0.0
var current_day_locked = false

func _ready():
	uid = Store.get_current_user_id()
	
	# --- SIGNALE ---
	if has_node("%StartBtn"):
		%StartBtn.pressed.connect(_toggle_timer)
	
	# Dieser Button übernimmt jetzt BEIDE Funktionen (Einreichen & Korrektur)
	if has_node("%SubmitDayBtn"):
		%SubmitDayBtn.pressed.connect(_on_submit_day_pressed)
		
	if has_node("%VacBtn"):
		%VacBtn.pressed.connect(func(): if has_node("%VacationPopup"): %VacationPopup.open(uid))
	
	# --- MODULE ---
	if has_node("%CalendarPanel"):
		%CalendarPanel.setup(uid)
		# Kalenderklick prüft den Sperrstatus des gewählten Datums
		%CalendarPanel.request_manual.connect(_on_calendar_request_manual)
	
	if has_node("%ManualPopup"):
		%ManualPopup.entry_saved.connect(func():
			_refresh_all()
			_update_stats()
		)
	
	if has_node("%DateLabel"):
		%DateLabel.text = Time.get_date_string_from_system()
	
	# Init
	_update_ui_state()
	_fetch_customers()
	_update_stats()

# Diese Funktion prüft beim Klick im Kalender den Sperrstatus des gewählten Tages
func _on_calendar_request_manual(target_date):
	# Korrektur der Klammern in Zeile 53:
	Store.is_day_locked(uid, target_date, func(is_locked):
		if not is_locked:
			if has_node("%ManualPopup"): 
				%ManualPopup.open(uid, target_date)
		else:
			print("Manueller Eintrag verweigert: Tag " + target_date + " ist gesperrt.")
	)

# --- BUTTON LOGIK ---

func _on_submit_day_pressed():
	# Wir prüfen, ob im Kalender ein anderes Datum gewählt ist als 'heute'
	var selected_date = %CalendarPanel.sel_date
	var date_today = Time.get_date_string_from_system()
	
	# Falls im Kalender nichts gewählt ist, nehmen wir heute
	var target_date = selected_date if selected_date != "" else date_today
	
	%SubmitDayBtn.disabled = true
	%SubmitDayBtn.text = "..."
	
	if current_day_locked and target_date == date_today:
		# Nur wenn der HEUTIGE Tag gesperrt ist, beantragen wir Korrektur
		Store.request_correction(uid, target_date, "User Correction Request", func(success):
			if success:
				_update_stats() # UI für heute aktualisieren
			else:
				%SubmitDayBtn.text = "Fehler"
				%SubmitDayBtn.disabled = false
		)
	else:
		# Einreichen (Sperren) für das Ziel-Datum
		Store.submit_day(uid, target_date, func(success):
			if success:
				# WICHTIG: Nur wenn wir HEUTE eingereicht haben, 
				# rufen wir _update_stats auf, um den Timer-Button zu sperren.
				if target_date == date_today:
					_update_stats()
				
				# Kalender muss immer aktualisiert werden (Zelle wird rot)
				if has_node("%CalendarPanel"): 
					%CalendarPanel.refresh()
			else:
				%SubmitDayBtn.text = "Fehler"
				%SubmitDayBtn.disabled = false
		)

# --- VISUELLE LOGIK ---

func _update_stats():
	if uid == "": return
	var date_today = Time.get_date_string_from_system()
	
	# 1. Minuten holen
	var url = Store.get_api_url() + "/time/stats/daily?emp_id=" + uid + "&date=" + date_today
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json and json.has("total_minutes"):
				var total = int(json["total_minutes"])
				var h = total / 60
				var m = total % 60
				if has_node("%StatTodayLabel"):
					%StatTodayLabel.text = str(h) + "h " + str(m).pad_zeros(2) + "m"
				if has_node("%Bar"):
					%Bar.value = total / 60.0
		http.queue_free()
	)
	http.request(url)
	
# 2. STATUS CHECKEN & FARBEN SETZEN
	Store.is_day_locked(uid, date_today, func(is_locked):
		# Wir stellen sicher, dass wir hier NUR den Status für HEUTE speichern
		current_day_locked = is_locked
		
		var btn = %SubmitDayBtn
		var card = %TodayCard
		var status_lbl = %StatusLabel
		var start_btn = %StartBtn
		
		# Button immer aktivieren nach Check
		btn.disabled = false
		
		if is_locked:
			# --- ZUSTAND: EINGEREICHT ---
			
			# Button bleibt optisch unverändert
			btn.text = "Tag einreichen"
			btn.modulate = Color(1, 1, 1) 
			
			# Panel bleibt normal weiß
			card.modulate = Color(1, 1, 1) 
			
			# Status Text zeigt Sperre an
			status_lbl.text = "EINGEREICHT"
			status_lbl.modulate = Color(1, 0.3, 0.3)
			
			# Start Button gesperrt
			start_btn.disabled = true
			start_btn.text = "GESPERRT"
			start_btn.modulate = Color(0.5, 0.5, 0.5)
			
		else:
			# --- ZUSTAND: OFFEN (NORMAL) ---
			btn.text = "Tag einreichen"
			btn.modulate = Color(1, 1, 1)
			card.modulate = Color(1, 1, 1)
			status_lbl.modulate = Color(1, 1, 1)
			_update_ui_state()
	)

func _process(delta):
	if Store.is_timer_running(uid):
		var dur = Time.get_unix_time_from_system() - Store.get_timer_start(uid)
		var h = int(dur / 3600); var m = int(fmod(dur, 3600) / 60); var s = int(fmod(dur, 60))
		if has_node("%TimerLabel"): %TimerLabel.text = "%02d:%02d:%02d" % [h, m, s]
		
		blink_timer += delta
		if has_node("%PulseDot"):
			%PulseDot.visible = true
			%PulseDot.modulate.a = 0.3 + abs(sin(blink_timer * 4.0)) * 0.7
	else:
		if has_node("%PulseDot"): %PulseDot.visible = false

func _toggle_timer():
	if Store.is_timer_running(uid):
		var notes = ""
		if has_node("%NotesInput"):
			notes = %NotesInput.text
			%NotesInput.text = ""
		Store.stop_timer("", notes)
		_refresh_all()
	else:
		var cust = "Allgemein"
		if has_node("%CustomerOption"): cust = %CustomerOption.get_item_text(%CustomerOption.selected)
		Store.start_timer(cust)
	_update_stats()

func _refresh_all():
	if has_node("%CalendarPanel"): %CalendarPanel.refresh()
	_update_stats()

func _update_ui_state():
	if current_day_locked: return
	
	var running = Store.is_timer_running(uid)
	if has_node("%StartBtn"):
		%StartBtn.text = "STOPP" if running else "START"
		%StartBtn.disabled = false
		%StartBtn.modulate = Color(1, 1, 1)
	if has_node("%CustomerOption"): %CustomerOption.disabled = running
	if has_node("%StatusLabel"): %StatusLabel.text = "AKTIV" if running else "BEREIT"

func _fetch_customers():
	var url = Store.get_api_url() + "/customers"
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200 and has_node("%CustomerOption"):
			var customers = JSON.parse_string(body.get_string_from_utf8())
			%CustomerOption.clear()
			if customers is Array:
				for c in customers: %CustomerOption.add_item(c.get("company_name", "Kunde"))
		http.queue_free()
	)
	http.request(url)
