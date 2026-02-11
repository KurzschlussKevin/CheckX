extends Control

var current_user_id = "001" 
var selected_date_str = "" 
var current_popup_mode = "manual"
var selected_entry_id_for_request = ""
var displayed_date = { "month": 1, "year": 2024 }

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if has_node("%EntryPopup"): get_node("%EntryPopup").visible = false

	var now = Time.get_date_dict_from_system()
	displayed_date = { "month": now.month, "year": now.year }
	_update_header_date()

	await get_tree().process_frame
	
	if has_node("%ToggleTimerBtn"): get_node("%ToggleTimerBtn").pressed.connect(_on_toggle_timer)
	if has_node("%PauseBtn"): get_node("%PauseBtn").pressed.connect(_on_pause_timer)
	if has_node("%AddManualBtn"): get_node("%AddManualBtn").pressed.connect(_open_manual_popup)
	if has_node("%PopupCancelBtn"): get_node("%PopupCancelBtn").pressed.connect(func(): get_node("%EntryPopup").visible = false)
	if has_node("%PopupSaveBtn"): get_node("%PopupSaveBtn").pressed.connect(_on_popup_save)
	if has_node("%PrevMonthBtn"): get_node("%PrevMonthBtn").pressed.connect(_change_month.bind(-1))
	if has_node("%NextMonthBtn"): get_node("%NextMonthBtn").pressed.connect(_change_month.bind(1))
	
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
		if has_node("%TimerLabel"):
			get_node("%TimerLabel").text = _format_time(duration)
		if has_node("%DailyProgressBar"):
			var goal = 28800.0
			get_node("%DailyProgressBar").value = min(duration / goal, 1.0)
		
		if has_node("%MascotIcon"):
			get_node("%MascotIcon").rotation_degrees += 50 * _delta

func _set_greeting():
	if not has_node("%GreetingLabel"): return
	var hour = Time.get_time_dict_from_system().hour
	var text = "Hallo"
	if hour < 12: text = "Guten Morgen"
	elif hour < 18: text = "Guten Tag"
	else: text = "Guten Abend"
	
	var user_name = "Mitarbeiter"
	for emp in Store.get_all_employees():
		if emp.get("emp_id") == current_user_id:
			user_name = emp.name.split(" ")[0]
			break
	get_node("%GreetingLabel").text = "%s, %s!" % [text, user_name]

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
		var bar_panel = Panel.new()
		bar_panel.custom_minimum_size = Vector2(15, 60)
		bar_panel.size_flags_vertical = 8
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.2, 0.25)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		bar_panel.add_theme_stylebox_override("panel", sb)
		var fill = ColorRect.new()
		fill.color = Color(0.3, 0.6, 0.9)
		fill.show_behind_parent = false
		fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		fill.anchor_top = 1.0 - val
		bar_panel.add_child(fill)
		graph.add_child(bar_panel)

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
	if not has_node("%ToggleTimerBtn"): return
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
		if has_node("%TimerLabel"): get_node("%TimerLabel").text = "00:00:00"
		input.editable = true
		input.text = ""
		dot.modulate = Color(1,1,1,0)

func _change_month(offset: int):
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
	
	if has_node("%MonthLabel"):
		var months = ["", "JANUAR", "FEBRUAR", "MÄRZ", "APRIL", "MAI", "JUNI", "JULI", "AUGUST", "SEPTEMBER", "OKTOBER", "NOVEMBER", "DEZEMBER"]
		var m_name = months[displayed_date.month] if displayed_date.month <= 12 else str(displayed_date.month)
		get_node("%MonthLabel").text = "📅 %s %d" % [m_name, displayed_date.year]
	
	var days_count = _get_days_in_month(displayed_date.month, displayed_date.year)
	for day in range(1, days_count + 1):
		var day_str = "%d-%02d-%02d" % [displayed_date.year, displayed_date.month, day]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(40, 40)
		btn.text = str(day)
		var entries = Store.get_entries_for_date(current_user_id, day_str)
		if entries.size() > 0:
			btn.modulate = Color(0.4, 1.0, 0.5) 
		else:
			btn.modulate = Color(0.6, 0.6, 0.6)
		btn.pressed.connect(_on_day_clicked.bind(day_str))
		grid.add_child(btn)

func _get_days_in_month(month: int, year: int) -> int:
	if month in [1, 3, 5, 7, 8, 10, 12]: return 31
	elif month in [4, 6, 9, 11]: return 30
	else:
		var is_leap = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
		return 29 if is_leap else 28

func _on_day_clicked(date_str):
	selected_date_str = date_str
	if has_node("%RecentHistoryBox"): get_node("%RecentHistoryBox").visible = false
	get_node("%DetailBox").visible = true
	get_node("%SelectedDateLabel").text = "Details für: " + date_str
	
	var list = get_node("%EntryList")
	for c in list.get_children(): c.queue_free()
	
	var entries = Store.get_entries_for_date(current_user_id, date_str)
	var any_locked = false
	
	for e in entries:
		var row = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "• %s (%d Min)" % [e.project, int(e.duration / 60)]
		lbl.size_flags_horizontal = 3
		var status_lbl = Label.new()
		status_lbl.add_theme_font_size_override("font_size", 10)
		
		if e.status == "locked":
			any_locked = true
			status_lbl.text = "🔒"
			status_lbl.tooltip_text = "Genehmigt"
			status_lbl.modulate = Color.GREEN
		else:
			status_lbl.text = "📝"
			status_lbl.tooltip_text = "Offen"
		row.add_child(lbl)
		row.add_child(status_lbl)
		list.add_child(row)
	
	var manual_btn = get_node("%AddManualBtn")
	manual_btn.visible = true
	if any_locked:
		manual_btn.disabled = true
		manual_btn.text = "Tag gesperrt"
	else:
		manual_btn.disabled = false
		manual_btn.text = "+ Zeit nachtragen"

func _open_manual_popup():
	current_popup_mode = "manual"
	get_node("%PopupTitle").text = "ZEIT NACHTRAGEN"
	get_node("%PopupInput1").visible = true
	get_node("%PopupInput2").visible = true
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
