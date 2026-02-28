extends Control

# UI Referenzen
@onready var work_hours_spin = %WorkHoursSpin
@onready var break_time_spin = %BreakTimeSpin
@onready var core_start_spin = $Arbeitszeit/M/V/Card_Rules/V/CoreTimeStart
@onready var core_end_spin = $Arbeitszeit/M/V/Card_Rules/V/CoreTimeEnd
@onready var auto_break_check = $Arbeitszeit/M/V/Card_Rules/V/BreakRuleCheck
@onready var holiday_opt = $Arbeitszeit/M/V/Card_Rules/V/HolidayOption
@onready var vacation_spin = $Arbeitszeit/M/V/Card_Quota/V/VacationQuotaSpin

func _ready() -> void:
	_load_business_settings()
	_check_admin_permissions()
	_connect_signals()
	
	# Initiales Formatieren der Uhrzeit-Anzeige
	_format_time_display(core_start_spin)
	_format_time_display(core_end_spin)

# 1. PRÜFUNG: Admin-Rechte
func _check_admin_permissions() -> void:
	var is_admin = Store.current_user.get("role", "") == "Admin"
	
	work_hours_spin.editable = is_admin
	break_time_spin.editable = is_admin
	core_start_spin.editable = is_admin
	core_end_spin.editable = is_admin
	auto_break_check.disabled = !is_admin
	holiday_opt.disabled = !is_admin
	vacation_spin.editable = is_admin

# 2. LADEN: Werte aus Config
func _load_business_settings() -> void:
	work_hours_spin.value = Config.get_value("business", "daily_work_hours", 8.0)
	break_time_spin.value = Config.get_value("business", "daily_break_minutes", 30)
	core_start_spin.value = Config.get_value("business", "core_time_start", 9.0)
	core_end_spin.value = Config.get_value("business", "core_time_end", 15.0)
	auto_break_check.button_pressed = Config.get_value("business", "auto_break_after_6h", true)
	holiday_opt.selected = Config.get_value("business", "holiday_region", 0)
	vacation_spin.value = Config.get_value("business", "vacation_days_quota", 30)

# 3. VERBINDEN & FORMATIEREN
func _connect_signals() -> void:
	# Echtzeit-Formatierung beim Ändern (für die Optik)
	core_start_spin.value_changed.connect(func(v): _format_time_display(core_start_spin))
	core_end_spin.value_changed.connect(func(v): _format_time_display(core_end_spin))
	
	if Store.current_user.get("role") == "Admin":
		work_hours_spin.value_changed.connect(func(v): Config.set_value("business", "daily_work_hours", v))
		break_time_spin.value_changed.connect(func(v): Config.set_value("business", "daily_break_minutes", int(v)))
		core_start_spin.value_changed.connect(func(v): Config.set_value("business", "core_time_start", v))
		core_end_spin.value_changed.connect(func(v): Config.set_value("business", "core_time_end", v))
		auto_break_check.toggled.connect(func(v): Config.set_value("business", "auto_break_after_6h", v))
		holiday_opt.item_selected.connect(func(v): Config.set_value("business", "holiday_region", v))
		vacation_spin.value_changed.connect(func(v): Config.set_value("business", "vacation_days_quota", int(v)))

# Hilfsfunktion: Wandelt 16.5 in "16:30 Uhr" Text um
func _format_time_display(spin: SpinBox) -> void:
	var val = spin.value
	var hours = int(val)
	var minutes = int((val - hours) * 60)
	
	# Wir nutzen das "prefix" oder ein internes Label Trick, 
	# aber am saubersten ist es, das Suffix dynamisch zu setzen
	spin.suffix = " (%02d:%02d Uhr)" % [hours, minutes]
