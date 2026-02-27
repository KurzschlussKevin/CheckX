extends Node

# --- SERVER KONFIGURATION ---
# Die Basis-URL für alle API-Anfragen an das FastAPI-Backend
const API_URL = "http://127.0.0.1:8000"

# Pfad zur Speicherdatei
const SAVE_PATH = "user://settings.cfg"

# Standard-Werte für alle Einstellungen
var settings = {
	"general": {
		"dark_mode": true,
		"ui_scale": 1.0,
		"font_size": 16,
		"auto_login": false
	},
	"network": {
		"api_url": API_URL, # Hier wird die Konstante als Standardwert genutzt
		"request_timeout": 30
	},
	"dashboard": {
		"show_welcome": true,
		"show_revenue": true,
		"show_employees": true,
		"show_tasks": true,
		"show_timer": true,
		"show_server": false,
		"column_mode": 0, # 0 = Auto, 1 = 3 Spalten
		"refresh_rate": 30
	},
	"user": {
		"name": "",
		"job_title": "",
		"email": ""
	},
	"auth": {
		"keep_logged_in": false,
		"last_email": ""
	}
}

signal settings_changed(section, key, value)

func _ready() -> void:
	load_settings()

func set_value(section: String, key: String, value: Variant) -> void:
	if not settings.has(section):
		settings[section] = {}
	
	settings[section][key] = value
	emit_signal("settings_changed", section, key, value)
	save_settings() # Sofort speichern

func get_value(section: String, key: String, default: Variant = null) -> Variant:
	if settings.has(section) and settings[section].has(key):
		return settings[section][key]
	return default

func save_settings() -> void:
	var config = ConfigFile.new()
	for section in settings:
		for key in settings[section]:
			config.set_value(section, key, settings[section][key])
	config.save(SAVE_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		for section in config.get_sections():
			if not settings.has(section): settings[section] = {}
			for key in config.get_section_keys(section):
				settings[section][key] = config.get_value(section, key)
		print("Einstellungen geladen.")
		_apply_global_settings()
	else:
		print("Keine gespeicherten Einstellungen gefunden. Nutze Standards.")

# Wendet sofort globale Dinge wie Skalierung an
func _apply_global_settings() -> void:
	var scale = get_value("general", "ui_scale", 1.0)
	get_window().content_scale_factor = scale
	
func apply_sound_setting(is_active: bool) -> void:
	# Sucht den Haupt-Audio-Bus (Master) und schaltet ihn stumm (mute), 
	# wenn is_active "false" ist.
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, not is_active)


# --- HILFSFUNKTIONEN FÜR DATUM & KALENDER ---

# Wandelt das System-Datum (YYYY-MM-DD) in das Format aus den Einstellungen um
func get_formatted_date(iso_date: String) -> String:
	var format_type = get_value("general", "date_format", 0)
	
	if format_type == 1:
		return iso_date # Bleibt bei YYYY-MM-DD
		
	# Standard (0): Umbauen zu DD.MM.YYYY
	var parts = iso_date.split("-")
	if parts.size() == 3:
		return "%s.%s.%s" % [parts[2], parts[1], parts[0]]
		
	return iso_date # Fallback, falls das Datum kaputt ist

# Gibt das heutige Datum formatiert zurück
func get_today_formatted() -> String:
	var date = Time.get_date_dict_from_system()
	var iso_date = "%d-%02d-%02d" % [date.year, date.month, date.day]
	return get_formatted_date(iso_date)

# Gibt zurück, ob die Woche am Sonntag starten soll
func is_sunday_first() -> bool:
	# 0 = Montag, 1 = Sonntag
	return get_value("general", "week_start", 0) == 1
