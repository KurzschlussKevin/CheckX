extends Control

# --- UI REFERENZEN ---
@onready var login_panel: PanelContainer = %LoginPanel
@onready var center_container: CenterContainer = $CenterContainer
@onready var title: Label = %Title
@onready var register_fields: VBoxContainer = %RegisterFields
@onready var first_name_input: LineEdit = %FirstNameInput
@onready var last_name_input: LineEdit = %LastNameInput
@onready var email_input: LineEdit = %EmailInput
@onready var password_input: LineEdit = %PasswordInput
@onready var confirm_box: VBoxContainer = %ConfirmPasswordBox
@onready var confirm_input: LineEdit = %ConfirmPasswordInput
@onready var keep_logged_in_check: CheckBox = %KeepLoggedInCheck
@onready var status_label: Label = %StatusLabel
@onready var submit_button: Button = %SubmitButton
@onready var switch_button: Button = %SwitchModeButton

var is_register_mode: bool = false
var is_loading: bool = false

func _ready() -> void:
	switch_button.pressed.connect(_on_switch_mode_pressed)
	submit_button.pressed.connect(_on_submit_pressed)
	
	if Store.has_signal("login_completed"):
		Store.login_completed.connect(_on_server_response)
	
	status_label.text = ""
	_apply_ui_state()
	_force_window_resize(true)
	
	# --- AUTO-LOGIN LOGIK ---
	# 1. Prüfen, ob "Angemeldet bleiben" aktiv ist
	var keep_logged = Config.get_value("auth", "keep_logged_in", false)
	
	if keep_logged:
		# 2. Prüfen, ob der Store bereits einen Token aus der Datei geladen hat
		if not Store.token.is_empty():
			_show_status("Automatische Anmeldung...", false)
			# Optional: Hier könnte man noch einen API-Test machen, 
			# aber für den Anfang springen wir direkt zum Ladescreen
			await get_tree().create_timer(0.5).timeout
			get_tree().change_scene_to_file("res://app/modules/loadingscreen/loadingscreen.tscn")
			return # Beendet _ready, damit der Rest nicht ausgeführt wird
			
		# 3. Falls kein Token da ist, aber die Mail gespeichert war: Feld ausfüllen
		var last_mail = Config.get_value("auth", "last_email", "")
		if last_mail != "":
			email_input.text = last_mail
			keep_logged_in_check.button_pressed = true
	
	# Animation nur zeigen, wenn kein Auto-Login stattfindet
	login_panel.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(login_panel, "modulate:a", 1.0, 0.4)

## KERN-LOGIK: Passt das physikalische Betriebssystem-Fenster an
func _force_window_resize(instant: bool = false) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	var node_size = login_panel.get_combined_minimum_size()
	var padding = Vector2(60, 60) 
	var target_size = node_size + padding
	
	var win = get_window()
	win.mode = Window.MODE_WINDOWED
	
	if instant:
		win.size = Vector2i(target_size)
		win.content_scale_size = Vector2i(target_size)
		win.move_to_center()
	else:
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(win, "size", Vector2i(target_size), 0.3)
		tween.tween_property(win, "content_scale_size", Vector2i(target_size), 0.3)
		
		var screen_rect = DisplayServer.screen_get_usable_rect(win.current_screen)
		var center_pos = Vector2(screen_rect.position) + (Vector2(screen_rect.size) / 2.0) - (target_size / 2.0)
		tween.tween_property(win, "position", Vector2i(center_pos), 0.3)

	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)

func _on_switch_mode_pressed() -> void:
	if is_loading: return
	is_register_mode = !is_register_mode
	
	var fade_out = create_tween()
	fade_out.tween_property(login_panel, "modulate:a", 0.0, 0.1)
	await fade_out.finished
	
	_apply_ui_state()
	_force_window_resize(false)
	
	var fade_in = create_tween()
	fade_in.tween_property(login_panel, "modulate:a", 1.0, 0.2)

func _apply_ui_state() -> void:
	register_fields.visible = is_register_mode
	confirm_box.visible = is_register_mode
	keep_logged_in_check.visible = !is_register_mode
	
	title.text = "Registrieren" if is_register_mode else "Login"
	submit_button.text = "Konto erstellen" if is_register_mode else "Anmelden"
	switch_button.text = "Bereits ein Konto? Login" if is_register_mode else "Noch kein Konto? Registrieren"
	status_label.text = ""

func _on_submit_pressed() -> void:
	if is_loading: return
	
	if is_register_mode:
		if first_name_input.text.is_empty() or last_name_input.text.is_empty():
			_perform_error_shake("Vor- und Nachname erforderlich!")
			return
		if password_input.text != confirm_input.text:
			_perform_error_shake("Passwörter ungleich!")
			return
			
	if email_input.text.is_empty() or password_input.text.is_empty():
		_perform_error_shake("Bitte alle Felder ausfüllen!")
		return

	_start_auth_process()

func _perform_error_shake(msg: String) -> void:
	_show_status(msg, true)
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
	var pos = login_panel.position
	tween.tween_property(login_panel, "position:x", pos.x + 8, 0.05)
	tween.tween_property(login_panel, "position:x", pos.x - 8, 0.05)
	tween.tween_property(login_panel, "position:x", pos.x, 0.05)

func _start_auth_process() -> void:
	is_loading = true
	submit_button.disabled = true
	_show_status("Verbindung zum Server...", false)
	
	if is_register_mode:
		Store.register(first_name_input.text, last_name_input.text, email_input.text, password_input.text)
	else:
		Store.login(email_input.text, password_input.text)

# VERBESSERT: Verarbeitet jetzt die Daten inkl. Token
func _on_server_response(success: bool, message: String, data: Dictionary = {}) -> void:
	is_loading = false
	submit_button.disabled = false
	
	if success:
		_show_status(message, false)
		
		if !is_register_mode:
			# Token permanent speichern (falls in der Antwort vorhanden)
			if data.has("access_token"):
				Store.save_token(data.access_token, data.user)
			
			# Config-Einstellungen für Auto-Fill
			Config.set_value("auth", "keep_logged_in", keep_logged_in_check.button_pressed)
			if keep_logged_in_check.button_pressed:
				Config.set_value("auth", "last_email", email_input.text)
		
		await get_tree().create_timer(0.6).timeout
		get_tree().change_scene_to_file("res://app/modules/loadingscreen/loadingscreen.tscn")
	else:
		_perform_error_shake(message)

func _show_status(msg: String, is_error: bool) -> void:
	status_label.text = msg
	var color = Color.INDIAN_RED if is_error else Color.PALE_GREEN
	status_label.add_theme_color_override("font_color", color)
