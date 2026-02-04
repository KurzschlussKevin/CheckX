extends Control

@onready var content: Control = %Content
@onready var sidebar = %Sidebar

func _ready() -> void:
	# Router Container setzen
	Scenerouter.set_container(content)

	# Korrigierter Pfad zum Dialog (Ordnerstruktur laut Dateiliste: app/ui/dialogs/...)
	var dialog_path := "res://app/ui/dialogs/ConfirmUnsavedDialog.tscn"
	var dialog_scene := load(dialog_path) as PackedScene
	
	if dialog_scene:
		var dialog = dialog_scene.instantiate()
		add_child(dialog)
		Unsavedguard.set_dialog(dialog)
	else:
		push_error("ConfirmUnsavedDialog.tscn nicht unter " + dialog_path + " gefunden.")

	# Sidebar Signal verbinden
	if sidebar.has_signal("route_selected"):
		sidebar.route_selected.connect(_on_route_selected)

	# Start-Route setzen
	Scenerouter.goto("dashboard")

func _on_route_selected(route_key: String) -> void:
	Scenerouter.goto(route_key)
