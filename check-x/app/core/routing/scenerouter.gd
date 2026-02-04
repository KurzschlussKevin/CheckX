extends Node

signal route_changed(route_key: String)

var _container: Control
var current_route: String = ""
var current_module: Node

func set_container(c: Control) -> void:
	_container = c

func goto(route_key: String) -> void:
	if _container == null:
		push_error("SceneRouter: container not set")
		return
	if route_key == current_route:
		return

	if not Unsavedguard.request_route_change(route_key):
		return

	_force_goto(route_key)

func _force_goto(route_key: String) -> void:
	if current_module and is_instance_valid(current_module):
		current_module.queue_free()
		current_module = null

	current_route = route_key

	# HIER: AppRoutes statt Routes
	var path: String = AppRoutes.MAP.get(route_key, "")
	if path == "":
		push_error("Unknown route: " + route_key)
		return

	var ps := load(path) as PackedScene
	current_module = ps.instantiate()
	_container.add_child(current_module)

	emit_signal("route_changed", route_key)
