extends Control

var card_scene = preload("res://app/modules/employees/employee_card.tscn")
var role_colors = {
	"Alle": Color(0.8, 0.8, 0.8),
	"Admin": Color(1.0, 0.3, 0.3),
	"BackOffice": Color(0.3, 0.7, 1.0),
	"Prüfer": Color(0.4, 1.0, 0.6)
}

# HINWEIS: Lokale 'employee_data' Variable wurde gelöscht. Wir nutzen den Store.

var current_filter = "Alle"
var editing_emp = null

func _ready():
	await get_tree().process_frame
	_setup_filter_bar()
	_setup_edit_panel()
	
	# LADE DATEN ZENTRAL AUS DEM STORE
	render_list(Store.get_all_employees())
	
	if has_node("%SearchField"):
		get_node("%SearchField").text_changed.connect(_on_search)
	
	if has_node("%AddButton"):
		get_node("%AddButton").pressed.connect(_open_create_panel)

func _setup_filter_bar():
	if not has_node("%FilterBar"): return
	for role in role_colors.keys():
		var btn = Button.new()
		btn.text = role
		btn.add_theme_color_override("font_color", role_colors[role])
		# Auch beim Filtern holen wir frische Daten aus dem Store
		btn.pressed.connect(func(): current_filter = role; render_list(Store.get_all_employees()))
		get_node("%FilterBar").add_child(btn)

func _setup_edit_panel():
	var role_btn = get_node_or_null("%EditRole")
	if role_btn:
		role_btn.clear()
		for r in ["Admin", "BackOffice", "Prüfer"]: role_btn.add_item(r)
	
	if has_node("%CancelEdit"): get_node("%CancelEdit").pressed.connect(func(): get_node("%QuickEditOverlay").visible = false)
	if has_node("%SaveEdit"): get_node("%SaveEdit").pressed.connect(_save_changes)

func render_list(data):
	var grid = get_node("%CardGrid")
	if not grid: return
	for c in grid.get_children(): c.queue_free()
	
	for emp in data:
		if current_filter != "Alle" and emp.role != current_filter: continue
		if has_node("%SearchField") and !get_node("%SearchField").text.is_empty():
			if not emp.name.to_lower().contains(get_node("%SearchField").text.to_lower()): continue
		
		var card = card_scene.instantiate()
		grid.add_child(card)
		
		var color = role_colors.get(emp.role, Color.WHITE)
		_apply_card_data(card, emp, color)
		
		card.gui_input.connect(_on_card_input.bind(card))
		if card.has_node("%EditButton"):
			card.get_node("%EditButton").pressed.connect(_open_edit.bind(emp))
		
		card.mouse_entered.connect(_on_card_hover.bind(card, true, color))
		card.mouse_exited.connect(_on_card_hover.bind(card, false, color))

func _apply_card_data(card, emp, color):
	if card.has_node("%Name"): card.get_node("%Name").text = emp.name
	if card.has_node("%Role"): 
		card.get_node("%Role").text = emp.role.to_upper()
		card.get_node("%Role").add_theme_color_override("font_color", color)
	if card.has_node("%Mail"): card.get_node("%Mail").text = emp.mail
	if card.has_node("%Phone"): card.get_node("%Phone").text = "Tel: " + str(emp.get("phone", "---"))
	if card.has_node("%IDLabel"): card.get_node("%IDLabel").text = "ID: " + str(emp.get("emp_id", "000"))
	if card.has_node("%ParallaxBG"): card.get_node("%ParallaxBG").text = emp.dept
	
	if card.has_node("%SkillContainer"):
		for s in emp.skills:
			if s.is_empty(): continue
			var l = Label.new()
			l.text = "#" + s
			l.add_theme_font_size_override("font_size", 10)
			l.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.4))
			card.get_node("%SkillContainer").add_child(l)
	
	if emp.get("bday", false) and card.has_node("%BirthdayOverlay"):
		card.get_node("%BirthdayOverlay").visible = true
		var t = card.create_tween().set_loops()
		t.tween_property(card, "modulate", Color(1.2, 1.1, 0.8), 1.0)
		t.tween_property(card, "modulate", Color(1, 1, 1), 1.0)

func _on_card_input(event, card):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var details = card.get_node_or_null("%ExtraDetails")
		if not details: return
		var is_exp = !details.visible
		var t = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
		if is_exp:
			details.visible = true
			t.tween_property(card, "custom_minimum_size:y", 240, 0.3)
			t.tween_property(details, "modulate:a", 1.0, 0.2)
		else:
			t.tween_property(card, "custom_minimum_size:y", 180, 0.3)
			t.tween_property(details, "modulate:a", 0.0, 0.2)
			await t.finished
			details.visible = false

# --- CREATE & EDIT LOGIK ÜBER STORE ---
func _open_create_panel():
	editing_emp = null # Create Mode
	get_node("%EditTitle").text = "NEUEN MITARBEITER ANLEGEN"
	get_node("%EditName").text = ""
	get_node("%EditMail").text = ""
	get_node("%EditPhone").text = ""
	get_node("%EditPersonalID").text = ""
	get_node("%EditDept").text = ""
	get_node("%EditSkills").text = ""
	get_node("%EditRole").selected = 0
	get_node("%QuickEditOverlay").visible = true

func _open_edit(emp):
	editing_emp = emp
	get_node("%EditTitle").text = "MITARBEITER BEARBEITEN"
	get_node("%EditName").text = emp.name
	get_node("%EditMail").text = emp.mail
	get_node("%EditPhone").text = emp.get("phone", "")
	get_node("%EditPersonalID").text = emp.get("emp_id", "")
	get_node("%EditDept").text = emp.dept
	get_node("%EditSkills").text = ", ".join(emp.skills)
	var role_opt = get_node("%EditRole")
	for i in range(role_opt.item_count):
		if role_opt.get_item_text(i) == emp.role: role_opt.selected = i
	get_node("%QuickEditOverlay").visible = true

func _save_changes():
	var new_data = {
		"name": get_node("%EditName").text,
		"mail": get_node("%EditMail").text,
		"phone": get_node("%EditPhone").text,
		"emp_id": get_node("%EditPersonalID").text,
		"dept": get_node("%EditDept").text,
		"role": get_node("%EditRole").get_item_text(get_node("%EditRole").selected),
		"bday": false
	}
	var raw_skills = get_node("%EditSkills").text.split(",")
	var clean_skills = []
	for s in raw_skills: clean_skills.append(s.strip_edges())
	new_data["skills"] = clean_skills

	if editing_emp:
		# UPDATE via Store
		Store.update_employee(editing_emp, new_data)
	else:
		# CREATE via Store
		Store.add_employee(new_data)
	
	get_node("%QuickEditOverlay").visible = false
	render_list(Store.get_all_employees())

func _on_search(_t): 
	render_list(Store.get_all_employees())

func _on_card_hover(card, h, color):
	if card.has_meta("h") and card.get_meta("h") == h: return
	card.set_meta("h", h)
	var tw = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
	var border = card.get_node_or_null("%BorderGlow")
	if h:
		card.z_index = 10
		tw.tween_property(card, "scale", Vector2(1.05, 1.05), 0.2)
		if border: tw.tween_property(border, "border_color", color, 0.2)
	else:
		card.z_index = 0
		card.rotation = 0
		tw.tween_property(card, "scale", Vector2(1, 1), 0.2)
		if border: tw.tween_property(border, "border_color", Color(0,0,0,0), 0.2)

func _process(_delta):
	for card in get_node("%CardGrid").get_children():
		if card.has_meta("h") and card.get_meta("h"):
			var m_pos = card.get_local_mouse_position()
			var pivot = card.pivot_offset
			if pivot == Vector2.ZERO: pivot = Vector2(160, 90)
			var lerp_val = (m_pos - pivot) / pivot
			card.rotation = lerp(card.rotation, deg_to_rad(lerp_val.x * 2.0), 0.1)
			if card.has_node("%ParallaxBG"):
				card.get_node("%ParallaxBG").position = (m_pos - pivot) * -0.05
