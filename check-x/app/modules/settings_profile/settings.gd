extends Control

# --- UI REFERENZEN (Dynamische Suche in Sub-Szenen) ---
# Wir nutzen Lazy-Loading Variablen, damit sie erst gesucht werden, wenn die Szene bereit ist

@onready var save_btn = find_child("SaveProfileBtn", true, false)

# Profil
@onready var inp_name = find_child("NameInput", true, false)
@onready var inp_job = find_child("JobTitleInput", true, false)
@onready var inp_mail = find_child("EmailInput", true, false)

# Dashboard Konfig (Checkboxen aus settings_personal.tscn)
@onready var check_welcome = find_child("Check1", true, false)
@onready var check_revenue = find_child("Check2", true, false)
@onready var check_emp = find_child("Check3", true, false)
@onready var check_tasks = find_child("Check4", true, false)
@onready var check_timer = find_child("Check5", true, false)

# Darstellung
@onready var check_dark = find_child("DarkModeCheck", true, false)
@onready var slider_scale = find_child("UIScaleSlider", true, false)

func _ready() -> void:
	# Warten bis alle Sub-Szenen geladen sind
	await get_tree().process_frame
	
	_load_values()
	_connect_signals()

func _load_values() -> void:
	# 1. Benutzerdaten aus Store oder Config laden
	var employees = Store.get_all_employees()
	if employees.size() > 0:
		var u = employees[0]
		if inp_name: inp_name.text = u.name
		if inp_mail: inp_mail.text = u.mail
		# Job Title laden wir aus Config, falls im Store nicht vorhanden
		if inp_job: inp_job.text = Config.get_value("user", "job_title", "")

	# 2. Checkboxen setzen
	if check_welcome: check_welcome.button_pressed = Config.get_value("dashboard", "show_welcome", true)
	if check_revenue: check_revenue.button_pressed = Config.get_value("dashboard", "show_revenue", true)
	if check_emp: check_emp.button_pressed = Config.get_value("dashboard", "show_employees", true)
	if check_tasks: check_tasks.button_pressed = Config.get_value("dashboard", "show_tasks", true)
	if check_timer: check_timer.button_pressed = Config.get_value("dashboard", "show_timer", true)
	
	if check_dark: check_dark.button_pressed = Config.get_value("general", "dark_mode", true)
	if slider_scale: slider_scale.value = Config.get_value("general", "ui_scale", 1.0)

func _connect_signals() -> void:
	if save_btn: save_btn.pressed.connect(_on_save)
	
	# Live-Update Signale für Dashboard
	if check_welcome: check_welcome.toggled.connect(func(v): Config.set_value("dashboard", "show_welcome", v))
	if check_revenue: check_revenue.toggled.connect(func(v): Config.set_value("dashboard", "show_revenue", v))
	if check_emp: check_emp.toggled.connect(func(v): Config.set_value("dashboard", "show_employees", v))
	if check_tasks: check_tasks.toggled.connect(func(v): Config.set_value("dashboard", "show_tasks", v))
	if check_timer: check_timer.toggled.connect(func(v): Config.set_value("dashboard", "show_timer", v))
	
	# Live-Update Darstellung
	if slider_scale: 
		slider_scale.value_changed.connect(func(v): 
			Config.set_value("general", "ui_scale", v)
			get_window().content_scale_factor = v
		)

func _on_save() -> void:
	if not save_btn: return
	
	# UI Feedback
	var old_text = save_btn.text
	save_btn.text = "SPEICHERT..."
	save_btn.disabled = true
	
	# Simuliere Speichern
	await get_tree().create_timer(0.5).timeout
	
	# Store Update (Simulation)
	var emps = Store.get_all_employees()
	if emps.size() > 0:
		Store.update_employee(emps[0], {
			"name": inp_name.text if inp_name else "",
			"mail": inp_mail.text if inp_mail else ""
		})
	
	# Job Titel in Config speichern
	if inp_job: Config.set_value("user", "job_title", inp_job.text)
	
	# Erfolg
	save_btn.text = "GESPEICHERT ✔"
	save_btn.modulate = Color.GREEN
	
	await get_tree().create_timer(1.0).timeout
	
	if is_instance_valid(save_btn):
		save_btn.text = old_text
		save_btn.modulate = Color.WHITE
		save_btn.disabled = false
