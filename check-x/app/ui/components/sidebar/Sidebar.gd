extends PanelContainer

signal route_selected(route_key: String)

func _ready() -> void:
	# Direkte Pfade statt %UniqueNames
	var btns = $VBox/Btns
	btns.get_node("Dashboard").pressed.connect(func(): route_selected.emit("dashboard"))
	btns.get_node("Customers").pressed.connect(func(): route_selected.emit("customers_assets"))
	btns.get_node("Inventory").pressed.connect(func(): route_selected.emit("inventory"))
	btns.get_node("Time").pressed.connect(func(): route_selected.emit("time"))
	btns.get_node("Schedule").pressed.connect(func(): route_selected.emit("schedule"))
	btns.get_node("Calibration").pressed.connect(func(): route_selected.emit("calibration"))
	btns.get_node("Sales").pressed.connect(func(): route_selected.emit("sales"))
	btns.get_node("Export").pressed.connect(func(): route_selected.emit("export"))
	btns.get_node("Settings").pressed.connect(func(): route_selected.emit("settings"))
