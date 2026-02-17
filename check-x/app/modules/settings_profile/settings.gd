extends Control

# Wir suchen die Nodes jetzt dynamisch, da sie in Sub-Szenen liegen
@onready var name_input = find_child("NameInput", true, false)
@onready var email_input = find_child("EmailInput", true, false)
@onready var save_profile_btn = find_child("SaveProfileBtn", true, false)

@onready var dark_mode_check = find_child("DarkModeCheck", true, false)
@onready var font_size_slider = find_child("FontSizeSlider", true, false)

@onready var default_project_input = find_child("DefaultProjectInput", true, false)
@onready var auto_stop_check = find_child("AutoStopCheck", true, false)
@onready var two_factor_check = find_child("TwoFactorCheck", true, false)

func _ready() -> void:
	await get_tree().process_frame
	_load_settings_from_store()
	_connect_signals()

func _load_settings_from_store() -> void:
	# Benutzerdaten laden
	var employees = Store.get_all_employees()
	if employees.size() > 0:
		var user = employees[0]
		if name_input: name_input.text = user.name
		if email_input: email_input.text = user.mail
	
	# Einstellungen laden (Mockup)
	if dark_mode_check: dark_mode_check.button_pressed = true 
	if font_size_slider: font_size_slider.value = 16

func _connect_signals() -> void:
	if save_profile_btn:
		save_profile_btn.pressed.connect(_on_save_pressed)
	
	if font_size_slider:
		font_size_slider.value_changed.connect(func(v): print("Schriftgröße:", v))

func _on_save_pressed() -> void:
	if not save_profile_btn: return
	
	save_profile_btn.text = "WIRD GESPEICHERT..."
	save_profile_btn.disabled = true
	
	await get_tree().create_timer(0.6).timeout
	
	var employees = Store.get_all_employees()
	if employees.size() > 0 and name_input and email_input:
		Store.update_employee(employees[0], {
			"name": name_input.text, 
			"mail": email_input.text
		})
	
	save_profile_btn.text = "GESPEICHERT ✔"
	save_profile_btn.modulate = Color(0.4, 0.9, 0.5)
	
	await get_tree().create_timer(1.5).timeout
	
	if is_instance_valid(save_profile_btn):
		save_profile_btn.text = "ÄNDERUNGEN SPEICHERN"
		save_profile_btn.modulate = Color.WHITE
		save_profile_btn.disabled = false
