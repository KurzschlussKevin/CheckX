extends Control

# UI Referenzen (Bestehende)
@onready var work_hours_spin = %WorkHoursSpin
@onready var break_time_spin = %BreakTimeSpin
@onready var core_start_spin = $Arbeitszeit/M/V/Card_Rules/V/CoreTimeStart
@onready var core_end_spin = $Arbeitszeit/M/V/Card_Rules/V/CoreTimeEnd
@onready var auto_break_check = $Arbeitszeit/M/V/Card_Rules/V/BreakRuleCheck
@onready var holiday_opt = $Arbeitszeit/M/V/Card_Rules/V/HolidayOption
@onready var vacation_spin = $Arbeitszeit/M/V/Card_Quota/V/VacationQuotaSpin

# UI Referenzen (NEU: Erfassung - für jeden Nutzer frei)
@onready var default_project_input = %DefaultProjectInput
@onready var auto_stop_check = %AutoStopCheck
@onready var require_desc_check = $Arbeitszeit/M/V/Card_Tracking/V/RequireDescCheck

func _ready() -> void:
	_load_business_settings()
	_check_admin_permissions()
	_connect_signals()
	
	_format_time_display(core_start_spin)
	_format_time_display(core_end_spin)

# 1. PRÜFUNG: Admin vs. Nutzer
func _check_admin_permissions() -> void:
	var is_admin = Store.current_user.get("role", "") == "Admin"
	
	# Diese Felder bleiben Admin-exklusiv (Firmenregeln)
	work_hours_spin.editable = is_admin
	break_time_spin.editable = is_admin
	core_start_spin.editable = is_admin
	core_end_spin.editable = is_admin
	auto_break_check.disabled = !is_admin
	holiday_opt.disabled = !is_admin
	vacation_spin.editable = is_admin
	
	# DIESER BEREICH IST JETZT FÜR JEDEN FREI:
	default_project_input.editable = true 
	auto_stop_check.disabled = false
	require_desc_check.disabled = false

# 2. LADEN: Werte aus Config
func _load_business_settings() -> void:
	# Admin-Werte
	work_hours_spin.value = Config.get_value("business", "daily_work_hours", 8.0)
	break_time_spin.value = Config.get_value("business", "daily_break_minutes", 30)
	core_start_spin.value = Config.get_value("business", "core_time_start", 9.0)
	core_end_spin.value = Config.get_value("business", "core_time_end", 15.0)
	auto_break_check.button_pressed = Config.get_value("business", "auto_break_after_6h", true)
	holiday_opt.selected = Config.get_value("business", "holiday_region", 0)
	vacation_spin.value = Config.get_value("business", "vacation_days_quota", 30)
	
	# Erfassungs-Werte (Nutzer-individuell)
	default_project_input.text = Config.get_value("business", "default_project", "Allgemein")
	auto_stop_check.button_pressed = Config.get_value("business", "auto_stop_on_exit", false)
	require_desc_check.button_pressed = Config.get_value("business", "require_description", false)

# 3. VERBINDEN & SPEICHERN
func _connect_signals() -> void:
	# Formatierung für Admin-Spins
	core_start_spin.value_changed.connect(func(v): _format_time_display(core_start_spin))
	core_end_spin.value_changed.connect(func(v): _format_time_display(core_end_spin))
	
	# Signale für Admin-Werte (nur wenn Admin)
	if Store.current_user.get("role") == "Admin":
		work_hours_spin.value_changed.connect(func(v): Config.set_value("business", "daily_work_hours", v))
		break_time_spin.value_changed.connect(func(v): Config.set_value("business", "daily_break_minutes", int(v)))
		core_start_spin.value_changed.connect(func(v): Config.set_value("business", "core_time_start", v))
		core_end_spin.value_changed.connect(func(v): Config.set_value("business", "core_time_end", v))
		auto_break_check.toggled.connect(func(v): Config.set_value("business", "auto_break_after_6h", v))
		holiday_opt.item_selected.connect(func(v): Config.set_value("business", "holiday_region", v))
		vacation_spin.value_changed.connect(func(v): Config.set_value("business", "vacation_days_quota", int(v)))
	
	# Signale für JEDEN NUTZER (Erfassung)
	default_project_input.text_changed.connect(func(new_text): 
		Config.set_value("business", "default_project", new_text)
	)
	auto_stop_check.toggled.connect(func(v): 
		Config.set_value("business", "auto_stop_on_exit", v)
	)
	require_desc_check.toggled.connect(func(v): 
		Config.set_value("business", "require_description", v)
	)

func _format_time_display(spin: SpinBox) -> void:
	var val = spin.value
	var hours = int(val)
	var minutes = int((val - hours) * 60)
	spin.suffix = " (%02d:%02d Uhr)" % [hours, minutes]
