extends Control

# Direkte Pfade statt Unique Names für maximale Stabilität
@onready var main_layout = $MainLayout
@onready var module_container = $MainLayout/ContentLayout/ModuleContainer
@onready var page_title = $MainLayout/ContentLayout/TopBar/Margin/HBox/PageTitle
@onready var nav_container = $MainLayout/Sidebar/Margin/VBox/NavButtons
@onready var user_name_label = %UserName

# Vorlage für die Buttons laden
var nav_button_scene = preload("res://app/modules/main/nav_button.tscn")

# Liste der Module und ihrer Pfade
var modules = {
	"Dashboard": "res://app/modules/dashboard/dashboard.tscn",
	"Zeiterfassung": "res://app/modules/time/time_tracking_new.tscn",
	"Team-Urlaub": "res://app/modules/team_calendar/team_calendar.tscn",
	"Leistung": "res://app/modules/performance/performance.tscn",
	"Mitarbeiter": "res://app/modules/employees/employees.tscn",
	"Einstellungen": "res://app/modules/settings_profile/settings.tscn",
	"Admin-Panel": "res://app/modules/admin/admin_panel.tscn"
}

func _ready() -> void:
	# 1. FENSTER MAXIMIEREN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	
	# Benutzername in der TopBar anzeigen
	if user_name_label:
		user_name_label.text = Store.current_user.get("name", "Gast")
	
	# Sicherheits-Check: Existiert der Container für die Buttons?
	if nav_container == null:
		printerr("Fehler: NavButtons Container nicht gefunden!")
		return
	
	# 2. Sidebar mit Buttons füllen (inkl. Rollenprüfung)
	_setup_sidebar()
	
	# 3. Das Dashboard als Startseite laden
	load_module(modules["Dashboard"], "Dashboard")
	
	# 4. Sanftes Einblenden der UI
	main_layout.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(main_layout, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	
	# --- NEU: ERROR-HANDLER VERBINDEN ---
	# Wir verbinden das Signal vom Autoload-Singleton 'ErrorHandler'
	if ErrorHandler.has_signal("show_error_dialog"):
		ErrorHandler.show_error_dialog.connect(_on_error_reported)
	
	# Verbindung für den Bestätigungs-Button im Popup (%BugReportPopup)
	if has_node("%BugReportPopup"):
		%BugReportPopup.confirmed.connect(_on_send_bug_confirmed)

func _setup_sidebar() -> void:
	# Alle alten Kinder im Container löschen
	for child in nav_container.get_children():
		child.queue_free()
	
	# Aktuelle Rolle aus dem Store abrufen
	var user_role = Store.current_user.get("role", "Prüfer")
	
	# Für jeden Eintrag in 'modules' einen Button erstellen
	for module_name in modules:
		# ADMIN-CHECK: Das Admin-Panel nur anzeigen, wenn die Rolle 'Admin' ist
		if module_name == "Admin-Panel" and user_role != "Admin":
			continue
			
		var btn = nav_button_scene.instantiate()
		btn.text = "  " + module_name
		
		# Verbindet den Klick auf den Button mit der Lade-Funktion
		btn.pressed.connect(func(): load_module(modules[module_name], module_name))
		
		nav_container.add_child(btn)

func load_module(path: String, title: String = "") -> void:
	if title != "" and page_title:
		page_title.text = title.to_upper()
	
	if not module_container: return
	
	# Aktuelles Modul entfernen
	for child in module_container.get_children():
		child.queue_free()
	
	# Neue Szene laden und instanziieren
	if ResourceLoader.exists(path):
		var scene = load(path)
		var instance = scene.instantiate()
		module_container.add_child(instance)
		
		# Einblend-Animation für das Modul
		instance.modulate.a = 0
		var t = create_tween()
		t.tween_property(instance, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	else:
		# Falls eine Datei fehlt, melden wir das jetzt automatisch an dein neues System
		var err_msg = "Szenen-Datei fehlt oder Pfad ungültig: " + path
		print(err_msg)
		ErrorHandler.report("System / Navigation", err_msg)

# --- NEU: BUG-REPORTING LOGIK ---

# Diese Funktion wird aufgerufen, sobald irgendwo ErrorHandler.report(...) getriggert wird
func _on_error_reported(module_name: String, error_msg: String) -> void:
	# 1. Wir suchen zuerst das Popup
	if has_node("%BugReportPopup"):
		var popup = %BugReportPopup
		
		popup.title = "SYSTEM-FEHLER: " + module_name.to_upper()
		popup.dialog_text = "Ein technisches Problem ist aufgetreten. Der Fehler wurde unten eingetragen:"
		
		# 2. Wir suchen das Eingabefeld INNERHALB des Popups
		# Wir nutzen get_node_or_null auf dem Popup-Objekt selbst
		var input_field = popup.find_child("BugNoteInput", true, false)
		
		# Alternativ, falls du den Unique Name im Popup-Skript hast:
		# var input_field = popup.get_node("%BugNoteInput")
		
		var tech_info = "--- AUTOMATISCHER FEHLERBERICHT ---\n"
		tech_info += "MODUL: " + module_name + "\n"
		tech_info += "FEHLER: " + error_msg + "\n"
		tech_info += "-----------------------------------\n\n"
		
		if input_field:
			input_field.text = tech_info
			if input_field.has_method("set_caret_line"):
				input_field.set_caret_line(input_field.get_line_count())
		else:
			# Falls find_child nicht klappt, versuchen wir es über den direkten Pfad
			# (Passe den Pfad hier an, wenn deine VBox anders heißt)
			input_field = popup.get_node_or_null("VBox/BugNoteInput")
			if input_field:
				input_field.text = tech_info

		# 3. Jetzt das Fenster öffnen
		popup.popup_centered()

# Wird ausgeführt, wenn der User im Popup auf 'Bug Bericht senden' klickt
func _on_send_bug_confirmed() -> void:
	var user_note = ""
	if has_node("%BugNoteInput"):
		user_note = %BugNoteInput.text
	
	# Finales Absenden über das ErrorHandler-Modul an das Backend
	ErrorHandler.send_report_to_server(user_note)
	print("Bug-Report wurde durch Benutzer bestätigt.")
