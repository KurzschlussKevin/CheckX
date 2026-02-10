extends Control

@onready var tile_grid = %TileGrid

# Wir laden die Kachel-Vorlage
var stat_card_scene = preload("res://app/modules/dashboard/stat_card.tscn")

func _ready() -> void:
	# --- ECHTE DATEN ---
	var emp_count = str(Store.get_employee_count())
	
	# Hier fügen wir die gewünschten Business-Kacheln hinzu
	_add_stat("KUNDEN GESAMT", "842", "+ 5% diese Woche", Color.SKY_BLUE)
	_add_stat("UMSATZ (MONAT)", "42.150 €", "+ 18.4%", Color.PALE_GREEN)
	
	# DYNAMISCH: Mitarbeiterzahl kommt aus dem Store
	_add_stat("MITARBEITER", emp_count, "Alle aktiv", Color.WHITE)
	
	_add_stat("OFFENE TASKS", "12", "3 mit hoher Prio", Color.INDIAN_RED)
	_add_stat("SYSTEMSTATUS", "Online", "Latenz: 24ms", Color.LIGHT_SEA_GREEN)
	_add_stat("LETZTES BACKUP", "Vor 2 Std.", "Erfolgreich", Color.LIGHT_SLATE_GRAY)
	_add_stat("OFFENE SIGNATUREN", "7", "Warten auf Partner", Color.LIGHT_STEEL_BLUE)
	_add_stat("KRANKENSTAND", "3.2 %", "- 0.5% Trend", Color.SALMON)
	_add_stat("AKTUELLE ARBEITSZEIT", "06:42 Std.", "Beginn: 08:00 Uhr", Color.TURQUOISE)
	_add_stat("AKTUELLER BENUTZER", "Administrator", "Letzter Login: Heute, 08:30", Color.MEDIUM_ORCHID)

## Hilfsfunktion um eine Kachel mit Daten zu füllen
func _add_stat(title: String, value: String, trend: String, color: Color):
	var card = stat_card_scene.instantiate()
	tile_grid.add_child(card)
	
	# Zugriff auf die Labels in der instanziierten Kachel
	card.get_node("%Title").text = title.to_upper()
	card.get_node("%Value").text = value
	card.get_node("%Value").add_theme_color_override("font_color", color)
	card.get_node("%Trend").text = trend
	
	# Kleiner Einblend-Effekt für jede Kachel
	card.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(tile_grid.get_child_count() * 0.05)
