extends Control

var current_user_id = "001" 
var selected_date_str = "" 
var displayed_date = { "month": 1, "year": 2024 }
var current_popup_mode = "manual"
var selected_entry_id_for_request = ""

# URALUB: Variablen für Bereichsauswahl
var vac_current_date = { "month": 1, "year": 2024 }
var vac_start_date = ""
var vac_end_date = ""

func _ready():
	# Layout Fix: Erzwingt Vollbild im Container
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# POPUPS AUSBLENDEN (WICHTIG GEGEN SCHWARZES RECHTECK)
	if has_node("%EntryPopup"): get_node("%EntryPopup").visible = false
	if has_node("%VacationPopup"): get_node("%VacationPopup").visible = false

	var now = Time.get_date_dict_from_system()
	displayed_date = { "month": now.month, "year": now.year }
	_update_header_date()
	_update_dynamic_bg() 

	await get_tree().process_frame
	
	# CONNECTIONS - GENERAL
	if has_node("%ToggleTimerBtn"): get_node("%ToggleTimerBtn").pressed.connect(_on_toggle_timer)
	if has_node("%PauseBtn"): get_node("%PauseBtn").pressed.connect(_on_pause_timer)
	if has_node("%AddManualBtn"): get_node("%AddManualBtn").pressed.connect(_open_manual_popup)
	if has_node("%PopupCancelBtn"): get_node("%PopupCancelBtn").pressed.connect(func(): get_node("%EntryPopup").visible = false)
	if has_node("%PopupSaveBtn"): get_node("%PopupSaveBtn").pressed.connect(_on_popup_save)
	if has_node("%PrevMonthBtn"): get_node("%PrevMonthBtn").pressed.connect(_change_month.bind(-1))
	if has_node("%NextMonthBtn"): get_node("%NextMonthBtn").pressed.connect(_change_month.bind(1))
	if has_node("%PdfExportBtn"): get_node("%PdfExportBtn").pressed.connect(_on_pdf_export)
	
	# CONNECTIONS - VACATION
	if has_node("%RequestVacationBtn"): get_node("%RequestVacationBtn").pressed.connect(_open_vacation_popup)
	if has_node("%VacationCancelBtn"): get_node("%VacationCancelBtn").pressed.connect(func(): get_node("%VacationPopup").visible = false)
	if has_node("%VacationSaveBtn"): get_node("%VacationSaveBtn").pressed.connect(_on_vacation_save)
	if has_node("%VacPrevBtn"): get_node("%VacPrevBtn").pressed.connect(_on_vac_nav.bind(-1))
	if has_node("%VacNextBtn"): get_node("%VacNextBtn").pressed.connect(_on_vac_nav.bind(1))
	
	_setup_calendar()
	_update_total_stats()
	_update_recent_history()
	_setup_pulse_animation()
	_set_greeting()

	if Store.is_timer_running(current_user_id):
		_set_active_state(true)
	else:
		_set_active_state(false)

func _process(_delta):
	if Store.is_timer_running(current_user_id):
		var start = Store.get_timer_start(current_user_id)
		var duration = Time.get_unix_time_from_system() - start
		if has_node("%TimerLabel"): get_node("%TimerLabel").text = _format_time(duration)
		if has_node("%DailyProgressBar"): get_node("%DailyProgressBar").value = min(duration / 28800.0, 1.0)
		if has_node("%MascotIcon"):
			var icon = get_node("%MascotIcon")
			icon.pivot_offset = icon.size / 2
			icon.rotation_degrees += 50 * _delta

func _update_dynamic_bg():
	if not has_node("%DynamicBg"): return
	var hour = Time.get_time_dict_from_system().hour
	var bg = get_node("%DynamicBg")
	
	if hour >= 6 and hour < 12:
		bg.color = Color(0.05, 0.05, 0.1) 
	elif hour >= 12 and hour < 18:
		bg.color = Color(0.08, 0.08, 0.1) 
	else:
		bg.color = Color(0.05, 0.03, 0.02) 

func _on_pdf_export():
	var btn = get_node("%PdfExportBtn")
	var original_text = btn.text
	btn.text = "✅"
	await get_tree().create_timer(1.0).timeout
	btn.text = original_text

# --- URLAUB LOGIK ---

func _open_vacation_popup():
	var now = Time.get_date_dict_from_system()
	vac_current_date = { "month": now.month, "year": now.year }
	vac_start_date = ""
	vac_end_date = ""
	
	_update_vac_calendar()
	get_node("%VacationPopup").visible = true
	get_node("%VacSelectionInfo").text = "Bitte Startdatum wählen (1. Klick)"

func _on_vac_nav(offset):
	vac_current_date.month += offset
	if vac_current_date.month > 12:
		vac_current_date.month = 1
		vac_current_date.year += 1
	elif vac_current_date.month < 1:
		vac_current_date.month = 12
		vac_current_date.year -= 1
	_update_vac_calendar()

func _update_vac_calendar():
	var grid = get_node("%VacCalendarGrid")
	for c in grid.get_children(): c.queue_free()
	
	var m_names = ["", "JAN", "FEB", "MÄR", "APR", "MAI", "JUN", "JUL", "AUG", "SEP", "OKT", "NOV", "DEZ"]
	get_node("%VacMonthLabel").text = "%s %d" % [m_names[vac_current_date.month], vac_current_date.year]
	
	var days = _get_days_in_month(vac_current_date.month, vac_current_date.year)
	for day in range(1, days + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(35, 35)
		btn.text = str(day)
		var d_str = "%d-%02d-%02d" % [vac_current_date.year, vac_current_date.month, day]
		
		# RANGE FÄRBUNG
		if d_str == vac_start_date or d_str == vac_end_date:
			btn.modulate = Color(0.2, 0.6, 1.0) # Start/Ende: Blau
		elif vac_start_date != "" and vac_end_date != "" and d_str > vac_start_date and d_str < vac_end_date:
			btn.modulate = Color(0.2, 0.6, 1.0, 0.5) # Dazwischen: Hellblau
		else:
			btn.modulate = Color(1, 1, 1, 0.5) # Grau
			
		btn.pressed.connect(_on_vac_day_press.bind(d_str))
		grid.add_child(btn)

func _on_vac_day_press(date_str):
	var info = get_node("%VacSelectionInfo")
	
	if vac_start_date == "":
		vac_start_date = date_str
		info.text = "Start: " + date_str + " - Bitte Ende wählen"
	elif vac_end_date == "":
		if date_str < vac_start_date:
			vac_end_date = vac_start_date
			vac_start_date = date_str
		else:
			vac_end_date = date_str
		info.text = "Zeitraum: " + vac_start_date + " bis " + vac_end_date
	else:
		# Reset bei 3. Klick
		vac_start_date = date_str
		vac_end_date = ""
		info.text = "Neuer Start: " + date_str
	
	_update_vac_calendar()

func _on_vacation_save():
	if vac_start_date == "" or vac_end_date == "":
		get_node("%VacSelectionInfo").text = "FEHLER: Zeitraum unvollständig!"
		return
		
	var type = get_node("%VacationType").get_item_text(get_node("%VacationType").selected)
	Store.request_vacation(current_user_id, vac_start_date, vac_end_date, type)
	get_node("%VacationPopup").visible = false
	
	var btn = get_node("%RequestVacationBtn")
	btn.text = "Beantragt!"
	await get_tree().create_timer(2.0).timeout
	btn.text = "+ Beantragen"

# --- RESTLICHE FUNKTIONEN (UNVERÄNDERT) ---

func _set_greeting():
	if not has_node("%GreetingLabel"): return
	var hour = Time.get_time_dict_from_system().hour
	var text = "Guten Morgen" if hour < 12 else "Guten Tag"
	if hour >= 18: text = "Guten Abend"
	get_node("%GreetingLabel").text = "%s, Admin!"

func _update_header_date():
	if has_node("%DateDisplayLabel"):
		get_node("%DateDisplayLabel").text = Time.get_date_string_from_system()

func _setup_pulse_animation():
	if not has_node("%PulseDot"): return
	var dot = get_node("%PulseDot")
	var tween = create_tween().set_loops()
	tween.tween_property(dot, "modulate:a", 0.3, 0.8)
	tween.tween_property(dot, "modulate:a", 1.0, 0.8)

func _update_recent_history():
	if not has_node("%HistoryList"): return
	var list = get_node("%HistoryList")
	for c in list.get_children(): c.queue_free()
	
	var entries = Store.get_entries_by_employee(current_user_id)
	var count = 0
	for i in range(entries.size() - 1, -1, -1):
		if count >= 3: break
		var e = entries[i]
		var row = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "• %s" % e.project
		lbl.size_flags_horizontal = 3
		# Smart Tags Färbung
		if "#" in e.project:
			lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		else:
			lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		var time = Label.new()
		time.text = "%d min" % int(e.duration / 60)
		time.add_theme_font_size_override("font_size", 12)
		time.add_theme_color_override("font_color", Color.GRAY)
		row.add_child(lbl)
		row.add_child(time)
		list.add_child(row)
		count += 1

func _update_total_stats():
	if not has_node("%WeeklyGraph"): return
	var graph = get_node("%WeeklyGraph")
	for c in graph.get_children(): c.queue_free()
	var fake_values = [0.2, 0.5, 0.8, 0.4, 0.9, 0.1, 0.0]
	for val in fake_values:
		var bar = Panel.new()
		bar.custom_minimum_size = Vector2(15, 60)
		bar.size_flags_vertical = 8
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.2, 0.25)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		bar.add_theme_stylebox_override("panel", sb)
		var fill = ColorRect.new()
		fill.color = Color(0.3, 0.6, 0.9)
		fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		fill.anchor_top = 1.0 - val
		bar.add_child(fill)
		graph.add_child(bar)

func _on_toggle_timer():
	var proj = get_node("%ProjectInput").text
	var notes = ""
	if has_node("%NotesInput"): notes = get_node("%NotesInput").text
	if Store.is_timer_running(current_user_id):
		Store.stop_timer(current_user_id, proj, notes)
		_set_active_state(false)
		_setup_calendar()
		_update_recent_history()
	else:
		Store.start_timer(current_user_id)
		_set_active_state(true)

func _on_pause_timer():
	if Store.is_timer_running(current_user_id):
		var notes = ""
		if has_node("%NotesInput"): notes = get_node("%NotesInput").text
		Store.stop_timer(current_user_id, "PAUSE", notes)
		_set_active_state(false)
		_setup_calendar()
		_update_recent_history()
		if has_node("%ProjectInput"): get_node("%ProjectInput").text = "PAUSE"

func _set_active_state(is_running):
	var btn = get_node("%ToggleTimerBtn")
	var status = get_node("%StatusLabel")
	var input = get_node("%ProjectInput")
	var dot = get_node("%PulseDot")
	if is_running:
		btn.text = " ■ STOPPEN"
		btn.modulate = Color(1.0, 0.4, 0.4)
		status.text = "Aufzeichnung läuft..."
		status.add_theme_color_override("font_color", Color.GREEN)
		input.editable = false
		dot.modulate = Color.WHITE
	else:
		btn.text = " ▶ STARTEN"
		btn.modulate = Color(0.4, 0.8, 0.5)
		status.text = "Bereit"
		status.add_theme_color_override("font_color", Color.GRAY)
		input.editable = true
		dot.modulate = Color(1,1,1,0)

func _change_month(offset):
	displayed_date.month += offset
	if displayed_date.month > 12:
		displayed_date.month = 1
		displayed_date.year += 1
	elif displayed_date.month < 1:
		displayed_date.month = 12
		displayed_date.year -= 1
	get_node("%DetailBox").visible = false
	if has_node("%RecentHistoryBox"): get_node("%RecentHistoryBox").visible = true
	_setup_calendar()

func _setup_calendar():
	var grid = get_node_or_null("%CalendarGrid")
	if not grid: return
	for c in grid.get_children(): c.queue_free()
	var m_names = ["", "JAN", "FEB", "MÄR", "APR", "MAI", "JUN", "JUL", "AUG", "SEP", "OKT", "NOV", "DEZ"]
	if has_node("%MonthLabel"):
		get_node("%MonthLabel").text = "%s %d" % [m_names[displayed_date.month], displayed_date.year]
	var days = _get_days_in_month(displayed_date.month, displayed_date.year)
	for day in range(1, days + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(40, 40)
		btn.text = str(day)
		var d_str = "%d-%02d-%02d" % [displayed_date.year, displayed_date.month, day]
		var entries = Store.get_entries_for_date(current_user_id, d_str)
		if entries.size() > 0: btn.modulate = Color.GREEN
		else: btn.modulate = Color.GRAY
		btn.pressed.connect(_on_day_clicked.bind(d_str))
		grid.add_child(btn)

func _get_days_in_month(m, y):
	if m in [1,3,5,7,8,10,12]: return 31
	elif m in [4,6,9,11]: return 30
	var is_leap = (y % 4 == 0 and y % 100 != 0) or (y % 400 == 0)
	return 29 if is_leap else 28

func _on_day_clicked(date_str):
	selected_date_str = date_str
	if has_node("%RecentHistoryBox"): get_node("%RecentHistoryBox").visible = false
	get_node("%DetailBox").visible = true
	get_node("%SelectedDateLabel").text = date_str
	var list = get_node("%EntryList")
	for c in list.get_children(): c.queue_free()
	var entries = Store.get_entries_for_date(current_user_id, date_str)
	var locked = false
	for e in entries:
		var l = Label.new()
		l.text = "%s (%d min)" % [e.project, e.duration/60]
		list.add_child(l)
		if e.status == "locked": locked = true
	var btn = get_node("%AddManualBtn")
	btn.visible = true
	btn.disabled = locked
	btn.text = "Gesperrt" if locked else "+ Nachtragen"

func _open_manual_popup():
	current_popup_mode = "manual"
	get_node("%PopupTitle").text = "ZEIT NACHTRAGEN"
	get_node("%EntryPopup").visible = true

func _on_popup_save():
	if current_popup_mode == "manual":
		Store.add_manual_entry(current_user_id, selected_date_str, int(get_node("%PopupInput2").value), get_node("%PopupInput1").text)
	get_node("%EntryPopup").visible = false
	_setup_calendar()
	_on_day_clicked(selected_date_str)

func _format_time(s):
	var h = int(s / 3600)
	var m = int(fmod(s, 3600) / 60)
	return "%02d:%02d" % [h, m]
