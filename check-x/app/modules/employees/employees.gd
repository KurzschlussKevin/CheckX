extends Control

var card_scene = preload("res://app/modules/employees/employee_card.tscn")
var employee_data = [
	{"name": "Max Mustermann", "role": "Administrator", "dept": "IT", "mail": "max@checkx.de"},
	{"name": "Erika Musterfrau", "role": "Projektleitung", "dept": "ART", "mail": "erika@checkx.de"},
	{"name": "Kevin Kurzschluss", "role": "Entwickler", "dept": "DEV", "mail": "kevin@checkx.de"}
]

func _ready():
	await get_tree().process_frame
	render_list(employee_data)
	if has_node("%SearchField"):
		get_node("%SearchField").text_changed.connect(_on_search_text_changed)

func render_list(list):
	var grid = %CardGrid
	if not grid: return
	for c in grid.get_children(): c.queue_free()
	
	for emp in list:
		var card = card_scene.instantiate()
		grid.add_child(card)
		
		# Initial-Sichtbarkeit der Karte sicherstellen (nicht mehr fast unsichtbar)
		card.modulate = Color(1, 1, 1, 0.9) 
		
		if card.has_node("%Name"): card.get_node("%Name").text = emp.name
		if card.has_node("%Role"): card.get_node("%Role").text = emp.role
		if card.has_node("%Mail"): card.get_node("%Mail").text = emp.mail
		if card.has_node("%ParallaxBG"): card.get_node("%ParallaxBG").text = emp.dept
		
		card.mouse_entered.connect(_on_card_hover.bind(card, true))
		card.mouse_exited.connect(_on_card_hover.bind(card, false))

func _process(_delta):
	for card in %CardGrid.get_children():
		if card.has_meta("is_hovered") and card.get_meta("is_hovered"):
			var m_pos = card.get_local_mouse_position()
			if card.has_node("%ParallaxBG"):
				var bg = card.get_node("%ParallaxBG")
				# Parallax-Bewegung
				bg.position = (m_pos - card.pivot_offset) * -0.05

func _on_card_hover(card: Control, is_hover: bool):
	# Wenn der Zustand bereits gesetzt ist, nichts tun (verhindert Flackern)
	if card.has_meta("is_hovered") and card.get_meta("is_hovered") == is_hover:
		return
		
	card.set_meta("is_hovered", is_hover)
	var details = card.get_node_or_null("%ExtraDetails")
	var border = card.get_node_or_null("%BorderGlow")
	
	if card.has_meta("active_tween"): 
		var t = card.get_meta("active_tween")
		if t: t.kill()
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	card.set_meta("active_tween", tween)
	
	if is_hover:
		card.z_index = 10
		# Sanftere Skalierung gegen Flackern
		tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.2)
		tween.tween_property(card, "modulate", Color(1.1, 1.1, 1.2, 1.0), 0.2)
		if border: tween.tween_property(border, "border_color", Color(0, 0.8, 1, 1), 0.2)
		
		if details:
			var seq = create_tween()
			seq.tween_interval(0.15) # Kürzere Verzögerung für direkteres Feedback
			seq.tween_callback(func(): details.visible = true)
			seq.tween_property(details, "modulate:a", 1.0, 0.2)
	else:
		card.z_index = 0
		tween.tween_property(card, "scale", Vector2(1, 1), 0.2)
		tween.tween_property(card, "modulate", Color(1, 1, 1, 0.9), 0.2)
		if border: tween.tween_property(border, "border_color", Color(0, 0.8, 1, 0), 0.2)
		if details:
			details.visible = false
			details.modulate.a = 0

func _on_search_text_changed(new_text):
	var filtered = employee_data.filter(func(e): return new_text.to_lower() in e.name.to_lower())
	render_list(filtered)
