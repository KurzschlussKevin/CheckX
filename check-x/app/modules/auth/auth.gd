extends Control

# --- UI REFERENZEN (Unique Names %) ---
@onready var login_panel: PanelContainer = $CenterContainer/LoginPanel
@onready var center_container: CenterContainer = $CenterContainer
@onready var title: Label = %Title
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
	# Start-Konfiguration
	status_label.text = ""
	_update_ui_mode()
	
	# Warten bis das Layout initial berechnet wurde
	await get_tree().process_frame
	_force_window_resize()

## Die Kern-Funktion: Passt das Fenster physikalisch an das Panel an
func _force_window_resize() -> void:
	# 1. Wir warten kurz, damit Godot die Mindestgröße (minimum_size) berechnet
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 2. Die Größe abrufen, die das Panel wirklich braucht
	var node_size = login_panel.get_combined_minimum_size()
	
	# Optionaler Puffer (Rahmen um die Karte)
	var padding = Vector2(40, 40) 
	var target_size = node_size + padding
	
	var win = get_window()
	win.mode = Window.MODE_WINDOWED
	
	# 3. DAS FENSTER ANPASSEN (Physikalisch)
	win.size = Vector2i(target_size)
	
	# 4. DIE INTERNE SKALIERUNG ANPASSEN (Verhindert schwarze Balken)
	# Hier wird die "Leinwand" auf die exakte Fenstergröße gesetzt
	win.content_scale_size = Vector2i(target_size)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	
	# 5. Zentrieren auf dem Monitor
	win.move_to_center()
	
	# 6. Container ausrichten
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)

func _update_ui_mode() -> void:
	confirm_box.visible = is_register_mode
	title.text = "Registrieren" if is_register_mode else "Login"
	submit_button.text = "Konto erstellen" if is_register_mode else "Anmelden"
	switch_button.text = "Bereits ein Konto? Login" if is_register_mode else "Noch kein Konto? Registrieren"
	
	# Wenn die Nodes bereit sind, Fenster neu anpassen
	if is_node_ready():
		_force_window_resize()

func _on_switch_mode_pressed() -> void:
	if is_loading: return
	is_register_mode = !is_register_mode
	_update_ui_mode()

func _on_submit_pressed() -> void:
	if is_loading: return
	
	var email = email_input.text
	var password = password_input.text
	
	if email.is_empty() or password.is_empty():
		_show_status("Bitte alles ausfüllen!", true)
		return
		
	if is_register_mode and password != confirm_input.text:
		_show_status("Passwörter ungleich!", true)
		return

	_start_auth_process()

func _start_auth_process() -> void:
	is_loading = true
	submit_button.disabled = true
	submit_button.text = "Bitte warten..."
	_show_status("Verbindung...", false)
	
	await get_tree().create_timer(1.5).timeout
	
	_show_status("Erfolgreich!", false)
	# _transition_to_game()

func _show_status(msg: String, is_error: bool) -> void:
	status_label.text = msg
	var color = Color.INDIAN_RED if is_error else Color.PALE_GREEN
	status_label.add_theme_color_override("font_color", color)

## Stellt alles wieder auf 1080p Standard zurück
func _transition_to_game() -> void:
	var win = get_window()
	# Zurück auf Standard-Auflösung (z.B. 1920x1080)
	win.content_scale_size = Vector2i(1920, 1080)
	win.mode = Window.MODE_MAXIMIZED 
	get_tree().change_scene_to_file("res://dein_spiel.tscn")
