extends PanelContainer

signal route_selected(route_key: String)

func _ready() -> void:
	%Dashboard.pressed.connect(func(): emit_signal("route_selected", "dashboard"))
	%Customers.pressed.connect(func(): emit_signal("route_selected", "customers_assets"))
	%Inventory.pressed.connect(func(): emit_signal("route_selected", "inventory"))
	%Time.pressed.connect(func(): emit_signal("route_selected", "time"))
	%Schedule.pressed.connect(func(): emit_signal("route_selected", "schedule"))
	%Calibration.pressed.connect(func(): emit_signal("route_selected", "calibration"))
	%Sales.pressed.connect(func(): emit_signal("route_selected", "sales"))
	%Export.pressed.connect(func(): emit_signal("route_selected", "export"))
	%Settings.pressed.connect(func(): emit_signal("route_selected", "settings"))
