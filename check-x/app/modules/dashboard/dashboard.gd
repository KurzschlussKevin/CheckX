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

# NEU: Optionaler GridContainer für die Spalten-Option ("column_mode")
@onready var dashboard_grid = find_child("GridContainer", true, false)

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
	
	# Zugriff auf das neue User-Objekt im Store
	var user_data = Store.current_user 
	
	if welcome_label:
		if user_data and user_data.has("name"):
			welcome_label.text = "Willkommen, " + str(user_data["name"])
		else:
			welcome_label.text = "Willkommen, Gast"
	
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
	
	# Initial die Sichtbarkeit und das Layout anwenden
	_apply_visibility()
	_apply_layout()
	
	fetch_stats()

func _setup_labels():
	# Präzisere Suche für die Labels innerhalb ihrer Karten
	if card_revenue: lbl_revenue = card_revenue.find_child("Value", true, false)
	if card_hours: lbl_hours = card_hours.find_child("Value", true, false)
	if card_tasks: lbl_tasks = card_tasks.find_child("Value", true, false)

# Timer-Logik aufbauen
func _setup_refresh_timer():
	refresh_timer = Timer.new()
	refresh_timer.name = "DashboardRefreshTimer"
	add_child(refresh_timer)
	refresh_timer.timeout.connect(fetch_stats)
	
	# Start-Intervall aus Config laden (In config.gd ist der Schlüssel "refresh_rate", nicht "refresh_interval")
	var saved_interval = Config.get_value("dashboard", "refresh_rate", 30)
	_update_refresh_interval(saved_interval)

# Funktion zum Ändern des Intervalls (30s bis 600s/10min)
func _update_refresh_interval(seconds: int):
	if refresh_timer:
		refresh_timer.wait_time = clamp(seconds, 30, 600) # Sicherstellen des Bereichs
		refresh_timer.start()
		print("Dashboard-Refresh auf " + str(refresh_timer.wait_time) + " Sekunden gesetzt.")

# Reagiert auf Änderungen in den Einstellungen (Wird aus settings_personal.gd getriggert)
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

# Steuert die Sichtbarkeit der einzelnen Dashboard-Module
func _apply_visibility():
	if welcome_box:
		welcome_box.visible = Config.get_value("dashboard", "show_welcome", true)
	
	if card_revenue:
		card_revenue.visible = Config.get_value("dashboard", "show_revenue", true)
		
	if card_hours:
		card_hours.visible = Config.get_value("dashboard", "show_employees", true)
		
	if card_tasks:
		card_tasks.visible = Config.get_value("dashboard", "show_tasks", true)

# NEU: Steuert das Layout der Kacheln (Automatisch vs. 3 Spalten)
func _apply_layout():
	var col_mode = Config.get_value("dashboard", "column_mode", 0)
	
	if dashboard_grid:
		if col_mode == 1:
			# 1 = 3 Spalten Fest
			dashboard_grid.columns = 3
		else:
			# 0 = Automatisch
			# Hier könntest du bei einem GridContainer z.B. columns = 2 setzen
			# oder wenn du eine andere Logik für "Automatisch" nutzt, diese hier einbauen.
			dashboard_grid.columns = 2 

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
