extends PanelContainer

signal request_manual(date)
var date = {"month": 1, "year": 2024}
var uid = ""
var sel_date = ""

# Definition der Styles für die Kalender-Buttons
var style_normal = StyleBoxFlat.new()
var style_hover = StyleBoxFlat.new()
var style_today = StyleBoxFlat.new()

func _ready():
	_setup_styles()
	date = Time.get_date_dict_from_system()
	%PrevBtn.pressed.connect(func(): _nav(-1))
	%NextBtn.pressed.connect(func(): _nav(1))
	%AddBtn.pressed.connect(func(): emit_signal("request_manual", sel_date))

func _setup_styles():
	# Standard-Aussehen eines Tages
	style_normal.bg_color = Color(1, 1, 1, 0.05)
	style_normal.set_corner_radius_all(4)
	
	# Hover-Effekt (Mauszeiger)
	style_hover.bg_color = Color(0.2, 0.6, 1.0, 0.3)
	style_hover.set_corner_radius_all(4)
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(0.2, 0.6, 1.0, 1.0)
	
	# Markierung für den heutigen Tag
	style_today.bg_color = Color(1, 1, 1, 0.1)
	style_today.border_width_left = 1
	style_today.border_width_top = 1
	style_today.border_width_right = 1
	style_today.border_width_bottom = 1
	style_today.border_color = Color(1, 1, 0.5, 0.5)
	style_today.set_corner_radius_all(4)

func setup(user_id):
	uid = user_id
	refresh()

func refresh():
	%HistoryBox.visible = true
	%DetailBox.visible = false
	_update_cal()
	_update_hist()

func _nav(d):
	date.month += d
	if date.month > 12:
		date.month = 1; date.year += 1
	elif date.month < 1:
		date.month = 12; date.year -= 1
	refresh()

func _update_cal():
	for c in %Grid.get_children(): c.queue_free()
	var months = ["", "JAN", "FEB", "MÄR", "APR", "MAI", "JUN", "JUL", "AUG", "SEP", "OKT", "NOV", "DEZ"]
	%MonthLabel.text = "%s %d" % [months[date.month], date.year]
	
	var today_dict = Time.get_date_dict_from_system()
	var days = _get_days(date.month, date.year)
	
	for d in range(1, days + 1):
		var btn = Button.new()
		# Feste quadratische Größe gegen das Verzerren
		btn.custom_minimum_size = Vector2(45, 45) 
		btn.text = str(d)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		# Zentrierung innerhalb der Grid-Zelle
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var ds = "%d-%02d-%02d" % [date.year, date.month, d]
		
		# Styles zuweisen
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_hover)
		
		if d == today_dict.day and date.month == today_dict.month and date.year == today_dict.year:
			btn.add_theme_stylebox_override("normal", style_today)
		
		# Farbe basierend auf vorhandenen Einträgen
		if Store.get_entries_for_date(str(uid), ds).size() > 0:
			btn.modulate = Color(0.4, 1.0, 0.6) # Grün markieren
		else: 
			btn.modulate = Color(1, 1, 1, 0.6)
		
		btn.pressed.connect(func(): _click(ds))
		%Grid.add_child(btn)

func _update_hist():
	for c in %List.get_children(): c.queue_free()
	var entries = Store.get_entries_by_employee(uid)
	var count = 0
	for i in range(entries.size()-1, -1, -1):
		if count >= 3: break
		var l = Label.new()
		l.text = "• " + entries[i].project
		l.add_theme_font_size_override("font_size", 13)
		l.modulate = Color(0.7, 0.7, 0.7)
		%List.add_child(l)
		count += 1

func _click(ds):
	sel_date = ds
	%HistoryBox.visible = false
	%DetailBox.visible = true
	%DetailLabel.text = "Details für " + ds
	for c in %EntryList.get_children(): c.queue_free()
	
	# Zeigt Einträge inklusive der gespeicherten Notizen an
	for e in Store.get_entries_for_date(uid, ds):
		var l = Label.new()
		var note_text = ""
		if e.has("notes") and e.notes != "":
			note_text = " - " + e.notes
			
		l.text = "• %s (%d min)%s" % [e.project, int(e.duration/60), note_text]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		%EntryList.add_child(l)

func _get_days(m, y):
	if m in [1,3,5,7,8,10,12]: return 31
	elif m in [4,6,9,11]: return 30
	return 29 if (y%4==0 and y%100!=0) or y%400==0 else 28
