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

# (Hinweis: TimezoneOption und LanguageOption sind im Inspector auf disabled = true gesetzt, 
# weshalb sie hier vorerst kein Event bekommen, aber geladen werden können.)

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
	# Checkboxen
	compact_mode_check.button_pressed = Config.get_value("general", "compact_mode", false)
	sound_effects_check.button_pressed = Config.get_value("general", "sound_effects", true)
	reduced_motion_check.button_pressed = Config.get_value("general", "reduced_motion", false)
	
	# Slider
	ui_scale_slider.value = Config.get_value("general", "ui_scale", 1.0)
	
	# OptionButtons (Dropdowns)
	date_format_option.selected = Config.get_value("general", "date_format", 0)
	week_start_option.selected = Config.get_value("general", "week_start", 0)


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
	# Emp_id überspringen wir absichtlich, da es Read-Only ist
	
	print("Persönliches Profil wurde erfolgreich gespeichert!")
	# Falls du das Toast-System nutzen möchtest (laut deinen Dateien existiert eins):
	# Toast.show_success("Profil gespeichert")

# --- Darstellung Callbacks (Speichern direkt on-the-fly) ---

func _on_compact_mode_toggled(toggled_on: bool) -> void:
	Config.set_value("general", "compact_mode", toggled_on)

func _on_sound_effects_toggled(toggled_on: bool) -> void:
	Config.set_value("general", "sound_effects", toggled_on)
	Config.apply_sound_setting(toggled_on) # <-- Sound sofort an/aus

func _on_ui_scale_changed(value: float) -> void:
	Config.set_value("general", "ui_scale", value)
	# Wende die Skalierung sofort visuell an!
	get_window().content_scale_factor = value

func _on_reduced_motion_toggled(toggled_on: bool) -> void:
	Config.set_value("general", "reduced_motion", toggled_on)

func _on_date_format_selected(index: int) -> void:
	Config.set_value("general", "date_format", index)

func _on_week_start_selected(index: int) -> void:
	Config.set_value("general", "week_start", index)
