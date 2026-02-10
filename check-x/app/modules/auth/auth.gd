extends Control

# --- UI REFERENZEN (Unique Names %) ---
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
@onready var status_label: Label = %StatusLabel
@onready var submit_button: Button = %SubmitButton
@onready var switch_button: Button = %SwitchModeButton

var is_register_mode: bool = false
var is_loading: bool = false

func _ready() -> void:
	# Signale automatisch verbinden
	switch_button.pressed.connect(_on_switch_mode_pressed)
	submit_button.pressed.connect(_on_submit_pressed)
	
	status_label.text = ""
	
	# Initialen Zustand der UI setzen (Login oder Register)
	_apply_ui_state()
	
	# Start-Animation: Das Panel blendet weich ein
	login_panel.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(login_panel, "modulate:a", 1.0, 0.4)
	
	# Fenster beim Start sofort physisch anpassen
	_force_window_resize(true)

## KERN-LOGIK: Passt das physikalische Betriebssystem-Fenster an
func _force_window_resize(instant: bool = false) -> void:
	# Wir warten Frames, damit Godot die neue Mindestgröße der UI berechnet hat
	await get_tree().process_frame
	await get_tree().process_frame
	
	var node_size = login_panel.get_combined_minimum_size()
	var padding = Vector2(60, 60) 
	var target_size = node_size + padding
	
	var win = get_window()
	win.mode = Window.MODE_WINDOWED
	
	if instant:
		# Sofortige Anpassung ohne Animation
		win.size = Vector2i(target_size)
		win.content_scale_size = Vector2i(target_size)
		win.move_to_center()
	else:
		# Smoothe Fenster-Anpassung per Tween (Morphing)
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(win, "size", Vector2i(target_size), 0.3)
		tween.tween_property(win, "content_scale_size", Vector2i(target_size), 0.3)
		
		# Das Fenster auf dem Monitor zentriert halten während der Skalierung
		var screen_rect = DisplayServer.screen_get_usable_rect(win.current_screen)
		var center_pos = Vector2(screen_rect.position) + (Vector2(screen_rect.size) / 2.0) - (target_size / 2.0)
		tween.tween_property(win, "position", Vector2i(center_pos), 0.3)

	# Container im neuen Fenster-Bereich ausrichten
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)

## MODUS-WECHSEL: Mit weichem Cross-Fade und Fenster-Anpassung
func _on_switch_mode_pressed() -> void:
	if is_loading: return
	is_register_mode = !is_register_mode
	
	# 1. Inhalt kurz ausfaden
	var fade_out = create_tween()
	fade_out.tween_property(login_panel, "modulate:a", 0.0, 0.1)
	await fade_out.finished
	
	# 2. UI-Elemente im Hintergrund umschalten
	_apply_ui_state()
	
	# 3. Fenster-Resize an die neuen Felder (z.B. Namen) anpassen
	_force_window_resize(false)
	
	# 4. Inhalt sanft wieder einfaden
	var fade_in = create_tween()
	fade_in.tween_property(login_panel, "modulate:a", 1.0, 0.2)

## Hilfsfunktion für Texte und Sichtbarkeiten
func _apply_ui_state() -> void:
	register_fields.visible = is_register_mode
	confirm_box.visible = is_register_mode
	
	title.text = "Registrieren" if is_register_mode else "Login"
	submit_button.text = "Konto erstellen" if is_register_mode else "Anmelden"
	switch_button.text = "Bereits ein Konto? Login" if is_register_mode else "Noch kein Konto? Registrieren"
	status_label.text = ""

func _on_submit_pressed() -> void:
	if is_loading: return
	
	# Validierung für Namen bei Registrierung
	if is_register_mode:
		if first_name_input.text.is_empty() or last_name_input.text.is_empty():
			_perform_error_shake("Vor- und Nachname erforderlich!")
			return
		if password_input.text != confirm_input.text:
			_perform_error_shake("Passwörter ungleich!")
			return
			
	# Allgemeine Validierung
	if email_input.text.is_empty() or password_input.text.is_empty():
		_perform_error_shake("Bitte alle Felder ausfüllen!")
		return

	_start_auth_process()

## Feedback bei Fehlern (Wackeln)
func _perform_error_shake(msg: String) -> void:
	_show_status(msg, true)
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
	var pos = login_panel.position
	tween.tween_property(login_panel, "position:x", pos.x + 8, 0.05)
	tween.tween_property(login_panel, "position:x", pos.x - 8, 0.05)
	tween.tween_property(login_panel, "position:x", pos.x, 0.05)

## Platzhalter für den eigentlichen Server-Login
func _start_auth_process() -> void:
	is_loading = true
	submit_button.disabled = true
	_show_status("Authentifizierung...", false)
	
	# Simulierter Ladevorgang (Hier kommt später die Server-Anfrage hin)
	await get_tree().create_timer(1.5).timeout
	
	_show_status("Erfolgreich!", false)
	
	# WECHSEL ZUM LOADINGSCREEN
	# Dieser übernimmt das Fenster-Morphing zurück auf 1920x1080
	get_tree().change_scene_to_file("res://app/modules/loadingscreen/loadingscreen.tscn")

func _show_status(msg: String, is_error: bool) -> void:
	status_label.text = msg
	var color = Color.INDIAN_RED if is_error else Color.PALE_GREEN
	status_label.add_theme_color_override("font_color", color)
