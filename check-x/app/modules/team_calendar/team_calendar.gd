extends Control

@onready var grid = %Grid
@onready var month_label = %MonthLabel
@onready var info_label = %InfoLabel
@onready var stats_label = %StatsLabel
@onready var year_view_btn = %YearViewBtn

var current_date = {"month": 1, "year": 2026}
var team_data = []
var view_mode = "month"

# Einstellungen
var conflict_threshold = 2 # Warnung, wenn mehr als X Leute fehlen

var holidays = {
	"2026-01-01": "Neujahr", "2026-05-01": "Tag der Arbeit",
	"2026-10-03": "Tag der Dt. Einheit", "2026-12-25": "1. Weihnachtstag",
	"2026-12-26": "2. Weihnachtstag"
}
var weekday_names = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

func _ready():
	var now = Time.get_date_dict_from_system()
	current_date.month = now.month
	current_date.year = now.year
	
	%PrevBtn.pressed.connect(func(): _nav(-1))
	%NextBtn.pressed.connect(func(): _nav(1))
	%TodayBtn.pressed.connect(_on_today_pressed)
	%YearViewBtn.toggled.connect(_on_view_toggled)
	%ExportBtn.pressed.connect(_on_export_pressed)
	
	_fetch_team_data()

func _nav(dir: int):
	if view_mode == "month":
		current_date.month += dir
		if current_date.month > 12:
			current_date.month = 1; current_date.year += 1
		elif current_date.month < 1:
			current_date.month = 12; current_date.year -= 1
	else:
		current_date.year += dir
	_refresh_view()

func _on_today_pressed():
	var now = Time.get_date_dict_from_system()
	current_date.month = now.month
	current_date.year = now.year
	view_mode = "month"
	year_view_btn.set_pressed_no_signal(false)
	_refresh_view()

func _on_view_toggled(toggled):
	view_mode = "year" if toggled else "month"
	_refresh_view()

func _fetch_team_data():
	var url = Store.get_api_url() + "/absences/calendar"
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			team_data = JSON.parse_string(body.get_string_from_utf8())
			_refresh_view()
	)
	http.request(url)

func _refresh_view():
	if view_mode == "month":
		_build_month_grid()
		_update_stats()
	else:
		_build_year_grid()

# --- MONATSANSICHT ---
func _build_month_grid():
	for child in grid.get_children(): child.queue_free()
	grid.columns = 7
	
	var months = ["", "JANUAR", "FEBRUAR", "MÄRZ", "APRIL", "MAI", "JUNI", "JULI", "AUGUST", "SEPTEMBER", "OKTOBER", "NOVEMBER", "DEZEMBER"]
	month_label.text = "%s %d" % [months[current_date.month], current_date.year]
	
	var days_in_month = _get_days(current_date.month, current_date.year)
	var today = Time.get_date_dict_from_system()
	
	for d in range(1, days_in_month + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 120) 
		
		var d_str = "%d-%02d-%02d" % [current_date.year, current_date.month, d]
		var unix = Time.get_unix_time_from_datetime_dict({"year":current_date.year, "month":current_date.month, "day":d, "hour":12,"minute":0,"second":0})
		var weekday = Time.get_datetime_dict_from_unix_time(unix).weekday # 0=So, 1=Mo ...
		
		# Button Text & KW Berechnung
		var day_text = str(d) + "\n" + weekday_names[weekday]
		if weekday == 1: # Montag
			var kw = _get_iso_week(d, current_date.month, current_date.year)
			day_text += " (KW " + str(kw) + ")" # Hier steht jetzt z.B. "KW 3"
		
		btn.text = day_text
		btn.add_theme_font_size_override("font_size", 20)
		
		# Info Box Layout
		var info_box = VBoxContainer.new()
		info_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_box.alignment = BoxContainer.ALIGNMENT_END
		btn.add_child(info_box)
		
		var status_label = Label.new()
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 10)
		info_box.add_child(status_label)

		# Farben & Markierungen
		if d == today.day and current_date.month == today.month and current_date.year == today.year:
			btn.modulate = Color(1.3, 1.3, 1.1) # Heute (Heller)
		
		# Wochenende (Grau, aber ohne Text "WE")
		if weekday == 0 or weekday == 6:
			btn.modulate = Color(0.6, 0.6, 0.6)
			# status_label.text = "WE" <- Entfernt wie gewünscht

		# Feiertag (Rot)
		if holidays.has(d_str):
			btn.modulate = Color(1.0, 0.4, 0.4)
			status_label.text = holidays[d_str]

		# Urlaub (Blau + Zähler)
		var absent_people = []
		for entry in team_data:
			if d_str >= str(entry.get("start_date")) and d_str <= str(entry.get("end_date")):
				absent_people.append(entry.get("first_name"))
		
		if absent_people.size() > 0:
			var count = absent_people.size()
			status_label.text = str(count) + "x Urlaub"
			
			btn.tooltip_text = "Abwesend:\n- " + "\n- ".join(absent_people)
			
			# Konflikt-Check (Unterbesetzung)
			if weekday != 0 and weekday != 6 and !holidays.has(d_str):
				if count > conflict_threshold:
					btn.modulate = Color(1.0, 0.6, 0.2) # Orange Warnung
					status_label.modulate = Color.RED
					status_label.text += " (!)"
				else:
					btn.modulate = Color(0.4, 0.7, 1.0) # Normal Blau

		btn.pressed.connect(func(): _on_day_selected(d_str))
		grid.add_child(btn)

# --- JAHRESANSICHT ---
func _build_year_grid():
	for child in grid.get_children(): child.queue_free()
	grid.columns = 4
	month_label.text = "JAHR %d" % current_date.year
	var months = ["JAN", "FEB", "MÄR", "APR", "MAI", "JUN", "JUL", "AUG", "SEP", "OKT", "NOV", "DEZ"]
	
	for i in range(12):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 150)
		btn.text = months[i]
		btn.add_theme_font_size_override("font_size", 32)
		var target_month = i + 1
		btn.pressed.connect(func(): 
			current_date.month = target_month
			view_mode = "month"
			year_view_btn.set_pressed_no_signal(false)
			_refresh_view()
		)
		grid.add_child(btn)

# --- STATISTIK ---
func _update_stats():
	var counts = {}
	var month_str = "%d-%02d" % [current_date.year, current_date.month]
	for entry in team_data:
		var start = str(entry.get("start_date"))
		var end = str(entry.get("end_date"))
		if start.begins_with(month_str) or end.begins_with(month_str):
			var name = entry.get("first_name") + " " + entry.get("last_name")
			counts[name] = counts.get(name, 0) + 1
	
	var text = ""
	if counts.is_empty(): text = "Keine Abwesenheiten."
	else:
		for name in counts: text += "• %s: %d\n" % [name, counts[name]]
	stats_label.text = text

# --- EXPORT ---
func _on_export_pressed():
	var content = "URLAUBS-EXPORT %d-%02d\n----------------\n" % [current_date.year, current_date.month]
	content += stats_label.text
	var path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/urlaub_export_%d_%d.txt" % [current_date.year, current_date.month]
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		OS.shell_open(path)

func _on_day_selected(date_str):
	var people = []
	for entry in team_data:
		if date_str >= str(entry.get("start_date")) and date_str <= str(entry.get("end_date")):
			people.append("• " + entry.get("first_name") + " (" + entry.get("type") + ")")
	
	var output = "[b]Info " + date_str + "[/b]\n"
	if people.size() > 0: output += "\n".join(people)
	else: output += "[color=gray]Keine Abwesenheiten[/color]"
	info_label.bbcode_text = output

func _get_days(m, y):
	if m in [1,3,5,7,8,10,12]: return 31
	elif m in [4,6,9,11]: return 30
	return 29 if (y%4==0 and y%100!=0) or y%400==0 else 28

# HILFSFUNKTION: Berechnet die echte Kalenderwoche (ISO 8601 ähnlich)
func _get_iso_week(d, m, y):
	var unix = Time.get_unix_time_from_datetime_dict({"year":y, "month":m, "day":d, "hour":12,"minute":0,"second":0})
	var dt = Time.get_datetime_dict_from_unix_time(unix)
	var wd = dt.weekday
	if wd == 0: wd = 7 # Sonntag = 7 für ISO
	
	# Donnerstag der Woche finden
	var thursday_unix = unix + ((4 - wd) * 86400)
	var thursday_dt = Time.get_datetime_dict_from_unix_time(thursday_unix)
	
	# 1. Januar des Jahres des Donnerstags
	var jan1 = Time.get_unix_time_from_datetime_dict({"year": thursday_dt.year, "month": 1, "day": 1, "hour":12,"minute":0,"second":0})
	
	# Tage seit Jahresbeginn / 7
	var diff_days = floor((thursday_unix - jan1) / 86400.0)
	return floor(diff_days / 7.0) + 1
