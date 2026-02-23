extends Control

# --- UI REFERENZEN (Dynamische Suche in Sub-Szenen) ---
@onready var save_btn = find_child("SaveProfileBtn", true, false)

# Profil Felder
@onready var inp_name = find_child("NameInput", true, false)
@onready var inp_job = find_child("JobTitleInput", true, false)
@onready var inp_mail = find_child("EmailInput", true, false)
@onready var inp_dept = find_child("DeptInput", true, false)
@onready var inp_phone = find_child("PhoneInput", true, false) 
@onready var inp_empid = find_child("EmpIdInput", true, false) # NEU: Referenz für Personalnummer

# Dashboard Konfig (Checkboxen aus settings_personal.tscn)
@onready var check_welcome = find_child("Check1", true, false)
@onready var check_revenue = find_child("Check2", true, false)
@onready var check_emp = find_child("Check3", true, false)
@onready var check_tasks = find_child("Check4", true, false)
@onready var check_timer = find_child("Check5", true, false)

# Darstellung
@onready var slider_scale = find_child("UIScaleSlider", true, false)

func _ready() -> void:
	# Warten bis alle Sub-Szenen geladen sind
	await get_tree().process_frame
	
	_load_values()
	_connect_signals()

func _load_values() -> void:
	# 1. Benutzerdaten aus Store laden
	var user_data = Store.current_user 
	
	if not user_data.is_empty():
		# PERSONALNUMMER FORMATIEREN: Personalnummer (P-8964)
		if inp_empid:
			var raw_id = user_data.get("emp_id", "XXXX")
			inp_empid.text = "Personalnummer (" + str(raw_id) + ")"
			inp_empid.editable = false
			inp_empid.modulate = Color(0.6, 0.6, 0.6, 0.8) # Deutlich als inaktiv markiert

		# Name und Email setzen
		if inp_name: inp_name.text = user_data.get("name", "")
		if inp_mail: inp_mail.text = user_data.get("email", "")
		
		# Rolle/Jobtitel Logik (System-Rolle)
		if inp_job:
			var user_role = user_data.get("role", "Prüfer")
			inp_job.text = user_role
			
			# Admin-Check: Nur Admins dürfen die System-Rolle bearbeiten
			if user_role == "Admin":
				inp_job.editable = true
				inp_job.modulate = Color.WHITE
			else:
				inp_job.editable = false
				inp_job.modulate = Color(0.7, 0.7, 0.7, 0.8) # Ausgegraut
		
		# Abteilung/Tätigkeit (Freitext)
		if inp_dept:
			inp_dept.text = user_data.get("dept", "")
			inp_dept.editable = true 
			inp_dept.modulate = Color.WHITE
			
		# Mobilnummer setzen
		if inp_phone:
			inp_phone.text = user_data.get("phone", "")
			inp_phone.editable = true
			inp_phone.modulate = Color.WHITE

	# 2. Checkboxen für Dashboard-Module setzen (aus lokaler Config)
	if check_welcome: check_welcome.button_pressed = Config.get_value("dashboard", "show_welcome", true)
	if check_revenue: check_revenue.button_pressed = Config.get_value("dashboard", "show_revenue", true)
	if check_emp: check_emp.button_pressed = Config.get_value("dashboard", "show_employees", true)
	if check_tasks: check_tasks.button_pressed = Config.get_value("dashboard", "show_tasks", true)
	if check_timer: check_timer.button_pressed = Config.get_value("dashboard", "show_timer", true)
	
	# UI Skalierung setzen
	if slider_scale: slider_scale.value = Config.get_value("general", "ui_scale", 1.0)
	
func _connect_signals() -> void:
	if save_btn: 
		if not save_btn.pressed.is_connected(_on_save):
			save_btn.pressed.connect(_on_save)
	
	# Live-Update Signale für Dashboard
	if check_welcome: check_welcome.toggled.connect(func(v): Config.set_value("dashboard", "show_welcome", v))
	if check_revenue: check_revenue.toggled.connect(func(v): Config.set_value("dashboard", "show_revenue", v))
	if check_emp: check_emp.toggled.connect(func(v): Config.set_value("dashboard", "show_employees", v))
	if check_tasks: check_tasks.toggled.connect(func(v): Config.set_value("dashboard", "show_tasks", v))
	if check_timer: check_timer.toggled.connect(func(v): Config.set_value("dashboard", "show_timer", v))
	
	# Live-Update für die UI Skalierung
	if slider_scale: 
		slider_scale.value_changed.connect(func(v): 
			Config.set_value("general", "ui_scale", v)
			get_window().content_scale_factor = v
		)

func _on_save() -> void:
	if not save_btn: return
	
	# UI Feedback Start
	var old_text = save_btn.text
	save_btn.text = "SPEICHERT..."
	save_btn.disabled = true
	
	# 1. Daten für das Profil-Update sammeln
	# Wichtig: Keys müssen exakt mit employees.py übereinstimmen!
	var updated_profile = {
		"name": inp_name.text if inp_name else Store.current_user.get("name", ""),
		"email": inp_mail.text if inp_mail else Store.current_user.get("email", ""),
		"job_title": inp_job.text if inp_job else Store.current_user.get("role", ""),
		"dept": inp_dept.text if inp_dept else "",
		"phone": inp_phone.text if inp_phone else "" 
	}
	
	# Lokale Config für Jobtitel (optionaler Cache)
	if inp_job: Config.set_value("user", "job_title", inp_job.text)
	
	# 2. Profil-Update an Store senden
	if Store.has_method("update_profile"):
		Store.update_profile(updated_profile)
	
	# Kurze Verzögerung für das UI-Gefühl
	await get_tree().create_timer(0.4).timeout
	
	# Erfolg-Toast anzeigen
	_send_toast("Profil erfolgreich gespeichert!", "success")
	
	# Button Animation Erfolg
	save_btn.text = "GESPEICHERT ✔"
	save_btn.modulate = Color.GREEN
	
	await get_tree().create_timer(1.0).timeout
	
	if is_instance_valid(save_btn):
		save_btn.text = old_text
		save_btn.modulate = Color.WHITE
		save_btn.disabled = false

func _send_toast(message: String, type: String) -> void:
	if Store.has_signal("notification_received"):
		Store.notification_received.emit({
			"message": message,
			"type": type
		})
