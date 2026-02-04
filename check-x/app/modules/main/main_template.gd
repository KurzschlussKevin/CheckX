extends Control

@onready var content: Control = %Content
@onready var sidebar = %Sidebar

func _ready() -> void:
	# Router Container setzen
	Scenerouter.set_container(content)

	# Unsaved-Dialog laden und an Guard binden
	var dialog_scene := load("res://app/ui/components/dialogs/ConfirmUnsavedDialog.tscn") as PackedScene
	var dialog = dialog_scene.instantiate()
	add_child(dialog)
	Unsavedguard.set_dialog(dialog)

	# Sidebar Signal
	sidebar.route_selected.connect(_on_route_selected)

	# Default route
	Scenerouter.goto("dashboard")

func _on_route_selected(route_key: String) -> void:
	Scenerouter.goto(route_key)
