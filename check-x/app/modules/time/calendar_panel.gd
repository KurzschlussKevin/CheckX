extends PanelContainer

signal request_manual(date)

var date = {"month": 1, "year": 2024}
var uid = ""
var sel_date = ""

# 'static' sorgt dafür, dass Godot den Cache beim Szenenwechsel behält
static var locked_days_cache = []

var style_normal = StyleBoxFlat.new()
var style_hover = StyleBoxFlat.new()
var style_today = StyleBoxFlat.new()

func _ready():
	_setup_styles()
	date = Time.get_date_dict_from_system()
	
	%PrevBtn.pressed.connect(func(): _nav(-1))
	%NextBtn.pressed.connect(func(): _nav(1))
	
	# WICHTIG: Den SubmitDayBtn (links) nur verbinden, NICHT optisch verändern
	var submit_node = get_node_or_null("%SubmitDayBtn")
	if submit_node and not submit_node.pressed.is_connected(_on_submit_pressed):
		submit_node.pressed.connect(_on_submit_pressed)
	
	# --- NEU: GLOBALEN REFRESH VERBINDEN ---
	if Store.has_signal("notification_received"):
		Store.notification_received.connect(_on_global_notification)

# --- NEU: LOGIK FÜR AUTOMATISCHEN REFRESH ---
func _on_global_notification(data: Dictionary) -> void:
	# Wenn eine Korrektur-Info oder ein Erfolg vom Server kommt, 
	# müssen wir davon ausgehen, dass sich Status-Farben geändert haben.
	var type = data.get("type", "")
	if type == "correction" or type == "info" or type == "success":
		print("[Kalender] Signal erhalten: Erzwinge Daten-Refresh...")
		# Cache leeren, damit die Farben vom Server neu bestimmt werden
		locked_days_cache.clear()
		
		# Kurze Pause, damit Store.fetch_time_entries() im Hintergrund fertig wird
		await get_tree().create_timer(0.5).timeout
		refresh()

func _setup_styles():
	style_normal.bg_color = Color(1, 1, 1, 0.05)
	style_normal.set_corner_radius_all(4)
	style_hover.bg_color = Color(0.2, 0.6, 1.0, 0.3)
	style_hover.set_corner_radius_all(4)
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(0.2, 0.6, 1.0, 1.0)
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
		btn.custom_minimum_size = Vector2(45, 45) 
		btn.text = str(d)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var ds = "%d-%02d-%02d" % [date.year, date.month, d]
		
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_hover)
		
		if d == today_dict.day and date.month == today_dict.month and date.year == today_dict.year:
			btn.add_theme_stylebox_override("normal", style_today)
		
		var entries = Store.get_entries_for_date(str(uid), ds)
		var locally_locked = false
		for e in entries:
			if e.get("approval_status", "") in ["submitted", "approved", "correction_pending"] or e.get("is_locked", false) == true:
				locally_locked = true
				
		if ds in locked_days_cache or locally_locked:
			btn.modulate = Color(1, 0.3, 0.3, 0.9) # Tag-Zelle ROT
		elif entries.size() > 0:
			btn.modulate = Color(0.4, 1.0, 0.6) # Grün
		else: 
			btn.modulate = Color(1, 1, 1, 0.6) # Weiß
		
		btn.pressed.connect(func():
			btn.release_focus()
			_click(ds)
		)
		%Grid.add_child(btn)

	# Bulk-Check vom Server
	Store.get_locked_days_for_month(uid, date.month, date.year, func(server_locked_days):
		if not is_instance_valid(self): return 
		for d_str in server_locked_days:
			if not (d_str in locked_days_cache):
				locked_days_cache.append(d_str)
			_paint_grid_cell_red(d_str)
	)

func _update_hist():
	for c in %List.get_children(): c.queue_free()
	# Ruft die Funktion im Store auf
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
	
	for e in Store.get_entries_for_date(uid, ds):
		var l = Label.new()
		var note_text = ""
		if e.has("notes") and e.notes != "":
			note_text = " - " + e.notes
		
		# Berechnung der Dauer (Annahme: duration im Store sind Minuten)
		var dur = e.get("duration", 0)
		l.text = "• %s (%d min)%s" % [e.project, int(dur), note_text]
		%EntryList.add_child(l)

	%AddBtn.disabled = true
	%AddBtn.text = "Prüfe..."
	
	Store.is_day_locked(uid, ds, func(is_locked):
		var effectively_locked = is_locked or (ds in locked_days_cache)
		if effectively_locked and not (ds in locked_days_cache):
			locked_days_cache.append(ds)
			_paint_grid_cell_red(ds)
		_update_buttons(effectively_locked)
	)

func _disconnect_all(btn: Button):
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn.callable)

func _update_buttons(is_locked: bool):
	%AddBtn.disabled = false
	_disconnect_all(%AddBtn)
	
	if is_locked:
		%AddBtn.text = "Korrektur beantragen"
		%AddBtn.modulate = Color(1, 0.4, 0.4) 
		%AddBtn.pressed.connect(_on_correction_pressed)
	else:
		%AddBtn.text = "+ Zeit manuell"
		%AddBtn.modulate = Color(1, 1, 1) 
		%AddBtn.pressed.connect(func(): emit_signal("request_manual", sel_date))

func _paint_grid_cell_red(target_date_str):
	var parts = target_date_str.split("-")
	if parts.size() == 3:
		if int(parts[0]) != date.year or int(parts[1]) != date.month:
			return 
		var day_str = str(int(parts[2]))
		for btn in %Grid.get_children():
			if btn is Button and btn.text == day_str:
				btn.modulate = Color(1, 0.3, 0.3, 0.9) 

func _on_submit_pressed():
	if sel_date == "": return
	
	Store.submit_day(uid, sel_date, func(success):
		if success:
			if not (sel_date in locked_days_cache):
				locked_days_cache.append(sel_date)
			_click(sel_date) 
			_update_cal() 
	)

func _on_correction_pressed():
	%AddBtn.disabled = true
	%AddBtn.text = "Sende Antrag..."
	
	Store.request_correction(uid, sel_date, "Korrektur durch Nutzer", func(success):
		if success:
			# Visueller Nachweis via Toast
			Store.emit_signal("notification_received", {
				"message": "Korrekturantrag für den " + sel_date + " wurde erfolgreich gesendet!",
				"type": "info"
			})
			# Cache nicht nur lokal löschen, sondern UI neu prüfen lassen
			locked_days_cache.erase(sel_date)
			_click(sel_date)
			_update_cal() 
		else:
			%AddBtn.text = "Fehler!"
			await get_tree().create_timer(1.0).timeout
			_update_buttons(true) 
	)

func _get_days(m, y):
	if m in [1,3,5,7,8,10,12]: return 31
	elif m in [4,6,9,11]: return 30
	return 29 if (y%4==0 and y%100!=0) or y%400==0 else 28
