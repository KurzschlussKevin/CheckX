extends Control

# Direkte Pfade statt Unique Names für maximale Stabilität
@onready var main_layout = $MainLayout
@onready var module_container = $MainLayout/ContentLayout/ModuleContainer
@onready var page_title = $MainLayout/ContentLayout/TopBar/Margin/HBox/PageTitle
@onready var nav_container = $MainLayout/Sidebar/Margin/VBox/NavButtons
@onready var user_name_label = %UserName

# Vorlagen laden
var nav_button_scene = preload("res://app/modules/main/nav_button.tscn")
var toast_scene = preload("res://app/core/notifications/toast.tscn") # NEU: Toast-Szene laden

# NEU: HTTP-Requests für den Hintergrund-Download der PDF-Vorlagen
var timesheet_http: HTTPRequest
var invoice_http: HTTPRequest

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
	# --- NEU: Standard-Beenden abfangen für Auto-Stop ---
	get_tree().set_auto_accept_quit(false) 
	
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
	
	# 4. Einblenden der UI (mit Rücksicht auf reduzierte Animationen)
	var reduced_motion = Config.get_value("general", "reduced_motion", false)
	if reduced_motion:
		main_layout.modulate.a = 1.0 # Sofort sichtbar
	else:
		main_layout.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(main_layout, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	
	# --- NEU: VORLAGEN IM HINTERGRUND HERUNTERLADEN ---
	_download_latest_templates()
	
	# --- SIGNALE VERBINDEN ---
	
	# Benachrichtigungs-System vom Store verbinden
	if Store.has_signal("notification_received"):
		Store.notification_received.connect(_on_notification_received)
	
	# Notification Button (Glocke) verbinden
	if has_node("%NotificationBtn"):
		%NotificationBtn.pressed.connect(_on_notification_list_requested)
	
	# Error-Handler vom Autoload-Singleton 'ErrorHandler'
	if ErrorHandler.has_signal("show_error_dialog"):
		ErrorHandler.show_error_dialog.connect(_on_error_reported)
	
	# Verbindung für den Bestätigungs-Button im Popup (%BugReportPopup)
	if has_node("%BugReportPopup"):
		%BugReportPopup.confirmed.connect(_on_send_bug_confirmed)


# --- NEU: VORLAGEN DOWNLOAD ---
func _download_latest_templates() -> void:
	var token = Store.token if "token" in Store else ""
	var headers = ["Authorization: Bearer " + token]
	
	# Stundenzettel Download
	timesheet_http = HTTPRequest.new()
	add_child(timesheet_http)
	# Speichert die Datei direkt ins lokale user-Verzeichnis
	timesheet_http.download_file = "user://timesheet_template.pdf"
	timesheet_http.request_completed.connect(_on_timesheet_downloaded)
	timesheet_http.request(Config.API_URL + "/templates/download_pdf/timesheet", headers, HTTPClient.METHOD_GET)
	
	# Rechnung Download
	invoice_http = HTTPRequest.new()
	add_child(invoice_http)
	invoice_http.download_file = "user://invoice_template.pdf"
	invoice_http.request_completed.connect(_on_invoice_downloaded)
	invoice_http.request(Config.API_URL + "/templates/download_pdf/invoice", headers, HTTPClient.METHOD_GET)

func _on_timesheet_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		print("✅ Aktuelle Stundenzettel-Vorlage vom Server geladen.")
		Config.set_value("business", "timesheet_template", "user://timesheet_template.pdf")
	else:
		print("ℹ️ Keine Stundenzettel-Vorlage auf dem Server gefunden. (Code: ", response_code, ")")
	timesheet_http.queue_free() # Aufräumen

func _on_invoice_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		print("✅ Aktuelle Rechnungs-Vorlage vom Server geladen.")
		Config.set_value("business", "invoice_template", "user://invoice_template.pdf")
	else:
		print("ℹ️ Keine Rechnungs-Vorlage auf dem Server gefunden. (Code: ", response_code, ")")
	invoice_http.queue_free() # Aufräumen


func _on_notification_received(data: Dictionary) -> void:
	# Toast instanziieren
	var toast = toast_scene.instantiate()
	add_child(toast)
	
	# Positionierung: Oben rechts mit etwas Abstand
	var screen_size = get_viewport_rect().size
	toast.position = Vector2(screen_size.x - toast.custom_minimum_size.x - 20, 20)
	
	# Nachricht und Typ (z.B. 'correction' oder 'vacation') übergeben
	if toast.has_method("display"):
		toast.display(data.get("message", ""), data.get("type", "info"))

func _on_notification_list_requested() -> void:
	Store.fetch_notification_history(func(history):
		_show_history_popup(history)
	)

# Verbessertes Popup Fenster mit Scroll-Ansicht für den Verlauf
func _show_history_popup(history: Array) -> void:
	# 1. Haupt-Dialog erstellen
	var dialog = AcceptDialog.new()
	dialog.title = "BENACHRICHTIGUNGS-ZENTRALE"
	
	dialog.size = Vector2(500, 400)
	
	# 2. Container-Struktur für Scrolling
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 10)
	
	# 3. Nachrichten-Elemente erzeugen
	if history.is_empty():
		var empty_label = Label.new()
		empty_label.text = "\nKeine Nachrichten vorhanden."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(empty_label)
	else:
		for n in history:
			var item_panel = PanelContainer.new()
			var item_style = StyleBoxFlat.new()
			item_style.bg_color = Color(0.15, 0.15, 0.18, 0.8)
			item_style.set_corner_radius_all(4)
			item_panel.add_theme_stylebox_override("panel", item_style)
			
			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_left", 12)
			margin.add_theme_constant_override("margin_top", 10)
			margin.add_theme_constant_override("margin_right", 12)
			margin.add_theme_constant_override("margin_bottom", 10)
			
			var vbox = VBoxContainer.new()
			
			var header = HBoxContainer.new()
			var type_label = Label.new()
			type_label.text = str(n.type).to_upper()
			type_label.add_theme_font_size_override("font_size", 11)
			type_label.modulate = Color(0.4, 0.6, 0.9)
			
			var status_label = Label.new()
			status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			status_label.text = "NEU" if not n.get("is_read", true) else ""
			status_label.modulate = Color(1, 0.8, 0.2)
			status_label.add_theme_font_size_override("font_size", 10)
			
			header.add_child(type_label)
			header.add_child(status_label)
			
			var content = Label.new()
			content.text = n.message
			content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_theme_font_size_override("font_size", 13)
			
			vbox.add_child(header)
			vbox.add_child(content)
			margin.add_child(vbox)
			item_panel.add_child(margin)
			list_container.add_child(item_panel)
	
	# 4. Zusammenbauen
	scroll.add_child(list_container)
	dialog.add_child(scroll)
	add_child(dialog)
	dialog.popup_centered()
	
	# Cleanup beim Schließen
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func(): dialog.queue_free())

# --- NAVIGATION & SIDEBAR ---

func _setup_sidebar() -> void:
	# 1. Alle alten Buttons entfernen
	for child in nav_container.get_children():
		child.queue_free()
	
	# 2. Kurze Sicherheitspause, damit der Store die Rolle sicher geladen hat
	if Store.token != "" and Store.current_user.is_empty():
		await get_tree().create_timer(0.1).timeout
	
	# 3. Aktuelle Rolle abrufen
	var user_role = "Prüfer" # Standardwert
	if Store.current_user.has("role"):
		user_role = Store.current_user["role"]
	
	print("Sidebar-Setup: Erkenne Rolle - ", user_role)
	
	# 4. Buttons basierend auf der Rolle erstellen
	for module_name in modules:
		# ADMIN-CHECK: Das Admin-Panel wird nur erstellt, wenn die Rolle 'Admin' ist
		if module_name == "Admin-Panel" and user_role != "Admin":
			continue
			
		var btn = nav_button_scene.instantiate()
		btn.text = "  " + module_name
		
		# Klick-Event verbinden
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
		var reduced_motion = Config.get_value("general", "reduced_motion", false)
		if reduced_motion:
			instance.modulate.a = 1.0 # Sofort einblenden
		else:
			instance.modulate.a = 0
			var t = create_tween()
			t.tween_property(instance, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	else:
		var err_msg = "Szenen-Datei fehlt oder Pfad ungültig: " + path
		print(err_msg)
		ErrorHandler.report("System / Navigation", err_msg)

# --- BUG-REPORTING LOGIK ---

func _on_error_reported(module_name: String, error_msg: String) -> void:
	if has_node("%BugReportPopup"):
		var popup = %BugReportPopup
		popup.title = "SYSTEM-FEHLER: " + module_name.to_upper()
		popup.dialog_text = "Ein technisches Problem ist aufgetreten. Der Fehler wurde unten eingetragen:"
		
		var input_field = popup.find_child("BugNoteInput", true, false)
		
		var tech_info = "--- AUTOMATISCHER FEHLERBERICHT ---\n"
		tech_info += "MODUL: " + module_name + "\n"
		tech_info += "FEHLER: " + error_msg + "\n"
		tech_info += "-----------------------------------\n\n"
		
		if input_field:
			input_field.text = tech_info
			if input_field.has_method("set_caret_line"):
				input_field.set_caret_line(input_field.get_line_count())
		else:
			input_field = popup.get_node_or_null("VBox/BugNoteInput")
			if input_field:
				input_field.text = tech_info

		popup.popup_centered()

func _on_send_bug_confirmed() -> void:
	var user_note = ""
	if has_node("%BugReportPopup"):
		# Wir greifen auf das Eingabefeld im Popup zu
		var input_field = %BugReportPopup.find_child("BugNoteInput", true, false)
		if input_field:
			user_note = input_field.text
	
	ErrorHandler.send_report_to_server(user_note)
	print("Bug-Report wurde durch Benutzer bestätigt.")

# --- NEU: FENSTER-SCHLIESSEN ABFANGEN ---
func _notification(what: int) -> void:
	# Wenn der User auf das "X" klickt oder Alt+F4 drückt
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_check_auto_stop_and_quit()

func _check_auto_stop_and_quit() -> void:
	var auto_stop = Config.get_value("business", "auto_stop_on_exit", false)
	var uid = Store.get_current_user_id() if Store.has_method("get_current_user_id") else Store.current_user.get("id", "")
	
	if auto_stop and uid != "" and Store.is_timer_running(uid):
		print("Auto-Stop aktiv! Timer wird vor dem Beenden gestoppt...")
		
		# 1. FENSTER UNSICHTBAR MACHEN (App wirkt für den User "geschlossen")
		get_window().hide()
		
		# 2. Pausen berechnen
		var start_time = Store.get_timer_start(uid)
		var dur_sec = Time.get_unix_time_from_system() - start_time
		var auto_enabled = Config.get_value("business", "auto_break_after_6h", true)
		var break_val = Config.get_value("business", "daily_break_minutes", 30)
		
		var break_min = 0
		if auto_enabled and (dur_sec / 3600.0) >= 6.0:
			break_min = int(break_val)
			
		# 3. Timer lokal und auf dem Server stoppen
		Store.stop_timer("", "Automatisch gestoppt (App-Ende)", break_min)
		
		# 4. SERVER GENUG ZEIT GEBEN! (2 Sekunden im Hintergrund warten)
		# Da das Fenster schon unsichtbar ist, merkt der Nutzer davon nichts.
		await get_tree().create_timer(2.0).timeout
		
		# 5. App jetzt endgültig beenden
		get_tree().quit()
	else:
		# Timer lief nicht oder Auto-Stop ist aus -> Sofort beenden
		get_tree().quit()
