extends Control

@onready var tile_grid = %TileGrid
var stat_card_scene = preload("res://app/modules/dashboard/stat_card.tscn")

# Variable für das Live-Update der Arbeitszeit
var work_time_card = null
var uid = "001" 

func _ready() -> void:
	# 1. Kunden Kachel
	_add_stat("KUNDEN GESAMT", "842", "+ 5% diese Woche", Color.SKY_BLUE)
	
	# 2. Umsatz Kachel
	_add_stat("UMSATZ (MONAT)", "42.150 €", "+ 18.4%", Color.PALE_GREEN)
	
	# 3. Mitarbeiter Kachel (dynamisch aus dem Store)
	_add_stat("MITARBEITER", str(Store.get_employee_count()), "Alle aktiv", Color.WHITE)
	
	# 4. AKTUELLE ARBEITSZEIT (Die Kachel, die wir live updaten)
	work_time_card = _add_stat("AKTUELLE ARBEITSZEIT", "00:00:00", "Timer inaktiv", Color.TURQUOISE)
	
	# 5. Offene Tasks
	_add_stat("OFFENE TASKS", "12", "3 mit hoher Prio", Color.INDIAN_RED)
	
	# 6. Systemstatus
	_add_stat("SYSTEMSTATUS", "Online", "Latenz: 24ms", Color.LIGHT_SEA_GREEN)

func _process(_delta: float) -> void:
	# Aktualisiert die Arbeitszeit-Kachel in Echtzeit
	_update_work_time_display()

func _update_work_time_display():
	if work_time_card == null: return
	
	if Store.is_timer_running(uid):
		var start_time = Store.get_timer_start(uid)
		var current_time = Time.get_unix_time_from_system()
		var elapsed = current_time - start_time
		
		var hours = int(elapsed / 3600)
		var minutes = int(fmod(elapsed, 3600) / 60)
		var seconds = int(fmod(elapsed, 60))
		
		work_time_card.get_node("%Value").text = "%02d:%02d:%02d" % [hours, minutes, seconds]
		work_time_card.get_node("%Trend").text = "Timer läuft aktiv"
		work_time_card.get_node("%Trend").add_theme_color_override("font_color", Color.PALE_GREEN)
	else:
		work_time_card.get_node("%Value").text = "00:00:00"
		work_time_card.get_node("%Trend").text = "Timer gestoppt"
		work_time_card.get_node("%Trend").add_theme_color_override("font_color", Color.LIGHT_SLATE_GRAY)

func _add_stat(title: String, value: String, trend: String, color: Color) -> PanelContainer:
	var card = stat_card_scene.instantiate()
	tile_grid.add_child(card)
	
	card.get_node("%Title").text = title.to_upper()
	card.get_node("%Value").text = value
	card.get_node("%Value").add_theme_color_override("font_color", color)
	card.get_node("%Trend").text = trend
	
	# Animation beim Erscheinen
	card.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(tile_grid.get_child_count() * 0.05)
	
	return card
