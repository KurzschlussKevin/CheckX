extends Control

@onready var grid = %Grid
@onready var info_label = %InfoLabel
@onready var stats_label = %StatsLabel
@onready var month_opt = %MonthOption
@onready var year_opt = %YearOption
@onready var export_btn = %ExportBtn

@onready var loading_overlay = %LoadingOverlay
@onready var spinner = %Spinner

var current_date = {"month": 1, "year": 2026}
var team_data = []
var weekday_names = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
var holiday_cache = {}

var conflict_threshold = Config.get_value("calendar", "conflict_limit", 2)
var current_request: HTTPRequest = null
var rotation_tween: Tween

func _ready():
	stats_label.bbcode_enabled = true
	info_label.bbcode_enabled = true
	
	var now = Time.get_date_dict_from_system()
	current_date.month = now.month
	current_date.year = now.year
	
	_setup_nav_dropdowns()
	
	%TodayBtn.pressed.connect(_on_today_pressed)
	export_btn.pressed.connect(_on_export_pressed)
	get_tree().root.size_changed.connect(_on_window_resize)
	
	# --- SPINNER FIX (Zeichnen statt Text) ---
	spinner.text = "" # Text entfernen, damit nichts "eiert"
	spinner.draw.connect(_on_spinner_draw) # Wir zeichnen selbst
	spinner.queue_redraw()
	
	_fetch_team_data()

# --- NEU: Eigener Zeichen-Code für perfekten Kreis ---
func _on_spinner_draw():
	var center = spinner.size / 2
	var radius = min(spinner.size.x, spinner.size.y) / 2 - 8 # Etwas Abstand zum Rand
	var width = 5.0 # Dicke des Rings
	var col = Color(0.2, 0.6, 1.0, 1.0) # CheckX Blau
	
	# 1. Hintergrund-Ring (dunkel/transparent)
	spinner.draw_arc(center, radius, 0, TAU, 64, Color(1, 1, 1, 0.1), width)
	
	# 2. Lade-Bogen (ca. 75% des Kreises)
	spinner.draw_arc(center, radius, 0, PI * 1.5, 64, col, width)

func _on_window_resize():
	if team_data.size() > 0:
		_build_month_grid()

func _set_loading(active: bool):
	loading_overlay.visible = active
	grid.visible = !active 
	
	if active:
		spinner.pivot_offset = spinner.size / 2
		
		if rotation_tween: rotation_tween.kill()
		rotation_tween = create_tween().set_loops()
		rotation_tween.tween_property(spinner, "rotation", TAU, 1.0).from(0.0)
	else:
		if rotation_tween: rotation_tween.kill()

func _fetch_team_data():
	if current_request != null:
		current_request.queue_free()
		current_request = null
	
	_set_loading(true)
	stats_label.text = "Aktualisiere..."
	
	var url = Store.get_api_url() + "/absences/calendar?year=%d&month=%d" % [current_date.year, current_date.month]
	
	current_request = HTTPRequest.new()
	add_child(current_request)
	
	var timeout_timer = get_tree().create_timer(5.0)
	timeout_timer.timeout.connect(func():
		if current_request:
			current_request.cancel_request()
			current_request.queue_free()
			current_request = null
			_set_loading(false)
			info_label.text = "[color=red]Zeitüberschreitung: Server antwortet nicht.[/color]"
	)
	
	current_request.request_completed.connect(func(result, code, headers, body):
		_set_loading(false)
		current_request.queue_free()
		current_request = null
		
		if code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json != null:
				team_data = json
				_build_month_grid()
				_update_stats()
			else:
				info_label.text = "[color=red]Datenfehler[/color]"
		elif code == 401:
			info_label.text = "[color=red]Sitzung abgelaufen. Bitte neu anmelden.[/color]"
			ErrorHandler.report("TeamCalendar", "401 Unauthorized: JWT Token ungültig.")
		else:
			info_label.text = "[color=red]Fehler: %d[/color]" % code
			ErrorHandler.report("TeamCalendar", "API Fehler: " + str(code))
	)
	
	# --- ÄNDERUNG: AUTH-HEADER HINZUGEFÜGT ---
	var err = current_request.request(url, Store._get_auth_headers())
	if err != OK:
		_set_loading(false)
		info_label.text = "[color=red]Verbindungsfehler[/color]"

func _setup_nav_dropdowns():
	year_opt.clear()
	var base_year = current_date.year
	for i in range(-5, 6):
		var y = base_year + i
		year_opt.add_item(str(y), y)
	_update_dropdown_selection()
	
	month_opt.item_selected.connect(func(idx): 
		current_date.month = month_opt.get_item_id(idx); _fetch_team_data())
	year_opt.item_selected.connect(func(idx):
		current_date.year = year_opt.get_item_id(idx); _fetch_team_data())

func _update_dropdown_selection():
	for i in range(month_opt.item_count):
		if month_opt.get_item_id(i) == current_date.month: month_opt.select(i); break
	for i in range(year_opt.item_count):
		if year_opt.get_item_id(i) == current_date.year: year_opt.select(i); break

func _on_today_pressed():
	var now = Time.get_date_dict_from_system()
	current_date.month = now.month
	current_date.year = now.year
	_update_dropdown_selection()
	_fetch_team_data()

func _build_month_grid():
	var days_in_month = _get_days(current_date.month, current_date.year)
	var today = Time.get_date_dict_from_system()
	var current_holidays = _get_holidays_for_year(current_date.year)
	
	# Grid leeren bevor neu aufgebaut wird
	for n in grid.get_children():
		grid.remove_child(n)
		n.queue_free()
	
	var available_width = get_viewport_rect().size.x * 0.6 
	var btn_size = clamp(available_width / 8, 80, 160)
	var btn_vec = Vector2(btn_size, btn_size)
	
	for i in range(days_in_month):
		var btn = Button.new()
		btn.add_theme_font_size_override("font_size", 20)
		var info_box = VBoxContainer.new()
		info_box.name = "InfoBox"
		info_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_box.alignment = BoxContainer.ALIGNMENT_END
		btn.add_child(info_box)
		var status_label = Label.new()
		status_label.name = "Status"
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 10)
		info_box.add_child(status_label)
		grid.add_child(btn)
		
		btn.custom_minimum_size = btn_vec
		var day_num = i + 1
		_configure_day_button(btn, day_num, today, current_holidays)

func _configure_day_button(btn, d, today, holidays_map):
	var d_str = "%d-%02d-%02d" % [current_date.year, current_date.month, d]
	var unix = Time.get_unix_time_from_datetime_dict({"year":current_date.year, "month":current_date.month, "day":d, "hour":12,"minute":0,"second":0})
	var weekday = Time.get_datetime_dict_from_unix_time(unix).weekday
	var status_label = btn.get_node("InfoBox/Status")
	status_label.text = ""; status_label.modulate = Color.WHITE
	btn.modulate = Color.WHITE; btn.tooltip_text = ""
	
	var day_text = str(d) + "\n" + weekday_names[weekday]
	if weekday == 1:
		var kw = _get_iso_week(d, current_date.month, current_date.year)
		day_text += " (KW " + str(int(kw)) + ")"
	btn.text = day_text
	
	var is_holiday = holidays_map.has(d_str); var is_weekend = (weekday == 0 or weekday == 6)
	if d == today.day and current_date.month == today.month and current_date.year == today.year:
		btn.modulate = Color(1.3, 1.3, 1.1)
	elif is_holiday:
		btn.modulate = Color(1.0, 0.4, 0.4); status_label.text = holidays_map[d_str]
	elif is_weekend:
		btn.modulate = Color(0.6, 0.6, 0.6)
	
	var absent_people = []
	for entry in team_data:
		var start = str(entry.get("start_date", "")); var end = str(entry.get("end_date", ""))
		if d_str >= start and d_str <= end: absent_people.append(entry.get("first_name", "Unbekannt"))
	
	if absent_people.size() > 0:
		var count = absent_people.size()
		status_label.text = str(count) + "x Urlaub"
		btn.tooltip_text = "Abwesend:\n- " + "\n- ".join(absent_people)
		if !is_weekend and !is_holiday:
			if count > conflict_threshold: btn.modulate = Color(1.0, 0.6, 0.2); status_label.modulate = Color.RED; status_label.text += " (!)"
			else: btn.modulate = Color(0.4, 0.7, 1.0)
	btn.pressed.connect(_on_day_selected.bind(d_str))

func _get_holidays_for_year(year):
	if holiday_cache.has(year): return holiday_cache[year]
	var h = {"%d-01-01"%year:"Neujahr", "%d-05-01"%year:"Tag d. Arbeit", "%d-10-03"%year:"Dt. Einheit", "%d-12-25"%year:"1. Weih.", "%d-12-26"%year:"2. Weih."}
	var a=year%19;var b=year%4;var c=year%7;var k=floor(year/100);var p=floor((13+8*k)/25);var q=floor(k/4);var m=(15-p+k-q)%30;var n=(4+k-q)%7;var d=(19*a+m)%30;var e=(2*b+4*c+6*d+n)%7;var day=22+d+e;var month=3
	if day>31: day=d+e-9; month=4
	var easter_unix = Time.get_unix_time_from_datetime_dict({"year":year, "month":month, "day":int(day), "hour":12,"minute":0,"second":0})
	h[_fmt_date(easter_unix - 2*86400)] = "Karfreitag"; h[_fmt_date(easter_unix + 1*86400)] = "Ostermontag"; h[_fmt_date(easter_unix + 39*86400)] = "Himmelfahrt"; h[_fmt_date(easter_unix + 50*86400)] = "Pfingsten"
	holiday_cache[year] = h
	return h

func _fmt_date(unix):
	var dt = Time.get_datetime_dict_from_unix_time(unix)
	return "%d-%02d-%02d" % [dt.year, dt.month, dt.day]

func _update_stats():
	var counts = {}
	for entry in team_data:
		var name = entry.get("first_name", "") + " " + entry.get("last_name", "")
		counts[name] = counts.get(name, 0) + 1
	var text = "[b]Abwesenheiten:[/b]\n"
	if counts.is_empty(): text += "[color=gray]Keine.[/color]"
	else:
		for name in counts: text += "• %s: %d\n" % [name, counts[name]]
	stats_label.bbcode_text = text

func _on_export_pressed():
	export_btn.disabled = true; export_btn.text = "Exportiere..."
	await get_tree().create_timer(0.5).timeout
	var content = "URLAUBS-EXPORT %d-%02d\n----------------\n" % [current_date.year, current_date.month]
	content += stats_label.get_parsed_text()
	var path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/urlaub_export_%d_%d.txt" % [current_date.year, current_date.month]
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file: file.store_string(content); file.close(); OS.shell_open(path)
	export_btn.text = "Fertig ✔"; await get_tree().create_timer(1.0).timeout; export_btn.text = "Diesen Monat Exportieren"; export_btn.disabled = false

func _on_day_selected(date_str):
	var people = []
	for entry in team_data:
		var start = str(entry.get("start_date", "")); var end = str(entry.get("end_date", ""))
		if date_str >= start and date_str <= end: people.append("• " + entry.get("first_name", "") + " (" + entry.get("type", "Urlaub") + ")")
	var output = "[b][font_size=18]Details für " + date_str + "[/font_size][/b]\n"
	if people.size() > 0: output += "\n".join(people)
	else: output += "[color=gray]Keine Abwesenheiten[/color]"
	info_label.bbcode_text = output

func _get_days(m, y):
	if m in [1,3,5,7,8,10,12]: return 31
	elif m in [4,6,9,11]: return 30
	return 29 if (y%4==0 and y%100!=0) or y%400==0 else 28

func _get_iso_week(d, m, y):
	var unix = Time.get_unix_time_from_datetime_dict({"year":y, "month":m, "day":d, "hour":12,"minute":0,"second":0})
	var dt = Time.get_datetime_dict_from_unix_time(unix); var wd = dt.weekday; if wd == 0: wd = 7 
	var thursday_unix = unix + ((4 - wd) * 86400); var thursday_dt = Time.get_datetime_dict_from_unix_time(thursday_unix)
	var jan1 = Time.get_unix_time_from_datetime_dict({"year": thursday_dt.year, "month": 1, "day": 1, "hour":12,"minute":0,"second":0})
	var diff_days = floor((thursday_unix - jan1) / 86400.0)
	return int(floor(diff_days / 7.0) + 1)
