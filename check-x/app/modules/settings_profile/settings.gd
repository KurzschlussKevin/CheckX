extends Control

# --- UI REFERENZEN (Dynamische Suche in Sub-Szenen) ---
@onready var save_btn = find_child("SaveProfileBtn", true, false)

# Profil Felder
@onready var inp_name = find_child("NameInput", true, false)
@onready var inp_job = find_child("JobTitleInput", true, false)
@onready var inp_mail = find_child("EmailInput", true, false)
@onready var inp_dept = find_child("DeptInput", true, false)
@onready var inp_phone = find_child("PhoneInput", true, false) 
@onready var inp_empid = find_child("EmpIdInput", true, false) # Referenz für Personalnummer

# Darstellung
@onready var opt_lang = find_child("LanguageOption", true, false)
@onready var check_compact = find_child("CompactModeCheck", true, false)
@onready var check_sounds = find_child("SoundEffectsCheck", true, false)
@onready var slider_scale = find_child("UIScaleSlider", true, false)
@onready var check_reduced_motion = find_child("ReducedMotionCheck", true, false)

# Dashboard Konfig
@onready var check_welcome = find_child("Check1", true, false)
@onready var check_revenue = find_child("Check2", true, false)
@onready var check_emp = find_child("Check3", true, false)
@onready var check_tasks = find_child("Check4", true, false)
@onready var check_timer = find_child("Check5", true, false)

# NEU: Dashboard Verhalten (Refresh)
@onready var spin_refresh = find_child("RefreshIntervalSpinBox", true, false)

func _ready() -> void:
	# Warten bis alle Sub-Szenen geladen sind
	await get_tree().process_frame
	
	_load_values()
	_connect_signals()

func _load_values() -> void:
	# 1. Benutzerdaten aus Store laden
	var user_data = Store.current_user 
	
	if not user_data.is_empty():
		# PERSONALNUMMER FORMATIEREN
		if inp_empid:
			var raw_id = user_data.get("emp_id", "XXXX")
			inp_empid.text = "Personalnummer (" + str(raw_id) + ")"
			inp_empid.editable = false
			inp_empid.modulate = Color(0.6, 0.6, 0.6, 0.8)

		# Name und Email setzen
		if inp_name: inp_name.text = user_data.get("name", "")
		if inp_mail: inp_mail.text = user_data.get("email", "")
		
		# Rolle/Jobtitel Logik
		if inp_job:
			var user_role = user_data.get("role", "Prüfer")
			inp_job.text = user_role
			if user_role == "Admin":
				inp_job.editable = true
				inp_job.modulate = Color.WHITE
			else:
				inp_job.editable = false
				inp_job.modulate = Color(0.7, 0.7, 0.7, 0.8)
		
		if inp_dept: inp_dept.text = user_data.get("dept", "")
		if inp_phone: inp_phone.text = user_data.get("phone", "")

	# 2. Darstellungswerte laden UND ANWENDEN
	if opt_lang:
		var lang = Config.get_value("appearance", "language", "de")
		opt_lang.selected = 0 if lang == "de" else 1
		opt_lang.disabled = true # Vorerst deaktiviert wie gewünscht
		opt_lang.modulate = Color(0.5, 0.5, 0.5, 0.7)
		TranslationServer.set_locale(lang)

	if check_compact:
		var is_compact = Config.get_value("appearance", "compact_mode", false)
		check_compact.button_pressed = is_compact
		_apply_compact_mode(is_compact)
	
	if check_sounds:
		var sounds_on = Config.get_value("appearance", "sound_enabled", true)
		check_sounds.button_pressed = sounds_on
		if "sound_enabled" in Store: Store.sound_enabled = sounds_on
		
	if check_reduced_motion:
		var reduced = Config.get_value("appearance", "reduced_motion", false)
		check_reduced_motion.button_pressed = reduced
		_apply_reduced_motion(reduced)

	# UI Skalierung beim Start anwenden
	if slider_scale: 
		var scale_val = Config.get_value("general", "ui_scale", 1.0)
		slider_scale.value = scale_val
		get_window().content_scale_factor = scale_val

	# 3. Dashboard-Module
	if check_welcome: check_welcome.button_pressed = Config.get_value("dashboard", "show_welcome", true)
	if check_revenue: check_revenue.button_pressed = Config.get_value("dashboard", "show_revenue", true)
	if check_emp: check_emp.button_pressed = Config.get_value("dashboard", "show_employees", true)
	if check_tasks: check_tasks.button_pressed = Config.get_value("dashboard", "show_tasks", true)
	if check_timer: check_timer.button_pressed = Config.get_value("dashboard", "show_timer", true)
	
	# NEU: Dashboard Refresh-Intervall laden
	if spin_refresh:
		var saved_interval = Config.get_value("dashboard", "refresh_interval", 60)
		spin_refresh.min_value = 30
		spin_refresh.max_value = 600
		spin_refresh.value = clamp(saved_interval, 30, 600)
	
func _connect_signals() -> void:
	if save_btn: 
		if not save_btn.pressed.is_connected(_on_save):
			save_btn.pressed.connect(_on_save)
	
	# --- DARSTELLUNG LIVE UPDATES ---
	if opt_lang:
		opt_lang.item_selected.connect(_on_language_selected)
		
	if check_compact:
		check_compact.toggled.connect(func(v): 
			Config.set_value("appearance", "compact_mode", v)
			_apply_compact_mode(v)
		)
		
	if check_sounds:
		check_sounds.toggled.connect(func(v): 
			Config.set_value("appearance", "sound_enabled", v)
			if "sound_enabled" in Store: Store.sound_enabled = v
		)
		
	if check_reduced_motion:
		check_reduced_motion.toggled.connect(func(v): 
			Config.set_value("appearance", "reduced_motion", v)
			_apply_reduced_motion(v)
		)
	
	if slider_scale: 
		slider_scale.value_changed.connect(func(v): 
			Config.set_value("general", "ui_scale", v)
			get_window().content_scale_factor = v
		)

	# --- DASHBOARD LIVE UPDATES ---
	if check_welcome: check_welcome.toggled.connect(func(v): Config.set_value("dashboard", "show_welcome", v))
	if check_revenue: check_revenue.toggled.connect(func(v): Config.set_value("dashboard", "show_revenue", v))
	if check_emp: check_emp.toggled.connect(func(v): Config.set_value("dashboard", "show_employees", v))
	if check_tasks: check_tasks.toggled.connect(func(v): Config.set_value("dashboard", "show_tasks", v))
	if check_timer: check_timer.toggled.connect(func(v): Config.set_value("dashboard", "show_timer", v))
	
	# NEU: Refresh Intervall Update
	if spin_refresh:
		spin_refresh.value_changed.connect(_on_refresh_changed)

# --- HILFSFUNKTIONEN FÜR LIVE-REAKTION ---

func _on_refresh_changed(value: float) -> void:
	var safe_val = int(clamp(value, 30, 600))
	Config.set_value("dashboard", "refresh_interval", safe_val)
	
	# Das Dashboard über Store-Signal informieren
	if Store.has_signal("dashboard_refresh_updated"):
		Store.dashboard_refresh_updated.emit(safe_val)

func _apply_reduced_motion(active: bool):
	if "reduced_motion" in Store:
		Store.reduced_motion = active

func _apply_compact_mode(active: bool):
	if Store.has_signal("ui_layout_changed"):
		Store.ui_layout_changed.emit("compact" if active else "normal")

func _on_language_selected(index: int) -> void:
	# Bleibt im Code, auch wenn Button oben deaktiviert ist
	var lang_code = "de" if index == 0 else "en"
	Config.set_value("appearance", "language", lang_code)
	TranslationServer.set_locale(lang_code)
	_send_toast("Sprache geändert / Language changed", "info")

func _on_save() -> void:
	if not save_btn: return
	
	var old_text = save_btn.text
	save_btn.text = "SPEICHERT..."
	save_btn.disabled = true
	
	var updated_profile = {
		"name": inp_name.text if inp_name else Store.current_user.get("name", ""),
		"email": inp_mail.text if inp_mail else Store.current_user.get("email", ""),
		"job_title": inp_job.text if inp_job else Store.current_user.get("role", ""),
		"dept": inp_dept.text if inp_dept else "",
		"phone": inp_phone.text if inp_phone else "" 
	}
	
	if inp_job: Config.set_value("user", "job_title", inp_job.text)
	
	if Store.has_method("update_profile"):
		Store.update_profile(updated_profile)
	
	await get_tree().create_timer(0.4).timeout
	_send_toast("Profil erfolgreich gespeichert!", "success")
	
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
