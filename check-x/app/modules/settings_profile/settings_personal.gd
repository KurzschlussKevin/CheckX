extends Control

# ==========================================
# UI ELEMENTE: PROFIL (Mit Unique % Names)
# ==========================================
@onready var name_input = %NameInput
@onready var job_title_input = %JobTitleInput
@onready var emp_id_input = %EmpIdInput # Ist im Inspector auf "editable = false"
@onready var dept_input = %DeptInput
@onready var email_input = %EmailInput
@onready var phone_input = %PhoneInput
@onready var save_profile_btn = %SaveProfileBtn

# ==========================================
# UI ELEMENTE: DARSTELLUNG (Mit Unique % Names)
# ==========================================
@onready var compact_mode_check = %CompactModeCheck
@onready var sound_effects_check = %SoundEffectsCheck
@onready var ui_scale_slider = %UIScaleSlider
@onready var reduced_motion_check = %ReducedMotionCheck

# UI Elemente ohne % Name (Pfad-basiert aus der tscn)
@onready var date_format_option = $Darstellung/M/V/Card_Format/V/DateFormatOption
@onready var week_start_option = $Darstellung/M/V/Card_Format/V/WeekStartOption

# ==========================================
# NEU: UI ELEMENTE: DASHBOARD (Pfad-basiert)
# ==========================================
@onready var check_welcome = $Dashboard/M/V/Card_Widgets/V/Check1
@onready var check_revenue = $Dashboard/M/V/Card_Widgets/V/Check2
@onready var check_employees = $Dashboard/M/V/Card_Widgets/V/Check3
@onready var check_tasks = $Dashboard/M/V/Card_Widgets/V/Check4
@onready var check_timer = $Dashboard/M/V/Card_Widgets/V/Check5

@onready var col_option = $Dashboard/M/V/Card_Layout/V/ColOption
@onready var refresh_spin = $Dashboard/M/V/Card_Layout/V/RefreshSpin

func _ready() -> void:
	print("🟢 SETTINGS_PERSONAL WURDE GELADEN!")
	_load_settings()
	_connect_signals()


# ---------------------------------------------------------
# 1. DATEN LADEN (Wird beim Start der Szene ausgeführt)
# ---------------------------------------------------------
func _load_settings() -> void:
	# -- Tab: Profil --
	name_input.text = Config.get_value("user", "name", "")
	job_title_input.text = Config.get_value("user", "job_title", "")
	emp_id_input.text = Config.get_value("user", "emp_id", "P-XXXX") 
	dept_input.text = Config.get_value("user", "department", "")
	email_input.text = Config.get_value("user", "email", "")
	phone_input.text = Config.get_value("user", "phone", "")

	# -- Tab: Darstellung --
	compact_mode_check.button_pressed = Config.get_value("general", "compact_mode", false)
	sound_effects_check.button_pressed = Config.get_value("general", "sound_effects", true)
	reduced_motion_check.button_pressed = Config.get_value("general", "reduced_motion", false)
	
	ui_scale_slider.value = Config.get_value("general", "ui_scale", 1.0)
	
	date_format_option.selected = Config.get_value("general", "date_format", 0)
	week_start_option.selected = Config.get_value("general", "week_start", 0)
	
	# -- NEU: Tab: Dashboard --
	check_welcome.button_pressed = Config.get_value("dashboard", "show_welcome", true)
	check_revenue.button_pressed = Config.get_value("dashboard", "show_revenue", true)
	check_employees.button_pressed = Config.get_value("dashboard", "show_employees", true)
	check_tasks.button_pressed = Config.get_value("dashboard", "show_tasks", true)
	check_timer.button_pressed = Config.get_value("dashboard", "show_timer", true)
	
	col_option.selected = Config.get_value("dashboard", "column_mode", 0)
	refresh_spin.value = Config.get_value("dashboard", "refresh_rate", 60)


# ---------------------------------------------------------
# 2. SIGNALE VERBINDEN (Reagieren auf Benutzerinteraktion)
# ---------------------------------------------------------
func _connect_signals() -> void:
	# -- Profil --
	save_profile_btn.pressed.connect(_on_save_profile_pressed)

	# -- Darstellung --
	compact_mode_check.toggled.connect(_on_compact_mode_toggled)
	sound_effects_check.toggled.connect(_on_sound_effects_toggled)
	ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	reduced_motion_check.toggled.connect(_on_reduced_motion_toggled)
	
	date_format_option.item_selected.connect(_on_date_format_selected)
	week_start_option.item_selected.connect(_on_week_start_selected)
	
	# -- NEU: Dashboard --
	check_welcome.toggled.connect(_on_check_welcome_toggled)
	check_revenue.toggled.connect(_on_check_revenue_toggled)
	check_employees.toggled.connect(_on_check_employees_toggled)
	check_tasks.toggled.connect(_on_check_tasks_toggled)
	check_timer.toggled.connect(_on_check_timer_toggled)
	
	col_option.item_selected.connect(_on_col_option_selected)
	refresh_spin.value_changed.connect(_on_refresh_spin_changed)


# ---------------------------------------------------------
# 3. CALLBACK-FUNKTIONEN (Hier wird in die Config gespeichert)
# ---------------------------------------------------------

# Wird aufgerufen, wenn auf "ÄNDERUNGEN SPEICHERN" geklickt wird
func _on_save_profile_pressed() -> void:
	Config.set_value("user", "name", name_input.text)
	Config.set_value("user", "job_title", job_title_input.text)
	Config.set_value("user", "department", dept_input.text)
	Config.set_value("user", "email", email_input.text)
	Config.set_value("user", "phone", phone_input.text)
	
	print("Persönliches Profil wurde erfolgreich gespeichert!")

# --- Darstellung Callbacks ---

func _on_compact_mode_toggled(toggled_on: bool) -> void:
	Config.set_value("general", "compact_mode", toggled_on)

func _on_sound_effects_toggled(toggled_on: bool) -> void:
	Config.set_value("general", "sound_effects", toggled_on)
	if Config.has_method("apply_sound_setting"):
		Config.apply_sound_setting(toggled_on)

func _on_ui_scale_changed(value: float) -> void:
	Config.set_value("general", "ui_scale", value)
	get_window().content_scale_factor = value

func _on_reduced_motion_toggled(toggled_on: bool) -> void:
	Config.set_value("general", "reduced_motion", toggled_on)

func _on_date_format_selected(index: int) -> void:
	Config.set_value("general", "date_format", index)

func _on_week_start_selected(index: int) -> void:
	Config.set_value("general", "week_start", index)

# --- NEU: Dashboard Callbacks ---

func _on_check_welcome_toggled(toggled_on: bool) -> void:
	Config.set_value("dashboard", "show_welcome", toggled_on)

func _on_check_revenue_toggled(toggled_on: bool) -> void:
	Config.set_value("dashboard", "show_revenue", toggled_on)

func _on_check_employees_toggled(toggled_on: bool) -> void:
	Config.set_value("dashboard", "show_employees", toggled_on)

func _on_check_tasks_toggled(toggled_on: bool) -> void:
	Config.set_value("dashboard", "show_tasks", toggled_on)

func _on_check_timer_toggled(toggled_on: bool) -> void:
	Config.set_value("dashboard", "show_timer", toggled_on)

func _on_col_option_selected(index: int) -> void:
	Config.set_value("dashboard", "column_mode", index)

func _on_refresh_spin_changed(value: float) -> void:
	Config.set_value("dashboard", "refresh_rate", value)
