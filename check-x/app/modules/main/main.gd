extends Control

# Wir nutzen % für Unique Names, da dies am sichersten gegen Verschachtelungs-Fehler ist
@onready var card_grid = get_node_or_null("%CardGrid")
@onready var search_field = get_node_or_null("%SearchField")

var card_scene = preload("res://app/modules/employees/employee_card.tscn")

var employee_data = [
	{"name": "Max Mustermann", "role": "Administrator", "status": "Anwesend"},
	{"name": "Erika Musterfrau", "role": "Projektleiterin", "status": "Abwesend"},
	{"name": "Kevin Kurzschluss", "role": "IT-Support", "status": "Im Meeting"},
	{"name": "Sarah Sonnenschein", "role": "Marketing", "status": "Anwesend"}
]

func _ready() -> void:
	# Fehler abfangen, falls Nodes im Editor nicht als "Unique Name" markiert wurden
	if card_grid == null or search_field == null:
		printerr("KRITISCH: Nodes nicht gefunden! Rechtsklick auf 'CardGrid' und 'SearchField' -> 'Access as Unique Name' aktivieren!")
		return
	
	_render_cards(employee_data)
	search_field.text_changed.connect(_on_search_text_changed)

func _render_cards(data_to_show: Array) -> void:
	if not card_grid: return
	
	for child in card_grid.get_children():
		child.queue_free()
	
	for emp in data_to_show:
		var card = card_scene.instantiate()
		card_grid.add_child(card)
		
		card.get_node("%Name").text = emp["name"]
		card.get_node("%Role").text = emp["role"]
		
		var badge = card.get_node("%StatusBadge")
		badge.text = emp["status"].to_upper()
		
		match emp["status"]:
			"Anwesend": badge.add_theme_color_override("font_color", Color.PALE_GREEN)
			"Abwesend": badge.add_theme_color_override("font_color", Color.INDIAN_RED)
			"Im Meeting": badge.add_theme_color_override("font_color", Color.LIGHT_SKY_BLUE)
		
		card.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(card_grid.get_child_count() * 0.05)

func _on_search_text_changed(new_text: String) -> void:
	var filtered_data = employee_data.filter(func(emp): 
		return new_text.is_empty() or \
		new_text.to_lower() in emp["name"].to_lower() or \
		new_text.to_lower() in emp["role"].to_lower()
	)
	_render_cards(filtered_data)
