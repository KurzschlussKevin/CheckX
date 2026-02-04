extends Control

@onready var user: LineEdit = $Center/Card/VBox/User
@onready var passw: LineEdit = $Center/Card/VBox/Pass
@onready var msg: Label = $Center/Card/VBox/Msg
@onready var btn: Button = $Center/Card/VBox/LoginBtn


func _ready() -> void:
	btn.pressed.connect(_on_login)
	Authservice.login_success.connect(_on_success)
	Authservice.login_failed.connect(_on_failed)

func _on_login() -> void:
	msg.text = ""
	Authservice.login(user.text, passw.text)

func _on_success(_u: Dictionary) -> void:
	# Wechsel zur MainTemplate
	get_tree().change_scene_to_file("res://app/modules/main/MainTemplate.tscn")

func _on_failed(reason: String) -> void:
	msg.text = reason
