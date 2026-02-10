extends Control

var card_scene = preload("res://app/modules/employees/employee_card.tscn")
var role_colors = {
	"Alle": Color(0.8, 0.8, 0.8),
	"Admin": Color(1.0, 0.3, 0.3),
	"BackOffice": Color(0.3, 0.7, 1.0),
	"Prüfer": Color(0.4, 1.0, 0.6)
}

var employee_data = [
	{
		"name": "Max Admin", "role": "Admin", "dept": "SYS", 
		"mail": "admin@checkx.de", "phone": "+49 123 456", 
		"emp_id": "A-101", "skills": ["Security"], "bday": true
	},
	{
		"name": "Kevin Prüf", "role": "Prüfer", "dept": "QA", 
		"mail": "check@checkx.de", "phone": "+49 987 654", 
		"emp_id": "P-505", "skills": ["Audit"], "bday": false
	}
]

var current_filter = "Alle"
var editing_emp = null

func _ready():
	await get_tree().process_frame
	_setup_filter_bar()
	_setup_edit_panel()
	render_list(employee_data)
	if has_node("%SearchField"):
		%SearchField.text_changed.connect(_on_search)

func _setup_filter_bar():
	if not has_node("%FilterBar"): return
	for role in role_colors.keys():
		var btn = Button.new()
		btn.text = role
		btn.add_theme_color_override("font_color", role_colors[role])
		btn.pressed.connect(func(): current_filter = role; render_list(employee_data))
		%FilterBar.add_child(btn)

func _setup_edit_panel():
	var role_btn = get_node_or_null("%EditRole")
	if role_btn:
		role_btn.clear()
		for r in ["Admin", "BackOffice", "Prüfer"]: role_btn.add_item(r)
	if has_node("%CancelEdit"): %CancelEdit.pressed.connect(func(): %QuickEditOverlay.visible = false)
	if has_node("%SaveEdit"): %SaveEdit.pressed.connect(_save_changes)

func render_list(data):
	var grid = %CardGrid
	if not grid: return
	for c in grid.get_children(): c.queue_free()
	
	for emp in data:
		if current_filter != "Alle" and emp.role != current_filter: continue
		if !%SearchField.text.is_empty() and !%SearchField.text.to_lower() in emp.name.to_lower(): continue
		
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
	if card.has_node("%IDLabel"): card.get_node("%IDLabel").text = "ID: " + str(emp.get("emp_id", "0000"))
	if card.has_node("%ParallaxBG"): card.get_node("%ParallaxBG").text = emp.dept
	
	if card.has_node("%SkillContainer"):
		for s in emp.skills:
			var l = Label.new()
			l.text = "#" + s
			l.add_theme_font_size_override("font_size", 10)
			l.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.4))
			card.get_node("%SkillContainer").add_child(l)
			
	if emp.bday and card.has_node("%BirthdayOverlay"):
		card.get_node("%BirthdayOverlay").visible = true
		# FIX: Tween muss eine Zeitdauer haben!
		var t = create_tween().set_loops()
		t.tween_property(card, "modulate", Color(1.2, 1.1, 0.8), 1.0)
		t.tween_property(card, "modulate", Color(1, 1, 1), 1.0)

func _on_card_input(event, card):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var details = card.get_node("%ExtraDetails")
		var is_exp = !details.visible
		var t = create_tween().set_parallel(true)
		if is_exp:
			details.visible = true
			t.tween_property(card, "custom_minimum_size:y", 240, 0.2)
			t.tween_property(details, "modulate:a", 1.0, 0.2)
		else:
			t.tween_property(card, "custom_minimum_size:y", 180, 0.2)
			t.tween_property(details, "modulate:a", 0.0, 0.2)
			await t.finished
			details.visible = false

func _open_edit(emp):
	editing_emp = emp
	%EditName.text = emp.name
	%EditMail.text = emp.mail
	%EditPhone.text = emp.get("phone", "")
	%EditPersonalID.text = emp.get("emp_id", "")
	%EditDept.text = emp.dept
	%EditSkills.text = ", ".join(emp.skills)
	for i in range(%EditRole.item_count):
		if %EditRole.get_item_text(i) == emp.role: %EditRole.selected = i
	%QuickEditOverlay.visible = true

func _save_changes():
	if editing_emp:
		editing_emp.name = %EditName.text
		editing_emp.mail = %EditMail.text
		editing_emp.phone = %EditPhone.text
		editing_emp.emp_id = %EditPersonalID.text
		editing_emp.dept = %EditDept.text
		editing_emp.role = %EditRole.get_item_text(%EditRole.selected)
		editing_emp.skills = %EditSkills.text.split(",")
		for i in range(len(editing_emp.skills)): editing_emp.skills[i] = editing_emp.skills[i].strip_edges()
		%QuickEditOverlay.visible = false
		render_list(employee_data)

func _on_search(_t): render_list(employee_data)

func _on_card_hover(card, h, color):
	if card.has_meta("h") and card.get_meta("h") == h: return
	card.set_meta("h", h)
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
	if h:
		card.z_index = 10
		tw.tween_property(card, "scale", Vector2(1.06, 1.06), 0.2)
		if card.has_node("%BorderGlow"):
			card.get_node("%BorderGlow").border_color = color
	else:
		card.z_index = 0
		card.rotation = 0
		tw.tween_property(card, "scale", Vector2(1, 1), 0.2)
		if card.has_node("%BorderGlow"):
			card.get_node("%BorderGlow").border_color = Color(color, 0)

func _process(_delta):
	for card in %CardGrid.get_children():
		if card.has_meta("h") and card.get_meta("h"):
			var m_pos = card.get_local_mouse_position()
			var lerp_val = (m_pos - card.pivot_offset) / card.pivot_offset
			card.rotation = lerp(card.rotation, deg_to_rad(lerp_val.x * 2.0), 0.1)
			if card.has_node("%ParallaxBG"):
				card.get_node("%ParallaxBG").position = (m_pos - card.pivot_offset) * -0.05
