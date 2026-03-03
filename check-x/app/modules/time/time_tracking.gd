extends Control

signal entry_saved

var uid = "" 
var blink_timer = 0.0
var current_day_locked = false
var daily_completed_seconds = 0 # <-- Speichert die bereits gearbeitete Zeit von heute

# NEU: HTTP-Request für den PDF-Export
var export_http: HTTPRequest

func _ready():
	uid = Store.get_current_user_id()
	
	# --- SIGNALE ---
	if has_node("%StartBtn"):
		%StartBtn.pressed.connect(_toggle_timer)
	
	# Dieser Button übernimmt jetzt BEIDE Funktionen (Einreichen & Korrektur)
	if has_node("%SubmitDayBtn"):
		%SubmitDayBtn.pressed.connect(_on_submit_day_pressed)
	
	# Auf Updates vom Server hören (wichtig beim App-Neustart)
	if Store.has_signal("data_updated"):
		Store.data_updated.connect(func():
			_update_ui_state()
			_update_stats()
		)
	
	if has_node("%VacBtn"):
		%VacBtn.pressed.connect(func(): if has_node("%VacationPopup"): %VacationPopup.open(uid))
	
	# --- NEU: PDF EXPORT SIGNALE ---
	if has_node("%PdfBtn"):
		%PdfBtn.pressed.connect(_on_export_btn_pressed)
		
	if has_node("%SavePdfDialog"):
		%SavePdfDialog.file_selected.connect(_on_save_path_selected)
		
	export_http = HTTPRequest.new()
	add_child(export_http)
	export_http.request_completed.connect(_on_export_downloaded)
	
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
	
	# Validierung für Pflichtbeschreibung
	if has_node("%NotesInput"):
		%NotesInput.text_changed.connect(_check_stop_button_validity)
	
	# Initialisierung
	_update_ui_state()
	_fetch_customers()
	_update_stats()
	_set_default_project()

# --- NEUE FUNKTION: Standardprojekt setzen ---
func _set_default_project():
	if not Store.is_timer_running(uid) and has_node("%CustomerOption"):
		var default_proj = Config.get_value("business", "default_project", "Allgemein")
		for i in range(%CustomerOption.get_item_count()):
			if %CustomerOption.get_item_text(i) == default_proj:
				%CustomerOption.selected = i
				break

# --- NEUE FUNKTION: Validierung Stopp-Button ---
func _check_stop_button_validity():
	if not Store.is_timer_running(uid): 
		if has_node("%StartBtn"): %StartBtn.disabled = false
		return
		
	var require_desc = Config.get_value("business", "require_description", false)
	if require_desc and has_node("%NotesInput") and has_node("%StartBtn"):
		var has_text = %NotesInput.text.strip_edges().length() > 0
		%StartBtn.disabled = not has_text
		if not has_text:
			%StartBtn.tooltip_text = "Beschreibung ist erforderlich um zu stoppen."
		else:
			%StartBtn.tooltip_text = ""

# Diese Funktion prüft beim Klick im Kalender den Sperrstatus des gewählten Tages
func _on_calendar_request_manual(target_date):
	# Store.is_day_locked muss intern die Header mitsenden
	Store.is_day_locked(uid, target_date, func(is_locked):
		if not is_locked:
			if has_node("%ManualPopup"): 
				%ManualPopup.open(uid, target_date)
		else:
			print("Manueller Eintrag verweigert: Tag " + target_date + " ist gesperrt.")
	)

# --- BUTTON LOGIK ---

func _on_submit_day_pressed():
	var selected_date = %CalendarPanel.sel_date if has_node("%CalendarPanel") and %CalendarPanel.sel_date != "" else Time.get_date_string_from_system()
	
	%SubmitDayBtn.disabled = true
	%SubmitDayBtn.text = "..."
	
	# NEU: Wir fragen den Server live, ob der ZIEL-Tag gesperrt ist (nicht nur "heute")
	Store.is_day_locked(uid, selected_date, func(is_locked):
		if is_locked:
			# FALL A: Tag ist gesperrt -> Korrektur beantragen
			Store.request_correction(uid, selected_date, "User Correction Request", func(success):
				if success:
					_update_stats()
				else:
					%SubmitDayBtn.text = "Fehler"
					%SubmitDayBtn.disabled = false
					ErrorHandler.report("TimeTracking", "Korrekturanfrage fehlgeschlagen: " + selected_date)
			)
		else:
			# FALL B: Tag einreichen (Sperren)
			Store.submit_day(uid, selected_date, func(success):
				if success:
					_update_stats()
					if has_node("%CalendarPanel"): 
						%CalendarPanel.refresh()
				else:
					%SubmitDayBtn.text = "Fehler"
					%SubmitDayBtn.disabled = false
					ErrorHandler.report("TimeTracking", "Einreichen fehlgeschlagen: " + selected_date)
			)
	)

# ==========================================
# NEU: PDF EXPORT LOGIK
# ==========================================

func _on_export_btn_pressed() -> void:
	# 1. Jahr und Monat holen (Fallback auf aktuelles Datum)
	var target_year = Time.get_date_dict_from_system().year
	var target_month = Time.get_date_dict_from_system().month
	
	# FIX: Das CalendarPanel speichert seine Daten im Dictionary 'date'
	if has_node("%CalendarPanel") and "date" in %CalendarPanel:
		target_year = %CalendarPanel.date.year
		target_month = %CalendarPanel.date.month
	
	# 2. Monatsnamen für den Dateinamen generieren
	var month_names = ["Januar", "Februar", "Maerz", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
	var month_str = month_names[target_month - 1]
	
	# 3. Das Format aus den Settings holen
	var format_string = Config.get_value("business", "export_filename_format", "Stundenzettel_%Name%_%Monat%")
	
	# 4. Platzhalter ersetzen
	var user_name = Store.current_user.get("name", "Mitarbeiter")
	var final_name = format_string.replace("%Name%", user_name)
	final_name = final_name.replace("%Monat%", month_str)
	
	if not final_name.ends_with(".pdf"):
		final_name += ".pdf"
		
	# 5. Den Save-Dialog öffnen und den generierten Namen vorschlagen
	if has_node("%SavePdfDialog"):
		%SavePdfDialog.current_file = final_name
		%SavePdfDialog.popup_centered_ratio(0.5)

func _on_save_path_selected(save_path: String) -> void:
	# Buttons visuell sperren während des Downloads
	if has_node("%PdfBtn"):
		%PdfBtn.disabled = true
		%PdfBtn.text = "Exportiere..."
		
	# Jahr und Monat erneut holen (gleicher Fix wie oben)
	var target_year = Time.get_date_dict_from_system().year
	var target_month = Time.get_date_dict_from_system().month
	
	if has_node("%CalendarPanel") and "date" in %CalendarPanel:
		target_year = %CalendarPanel.date.year
		target_month = %CalendarPanel.date.month
	
	# Download Request starten
	var url = Store.get_api_url() + "/export/pdf/timesheet?year=%d&month=%d" % [target_year, target_month]
	export_http.download_file = save_path
	export_http.request(url, Store._get_auth_headers(), HTTPClient.METHOD_GET)

func _on_export_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# Buttons wieder freigeben
	if has_node("%PdfBtn"):
		%PdfBtn.disabled = false
		%PdfBtn.text = "Export PDF"
		
	if response_code == 200:
		print("✅ Erfolg! PDF wurde gespeichert!")
		# Optional: Wir können hier auch den globalen Toast aufrufen
		if Store.has_signal("notification_received"):
			Store.emit_signal("notification_received", {"message": "Stundenzettel als PDF gespeichert!", "type": "info"})
	else:
		var error_msg = "Fehler beim PDF Export. (Code: " + str(response_code) + ")"
		print("❌ " + error_msg)
		ErrorHandler.report("PDF Export", error_msg)

# ==========================================
# VISUELLE LOGIK & TIMER
# ==========================================

func _update_stats():
	if uid == "": return
	var date_today = Time.get_date_string_from_system()
	
	# 1. Minuten holen (MIT HEADER)
	var url = Store.get_api_url() + "/time/stats/daily?emp_id=" + uid + "&date=" + date_today
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json and json.has("total_minutes"):
				# Float nutzen, um die exakte Zeit mit Sekunden zu erhalten!
				var total = float(json["total_minutes"])
				
				# Abgeschlossene Zeit in Sekunden für die Live-Uhr speichern
				daily_completed_seconds = int(round(total * 60.0))
				
				# Zeit für die große Anzeige aus den gesammelten Sekunden berechnen
				var h = daily_completed_seconds / 3600
				var m = (daily_completed_seconds % 3600) / 60
				var s = daily_completed_seconds % 60
				
				if has_node("%StatTodayLabel"):
					%StatTodayLabel.text = str(h) + "h " + str(m).pad_zeros(2) + "m"
				if has_node("%Bar"):
					%Bar.value = total / 60.0
					
				# Große Uhr zeigt jetzt exakt Stunden, Minuten UND Sekunden an
				if not Store.is_timer_running(uid) and has_node("%TimerLabel"):
					%TimerLabel.text = "%02d:%02d:%02d" % [h, m, s]
		else:
			ErrorHandler.report("TimeTracking", "API Fehler " + str(code) + " beim Abrufen der Tages-Statistiken.")
		http.queue_free()
	)
	http.request(url, Store._get_auth_headers())
	
	# 2. STATUS CHECKEN & FARBEN SETZEN
	Store.is_day_locked(uid, date_today, func(is_locked):
		current_day_locked = is_locked
		
		var btn = %SubmitDayBtn
		var card = %TodayCard
		var status_lbl = %StatusLabel
		var start_btn = %StartBtn
		
		btn.disabled = false
		
		if is_locked:
			btn.text = "Eingereicht"
			btn.modulate = Color(0.7, 0.7, 0.7) 
			card.modulate = Color(0.9, 0.9, 0.9) 
			
			status_lbl.text = "EINGEREICHT"
			status_lbl.modulate = Color(1, 0.3, 0.3)
			
			start_btn.disabled = true
			start_btn.text = "GESPERRT"
			start_btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			btn.text = "Tag einreichen"
			btn.modulate = Color(1, 1, 1)
			card.modulate = Color(1, 1, 1)
			status_lbl.modulate = Color(1, 1, 1)
			_update_ui_state()
	)

func _process(delta):
	if Store.is_timer_running(uid):
		# Dauer der JETZIGEN Sitzung
		var current_session_dur = Time.get_unix_time_from_system() - Store.get_timer_start(uid)
		
		# Gesamtdauer = Abgeschlossene Zeit heute + Jetzige Sitzung
		var total_dur = daily_completed_seconds + current_session_dur
		
		# Stunden, Minuten und Sekunden der Gesamtdauer berechnen
		var h = int(total_dur / 3600)
		var m = int(fmod(total_dur, 3600) / 60)
		var s = int(fmod(total_dur, 60))
		
		if has_node("%TimerLabel"): 
			%TimerLabel.text = "%02d:%02d:%02d" % [h, m, s]
		
		# Live Pausen-Warnung (prüft jetzt auch die Gesamtarbeitszeit!)
		if has_node("%PauseInfoLabel"):
			var auto_enabled = Config.get_value("business", "auto_break_after_6h", true)
			%PauseInfoLabel.visible = auto_enabled and (total_dur / 3600.0) >= 6.0
		
		blink_timer += delta
		if has_node("%PulseDot"):
			%PulseDot.visible = true
			%PulseDot.modulate.a = 0.3 + abs(sin(blink_timer * 4.0)) * 0.7
	else:
		if has_node("%PulseDot"): %PulseDot.visible = false
		if has_node("%PauseInfoLabel"): %PauseInfoLabel.visible = false

func _toggle_timer():
	if Store.is_timer_running(uid):
		var notes = ""
		if has_node("%NotesInput"):
			notes = %NotesInput.text
			%NotesInput.text = ""
		
		# Automatische Pausenberechnung beim Stoppen
		var start_time = Store.get_timer_start(uid)
		var end_time = Time.get_unix_time_from_system()
		var duration_seconds = end_time - start_time
		
		# Gesamte Dauer (heute bereits gearbeitet + jetzige Sitzung)
		var total_duration_today = daily_completed_seconds + duration_seconds
		# Berechne Pause basierend auf dem GESAMTEN Tag
		var break_min = _calculate_auto_break(total_duration_today)
		
		# Timer beim Server stoppen
		Store.stop_timer("", notes, break_min)
	else:
		var cust = "Allgemein"
		if has_node("%CustomerOption"): cust = %CustomerOption.get_item_text(%CustomerOption.selected)
		Store.start_timer(cust)
	
	_update_ui_state()

# HILFSFUNKTION für Pausenlogik
func _calculate_auto_break(dur_sec: float) -> int:
	var hours = dur_sec / 3600.0
	var auto_enabled = Config.get_value("business", "auto_break_after_6h", true)
	var break_val = Config.get_value("business", "daily_break_minutes", 30)
	
	if auto_enabled and hours >= 6.0:
		print("Auto-Pause angewendet: " + str(break_val) + " Minuten.")
		return int(break_val)
	return 0

func _refresh_all():
	if has_node("%CalendarPanel"): %CalendarPanel.refresh()
	_update_stats()

func _update_ui_state():
	if current_day_locked: return
	
	var running = Store.is_timer_running(uid)
	if has_node("%StartBtn"):
		%StartBtn.text = "STOPP" if running else "START"
		%StartBtn.modulate = Color(1, 1, 1)
		_check_stop_button_validity() # Validierung beim Umschalten prüfen
		
	if has_node("%CustomerOption"): %CustomerOption.disabled = running
	if has_node("%StatusLabel"): %StatusLabel.text = "AKTIV" if running else "BEREIT"

func _fetch_customers():
	var url = Store.get_api_url() + "/customers"
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200 and has_node("%CustomerOption"):
			var customers = JSON.parse_string(body.get_string_from_utf8())
			%CustomerOption.clear()
			if customers is Array:
				for c in customers: %CustomerOption.add_item(c.get("company_name", "Kunde"))
			_set_default_project() # Nach dem Laden Standard setzen
		elif code == 401:
			ErrorHandler.report("Network", "Sitzung abgelaufen. Bitte neu einloggen.")
		elif code != 200:
			ErrorHandler.report("Network", "Kundenliste Fehler (HTTP " + str(code) + ")")
		http.queue_free()
	)
	# Auch beim Laden der Kundenliste brauchen wir den Header
	http.request(url, Store._get_auth_headers())
