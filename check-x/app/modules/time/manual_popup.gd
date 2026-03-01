extends Control

signal entry_saved

var user_id = ""
var target_date = ""

@onready var start_slider = %StartSlider
@onready var end_slider = %EndSlider
@onready var start_input = %StartTimeInput
@onready var end_input = %EndTimeInput
@onready var project_input = %ProjectInput
@onready var save_btn = %SaveBtn
@onready var date_info = %DateInfo

func _ready():
	start_slider.value_changed.connect(func(v): _update_input_from_slider(start_input, v))
	end_slider.value_changed.connect(func(v): _update_input_from_slider(end_input, v))
	
	start_input.text_submitted.connect(func(t): _update_slider_from_text(start_slider, t))
	end_input.text_submitted.connect(func(t): _update_slider_from_text(end_slider, t))
	start_input.focus_exited.connect(func(): _update_slider_from_text(start_slider, start_input.text))
	end_input.focus_exited.connect(func(): _update_slider_from_text(end_slider, end_input.text))

	save_btn.pressed.connect(_on_save)
	%CancelBtn.pressed.connect(func(): visible = false)

func open(uid: String, date_str: String):
	user_id = uid
	target_date = date_str
	if has_node("%DateInfo"): date_info.text = "Eintrag für: " + date_str
	
	start_slider.value = 8.0
	end_slider.value = 16.5
	
	# --- NEU: Standard-Projekt aus der Config laden ---
	if has_node("%ProjectInput"): 
		var default_proj = Config.get_value("business", "default_project", "Allgemein")
		project_input.text = default_proj
	
	_update_input_from_slider(start_input, start_slider.value)
	_update_input_from_slider(end_input, end_slider.value)
	visible = true

func _update_input_from_slider(input_field: LineEdit, value: float):
	var h = int(value)
	var m = int(round((value - h) * 60))
	if m == 60: 
		h += 1
		m = 0
	input_field.text = "%02d:%02d" % [h, m]
	_validate_times()

func _update_slider_from_text(slider: HSlider, text: String):
	var parts = text.split(":")
	if parts.size() >= 1:
		var h = clampi(parts[0].to_int(), 0, 23)
		var m = 0
		if parts.size() >= 2:
			m = clampi(parts[1].to_int(), 0, 59)
		slider.value = h + (m / 60.0)
	_validate_times()

func _validate_times():
	# Nachtschicht-Erkennung: Wenn Ende vor Start, ist es der nächste Tag
	if end_slider.value < start_slider.value:
		end_input.add_theme_color_override("font_color", Color.CYAN) # Blau für Nachtschicht
		if has_node("%DateInfo"):
			date_info.text = "Schicht endet am Folgetag (+1)"
	else:
		end_input.remove_theme_color_override("font_color")
		if has_node("%DateInfo"):
			date_info.text = "Eintrag für: " + target_date
	
	save_btn.disabled = false # In der Nachtschicht-Logik ist fast jede Kombi valide

func _on_save():
	var start_val = start_slider.value
	var end_val = end_slider.value
	
	# NACHTSCHICHT BERECHNUNG
	var dur_hours = 0.0
	if end_val < start_val:
		# Schicht geht über Mitternacht (z.B. 22 bis 06 Uhr)
		dur_hours = (24.0 - start_val) + end_val
	else:
		dur_hours = end_val - start_val
		
	var total_mins = int(dur_hours * 60)
	var proj = project_input.text if project_input.text != "" else "Manuell"
	
	# Auto-Pause
	var break_min = 0
	var auto_enabled = Config.get_value("business", "auto_break_after_6h", true)
	var standard_break = Config.get_value("business", "daily_break_minutes", 30)
	
	if auto_enabled and dur_hours >= 6.0:
		break_min = int(standard_break)
		total_mins -= break_min
	
	# Senden
	Store.add_manual_entry(user_id, target_date, total_mins, proj, break_min)
	
	entry_saved.emit()
	visible = false
