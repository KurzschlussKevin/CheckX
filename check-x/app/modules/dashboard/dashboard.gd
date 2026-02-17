extends Control

@onready var tile_grid = %TileGrid
var stat_card_scene = preload("res://app/modules/dashboard/stat_card.tscn")

var work_time_card = null
var uid = "001" # HINWEIS: Sollte dynamisch über Store.get_current_user_id() gesetzt werden

func _ready() -> void:
	# Auf Einstellungsänderungen hören
	if Config.has_signal("settings_changed"):
		Config.settings_changed.connect(_on_config_changed)
	
	_build_dashboard()

func _process(_delta: float) -> void:
	_update_live_timer()

func _build_dashboard() -> void:
	# Grid leeren
	for c in tile_grid.get_children(): c.queue_free()
	work_time_card = null
	
	# Kacheln basierend auf Config laden
	if Config.get_value("dashboard", "show_welcome", true):
		_add_stat("BEGRÜSSUNG", "Hallo Chef", Time.get_date_string_from_system(), Color.CORNFLOWER_BLUE)

	if Config.get_value("dashboard", "show_revenue", true):
		_add_stat("UMSATZ (MONAT)", "42.150 €", "+ 18.4%", Color.PALE_GREEN)
	
	if Config.get_value("dashboard", "show_employees", true):
		_add_stat("MITARBEITER", str(Store.get_employee_count()), "Alle aktiv", Color.WHITE)
	
	if Config.get_value("dashboard", "show_timer", true):
		work_time_card = _add_stat("AKTUELLE ARBEITSZEIT", "00:00:00", "Timer inaktiv", Color.TURQUOISE)
	
	if Config.get_value("dashboard", "show_tasks", true):
		_add_stat("OFFENE TASKS", "12", "3 mit hoher Prio", Color.INDIAN_RED)

func _update_live_timer():
	if work_time_card == null: return
	
	if Store.is_timer_running(uid):
		var start = Store.get_timer_start(uid)
		var now = Time.get_unix_time_from_system()
		var diff = now - start
		
		var h = int(diff / 3600)
		var m = int(fmod(diff, 3600) / 60)
		var s = int(fmod(diff, 60))
		
		work_time_card.get_node("%Value").text = "%02d:%02d:%02d" % [h, m, s]
		work_time_card.get_node("%Trend").text = "Timer läuft..."
		work_time_card.get_node("%Trend").add_theme_color_override("font_color", Color.GREEN)
	else:
		work_time_card.get_node("%Value").text = "00:00:00"
		work_time_card.get_node("%Trend").text = "Inaktiv"
		work_time_card.get_node("%Trend").add_theme_color_override("font_color", Color.GRAY)

func _add_stat(title, val, trend, col) -> PanelContainer:
	var card = stat_card_scene.instantiate()
	tile_grid.add_child(card)
	card.get_node("%Title").text = title
	card.get_node("%Value").text = val
	card.get_node("%Value").add_theme_color_override("font_color", col)
	card.get_node("%Trend").text = trend
	return card

func _on_config_changed(section, _key, _val):
	if section == "dashboard":
		_build_dashboard()
