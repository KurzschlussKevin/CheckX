extends Control

# --- UI REFERENZEN (Statistiken) ---
@onready var lbl_revenue = find_child("Value", true, false) if find_child("StatRevenue", true, false) else null
@onready var lbl_hours = find_child("Value", true, false) if find_child("StatHours", true, false) else null
@onready var lbl_tasks = find_child("Value", true, false) if find_child("StatTasks", true, false) else null
@onready var welcome_label = %WelcomeLabel if find_child("WelcomeLabel", true, false) else null
@onready var refresh_btn = %RefreshBtn if find_child("RefreshBtn", true, false) else null

# --- UI REFERENZEN (Container für Sichtbarkeit) ---
# Wir suchen die Nodes jetzt dynamisch, um "Node not found" Fehler zu vermeiden
@onready var welcome_box = find_child("WelcomeBox", true, false)
@onready var card_revenue = find_child("StatRevenue", true, false)
@onready var card_hours = find_child("StatHours", true, false)
@onready var card_tasks = find_child("StatTasks", true, false)

# KORREKTUR: Suche nach dem echten Namen "TileGrid" aus der tscn
@onready var dashboard_grid = find_child("TileGrid", true, false)

var current_uid = ""
var refresh_timer: Timer # Dedizierter Timer für den Statistik-Refresh

func _ready():
	# Kurz warten, falls Nodes noch nicht ganz bereit sind
	await get_tree().process_frame
	
	# Pfade für Labels manuell nachjustieren, falls find_child zu ungenau war
	_setup_labels()
	
	# Timer initialisieren
	_setup_refresh_timer()
	
	current_uid = Store.get_current_user_id()
	
	# Begrüßungstext initial laden (Name + formatiertes Datum)
	_update_welcome_text()
	
	if refresh_btn:
		# Verhindern doppelter Verbindungen
		if not refresh_btn.pressed.is_connected(fetch_stats):
			refresh_btn.pressed.connect(fetch_stats)
	
	# LIVE-UPDATE DER EINSTELLUNGEN
	if Config.has_signal("settings_changed"):
		if not Config.settings_changed.is_connected(_on_config_updated):
			Config.settings_changed.connect(_on_config_updated)
	
	# Spezielles Signal für das Intervall (falls in Store.gd definiert)
	if Store.has_signal("dashboard_refresh_updated"):
		if not Store.dashboard_refresh_updated.is_connected(_update_refresh_interval):
			Store.dashboard_refresh_updated.connect(_update_refresh_interval)
			
	# Das Raster beobachtet jetzt live, wenn sich die Fenstergröße ändert!
	if dashboard_grid:
		if not dashboard_grid.resized.is_connected(_on_grid_resized):
			dashboard_grid.resized.connect(_on_grid_resized)
	
	# Initial die Sichtbarkeit und das Layout anwenden
	_apply_visibility()
	_apply_layout()
	
	fetch_stats()

func _setup_labels():
	# Präzisere Suche für die Labels innerhalb ihrer Karten
	if card_revenue: lbl_revenue = card_revenue.find_child("Value", true, false)
	if card_hours: lbl_hours = card_hours.find_child("Value", true, false)
	if card_tasks: lbl_tasks = card_tasks.find_child("Value", true, false)

# Baut den Text aus Name und formatiertem Datum
func _update_welcome_text():
	if welcome_label:
		var user_data = Store.current_user 
		var user_name = user_data.get("name", "Gast") if user_data else "Gast"
		
		# Abfragen, ob das Datum überhaupt angezeigt werden soll
		var show_date = Config.get_value("dashboard", "show_welcome", true)
		
		if show_date:
			var date_str = ""
			# Prüfen ob die neue Funktion in config.gd schon existiert
			if Config.has_method("get_today_formatted"):
				date_str = Config.get_today_formatted()
			else:
				# Fallback, falls du den Code in config.gd noch nicht drin hast
				var date = Time.get_date_dict_from_system()
				date_str = "%02d.%02d.%d" % [date.day, date.month, date.year]
			
			welcome_label.text = "Willkommen, " + str(user_name) + "  |  " + date_str
		else:
			welcome_label.text = "Willkommen, " + str(user_name)

# Timer-Logik aufbauen
func _setup_refresh_timer():
	refresh_timer = Timer.new()
	refresh_timer.name = "DashboardRefreshTimer"
	add_child(refresh_timer)
	refresh_timer.timeout.connect(fetch_stats)
	
	# Start-Intervall aus Config laden
	var saved_interval = Config.get_value("dashboard", "refresh_rate", 30)
	_update_refresh_interval(saved_interval)

# Funktion zum Ändern des Intervalls
func _update_refresh_interval(seconds: int):
	if refresh_timer:
		refresh_timer.wait_time = clamp(seconds, 30, 600) # Sicherstellen des Bereichs
		refresh_timer.start()
		print("Dashboard-Refresh auf " + str(refresh_timer.wait_time) + " Sekunden gesetzt.")

# Reagiert auf Änderungen in den Einstellungen
func _on_config_updated(section: String, key: String, value: Variant):
	if section == "dashboard":
		# Wenn sich eine Checkbox ändert, Sichtbarkeit aktualisieren
		_apply_visibility()
		
		# Wenn sich das Layout (Spalten) ändert
		if key == "column_mode":
			_apply_layout()
			
		# Falls das Intervall in der Config geändert wurde, Timer sofort anpassen
		if key == "refresh_rate":
			_update_refresh_interval(int(value))
			
		# Wenn die Checkbox für "Begrüßung & Datum" geklickt wird, Text anpassen
		if key == "show_welcome":
			_update_welcome_text()
			
	# Wenn das Datumsformat geändert wurde, Begrüßungstext live aktualisieren!
	if section == "general" and key == "date_format":
		_update_welcome_text()

# Steuert die Sichtbarkeit der einzelnen Dashboard-Module
func _apply_visibility():
	if card_revenue:
		card_revenue.visible = Config.get_value("dashboard", "show_revenue", true)
		
	if card_hours:
		card_hours.visible = Config.get_value("dashboard", "show_employees", true)
		
	if card_tasks:
		card_tasks.visible = Config.get_value("dashboard", "show_tasks", true)
		
	# Wir lösen hier ein Layout-Update aus, wenn sich Kacheln ein/ausblenden
	_apply_layout()

# --- Smarte Layout-Logik ---

func _apply_layout():
	# call_deferred stellt sicher, dass Godot die Größenberechnung erst nach dem Zeichnen macht
	call_deferred("_on_grid_resized")

# Diese Funktion berechnet live die Spalten anhand der Fensterbreite!
func _on_grid_resized():
	if not dashboard_grid or not (dashboard_grid is GridContainer):
		return
		
	var col_mode = Config.get_value("dashboard", "column_mode", 0)
	
	if col_mode == 1:
		# MODUS "3 FEST": Immer genau 3 Spalten erzwingen
		dashboard_grid.columns = 3
	else:
		# MODUS "AUTOMATISCH": 
		# 1. Wir zählen, wie viele Kacheln überhaupt sichtbar sind
		var visible_cards = 0
		for child in dashboard_grid.get_children():
			if child.visible:
				visible_cards += 1
				
		if visible_cards == 0:
			visible_cards = 1 # Sicherheits-Fallback
		
		# 2. Wir berechnen, wie viel Platz überhaupt da ist
		var available_width = dashboard_grid.size.x
		if available_width == 0:
			available_width = get_viewport_rect().size.x - 60 # Fallback für Initialisierung
			
		var card_width = 340 # Mindestbreite pro Kachel für sicheren Umbruch
		var max_fitting_cols = max(1, int(available_width / card_width))
		
		# 3. Die Spaltenanzahl ist das Minimum aus sichtbaren Kacheln und dem maximalen Platz
		var auto_cols = min(visible_cards, max_fitting_cols)
		
		if dashboard_grid.columns != auto_cols:
			dashboard_grid.columns = auto_cols

func fetch_stats():
	var url = Store.get_api_url() + "/dashboard/stats?emp_id=" + str(current_uid)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, c, _h, body):
		if c == 200:
			var data = JSON.parse_string(body.get_string_from_utf8())
			if data:
				_update_ui(data)
		else:
			print("Fehler beim Laden der Stats: ", c)
		http.queue_free()
	)
	http.request(url, Store._get_auth_headers())

func _update_ui(data):
	if lbl_revenue:
		var rev = data.get("revenue_week", 0.0)
		lbl_revenue.text = "%.2f €" % rev
		lbl_revenue.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4) if rev > 0 else Color.WHITE)
		
	if lbl_hours:
		lbl_hours.text = str(data.get("hours_week", 0.0)) + " Std."
		
	if lbl_tasks:
		lbl_tasks.text = str(data.get("open_tasks", 0))
