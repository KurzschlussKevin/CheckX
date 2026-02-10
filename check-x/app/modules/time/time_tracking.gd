extends Control

var current_user_id = "001" # Simulierter eingeloggter User
var selected_date_str = "" 
var current_popup_mode = "manual"
var selected_entry_id_for_request = ""

func _ready():
	# Layout Fix: Erzwingt Fullscreen-Ansicht innerhalb des Containers
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Sicherstellen, dass Popup versteckt ist
	if has_node("%EntryPopup"):
		get_node("%EntryPopup").visible = false

	await get_tree().process_frame
	
	if has_node("%ToggleTimerBtn"):
		get_node("%ToggleTimerBtn").pressed.connect(_on_toggle_timer)
	
	if has_node("%AddManualBtn"):
		get_node("%AddManualBtn").pressed.connect(_open_manual_popup)
	
	if has_node("%PopupCancelBtn"):
		get_node("%PopupCancelBtn").pressed.connect(func(): get_node("%EntryPopup").visible = false)
	
	if has_node("%PopupSaveBtn"):
		get_node("%PopupSaveBtn").pressed.connect(_on_popup_save)
	
	if Store.is_timer_running(current_user_id):
		_set_active_state(true)
	else:
		_set_active_state(false)
	
	_setup_calendar()
	_update_total_stats()

func _process(_delta):
	if Store.is_timer_running(current_user_id):
		var start = Store.get_timer_start(current_user_id)
		if has_node("%TimerLabel"):
			get_node("%TimerLabel").text = _format_time(Time.get_unix_time_from_system() - start)

func _on_toggle_timer():
	if Store.is_timer_running(current_user_id):
		Store.stop_timer(current_user_id, get_node("%ProjectInput").text)
		_set_active_state(false)
		_setup_calendar() 
	else:
		Store.start_timer(current_user_id)
		_set_active_state(true)

func _set_active_state(is_running):
	var btn = get_node("%ToggleTimerBtn")
	var status = get_node("%StatusLabel")
	var input = get_node("%ProjectInput")
	
	if is_running:
		btn.text = "STOPPEN"
		btn.modulate = Color(1.0, 0.4, 0.4)
		status.text = "Aufzeichnung läuft..."
		input.editable = false
	else:
		btn.text = "STARTEN"
		btn.modulate = Color(0.4, 0.8, 0.5)
		status.text = "Bereit"
		if has_node("%TimerLabel"): get_node("%TimerLabel").text = "00:00:00"
		input.editable = true
		input.text = ""

func _setup_calendar():
	var grid = get_node("%CalendarGrid")
	if not grid: return
	
	for c in grid.get_children(): c.queue_free()
	
	var date = Time.get_date_dict_from_system()
	if has_node("%MonthLabel"):
		get_node("%MonthLabel").text = "%02d / %d" % [date.month, date.year]
	
	for day in range(1, 31):
		var day_str = "%d-%02d-%02d" % [date.year, date.month, day]
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(40, 40)
		btn.text = str(day)
		
		var entries = Store.get_entries_for_date(current_user_id, day_str)
		if entries.size() > 0:
			btn.modulate = Color(0.4, 1.0, 0.5) 
			if entries[0].status == "locked":
				btn.tooltip_text = "Genehmigt (Gesperrt)"
			else:
				btn.tooltip_text = "Offen"
		else:
			btn.modulate = Color(0.6, 0.6, 0.6)
			
		btn.pressed.connect(_on_day_clicked.bind(day_str))
		grid.add_child(btn)

func _on_day_clicked(date_str):
	selected_date_str = date_str
	get_node("%DetailBox").visible = true
	get_node("%SelectedDateLabel").text = "Details für: " + date_str
	
	var list = get_node("%EntryList")
	for c in list.get_children(): c.queue_free()
	
	var entries = Store.get_entries_for_date(current_user_id, date_str)
	var any_locked = false
	
	for e in entries:
		var row = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "%s (%d Min)" % [e.project, int(e.duration / 60)]
		lbl.size_flags_horizontal = 3
		
		var status_lbl = Label.new()
		status_lbl.add_theme_font_size_override("font_size", 10)
		
		var action_btn = Button.new()
		action_btn.add_theme_font_size_override("font_size", 10)
		
		if e.status == "locked":
			any_locked = true
			status_lbl.text = "GENEHMIGT"
			status_lbl.add_theme_color_override("font_color", Color.GREEN)
			
			action_btn.text = "Antrag stellen"
			action_btn.pressed.connect(_open_change_request_popup.bind(e.id))
			
		elif e.status == "request_change":
			any_locked = true
			status_lbl.text = "ANTRAG LÄUFT"
			status_lbl.add_theme_color_override("font_color", Color.ORANGE)
			action_btn.visible = false
			
		else: 
			status_lbl.text = "OFFEN"
			status_lbl.add_theme_color_override("font_color", Color.GRAY)
			action_btn.text = "Bearbeiten"
			action_btn.disabled = true
		
		row.add_child(lbl)
		row.add_child(status_lbl)
		row.add_child(action_btn)
		list.add_child(row)
	
	var manual_btn = get_node("%AddManualBtn")
	if any_locked:
		manual_btn.disabled = true
		manual_btn.text = "Tag abgeschlossen (Gesperrt)"
	else:
		manual_btn.disabled = false
		manual_btn.text = "+ Zeit manuell nachtragen"

func _open_manual_popup():
	current_popup_mode = "manual"
	get_node("%PopupTitle").text = "ZEIT NACHTRAGEN"
	get_node("%PopupInput1").placeholder_text = "Projekt / Tätigkeit"
	get_node("%PopupInput1").visible = true
	get_node("%PopupInput2").visible = true
	get_node("%PopupInput1").text = ""
	get_node("%PopupInput2").value = 60
	get_node("%EntryPopup").visible = true

func _open_change_request_popup(entry_id):
	current_popup_mode = "request"
	selected_entry_id_for_request = entry_id
	
	get_node("%PopupTitle").text = "ÄNDERUNGSANTRAG"
	get_node("%PopupInput1").placeholder_text = "Begründung"
	get_node("%PopupInput1").text = ""
	get_node("%PopupInput1").visible = true
	get_node("%PopupInput2").visible = false
	get_node("%EntryPopup").visible = true

func _on_popup_save():
	if current_popup_mode == "manual":
		Store.add_manual_entry(current_user_id, selected_date_str, int(get_node("%PopupInput2").value), get_node("%PopupInput1").text)
	
	elif current_popup_mode == "request":
		Store.request_change(selected_entry_id_for_request, get_node("%PopupInput1").text)
	
	get_node("%EntryPopup").visible = false
	_setup_calendar()
	_on_day_clicked(selected_date_str)

func _update_total_stats():
	pass

func _format_time(s):
	var h = int(s / 3600)
	var m = int(fmod(s, 3600) / 60)
	return "%02d:%02d" % [h, m]
