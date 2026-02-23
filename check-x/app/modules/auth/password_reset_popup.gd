extends Window

@onready var token_input: LineEdit = %TokenInput
@onready var new_password_input: LineEdit = %NewPasswordInput
@onready var confirm_password_input: LineEdit = %ConfirmPasswordInput
@onready var status_label: Label = %StatusLabel
@onready var change_button: Button = %ChangeButton

var is_loading: bool = false

func _ready() -> void:
	change_button.pressed.connect(_on_change_pressed)
	close_requested.connect(queue_free)
	status_label.text = ""

func _on_change_pressed() -> void:
	if is_loading: return
	
	if token_input.text.is_empty() or new_password_input.text.is_empty():
		_show_error("Bitte alle Felder ausfüllen!")
		return
		
	if new_password_input.text != confirm_password_input.text:
		_show_error("Passwörter stimmen nicht überein!")
		return
		
	_start_reset_request()

func _start_reset_request() -> void:
	is_loading = true
	change_button.disabled = true
	status_label.text = "Wird verarbeitet..."
	status_label.add_theme_color_override("font_color", Color.PALE_GREEN)
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	
	var url = Config.API_URL + "/auth/reset-password"
	var body = JSON.stringify({
		"token": token_input.text,
		"new_password": new_password_input.text
	})
	var headers = ["Content-Type: application/json"]
	
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_request_completed(_result, response_code, _headers, body) -> void:
	is_loading = false
	change_button.disabled = false
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200:
		# Erfolg! Wir nutzen das globale Toast-System
		if has_node("/root/Toast"):
			get_node("/root/Toast").show_message("Erfolg", "Passwort wurde geändert.")
		
		await get_tree().create_timer(1.5).timeout
		queue_free()
	else:
		var msg = "Fehler beim Zurücksetzen."
		if response and response.has("detail"):
			msg = response.detail
		_show_error(msg)

func _show_error(msg: String) -> void:
	status_label.text = msg
	status_label.add_theme_color_override("font_color", Color.INDIAN_RED)
