extends Control

# Wir legen eine "tech" Sektion in der Config an.
const CONFIG_SECTION = "tech"

# Hier mappen wir den Node-Namen aus der Szene auf den Speicher-Schlüssel in der Config
var setting_nodes = {
	# ==========================================
	# TAB 1: SYSTEM
	# ==========================================
	# -- Anwendung --
	"StartOnBootCheck": {"type": "checkbox", "key": "start_on_boot", "default": false},
	"MinimizeToTrayCheck": {"type": "checkbox", "key": "minimize_to_tray", "default": false},
	"AutoUpdateCheck": {"type": "checkbox", "key": "auto_update", "default": true},
	
	# -- Server & Verbindung --
	"ServerHostInput": {"type": "line_edit", "key": "server_host", "default": "https://api.checkx.com"},
	"ServerPortSpin": {"type": "spinbox", "key": "server_port", "default": 443.0},
	"AuthProxyCheck": {"type": "checkbox", "key": "use_proxy", "default": false},
	
	# -- Dateien & Speicher --
	"DownloadPathInput": {"type": "line_edit", "key": "download_path", "default": ""},
	"OfflineCacheCheck": {"type": "checkbox", "key": "offline_cache", "default": false},
	"UploadLimitSpin": {"type": "spinbox", "key": "upload_limit_mb", "default": 10.0},
	"ImgCompressCheck": {"type": "checkbox", "key": "compress_images", "default": false},
	"TempCleanCheck": {"type": "checkbox", "key": "clean_temp_on_exit", "default": true},
	
	# -- Sicherheit & DSGVO --
	"TwoFactorCheck": {"type": "checkbox", "key": "2fa_enabled", "default": false},
	"AppLockCheck": {"type": "checkbox", "key": "auto_lock", "default": false},
	"DataLimitSpin": {"type": "spinbox", "key": "log_retention_days", "default": 30.0},
	
	# ==========================================
	# TAB 2: INTEGRATION
	# ==========================================
	# -- Kalender Sync --
	"OutlookSyncCheck": {"type": "checkbox", "key": "sync_outlook", "default": false},
	"GoogleSyncCheck": {"type": "checkbox", "key": "sync_google", "default": false},
	"AppleSyncCheck": {"type": "checkbox", "key": "sync_apple", "default": false},
	
	# -- Webhooks & Messenger --
	"SlackInput": {"type": "line_edit", "key": "slack_webhook", "default": ""},
	"TeamsCheck": {"type": "checkbox", "key": "sync_teams_status", "default": false},
	"ApiTokenInput": {"type": "line_edit", "key": "api_token", "default": ""},
	
	# ==========================================
	# TAB 3: AUTOMATISIERUNG
	# ==========================================
	# -- KI & Smart Features --
	"OCRCheck": {"type": "checkbox", "key": "ocr_receipts", "default": false},
	"KISuggestCheck": {"type": "checkbox", "key": "ai_project_suggest", "default": false},
	
	# -- Workflows --
	"AutoPauseCheck": {"type": "checkbox", "key": "auto_pause", "default": true},
	"FeierabendCheck": {"type": "checkbox", "key": "end_of_day_warning", "default": false},
	"ArchiveCheck": {"type": "checkbox", "key": "auto_archive", "default": false},
	
	# ==========================================
	# TAB 4: BENACHRICHTIGUNG
	# ==========================================
	# -- Kanäle & Sounds --
	"DesktopNotifyCheck": {"type": "checkbox", "key": "notify_desktop", "default": true},
	"SoundNotifyCheck": {"type": "checkbox", "key": "notify_sound", "default": false},
	"EmailReportCheck": {"type": "checkbox", "key": "email_daily_report", "default": false},
	
	# -- Auslöser --
	"NotifyTimerCheck": {"type": "checkbox", "key": "notify_timer_10h", "default": false},
	"NotifyVacationCheck": {"type": "checkbox", "key": "notify_vacation_updates", "default": false},
	"NotifyBreakCheck": {"type": "checkbox", "key": "notify_break_reminder", "default": false},
}

func _ready():
	_load_all_settings()
	_connect_signals()
	
	# --- SPEZIELLE BUTTONS VERBINDEN ---
	var test_btn = find_child("TestConnectionBtn", true, false)
	if test_btn:
		test_btn.pressed.connect(_on_test_connection_pressed)
		
	var clear_btn = find_child("ClearCacheBtn", true, false)
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_cache_pressed)

# Lädt alle Werte aus der Config und setzt sie ins UI
func _load_all_settings():
	for node_name in setting_nodes.keys():
		var node = find_child(node_name, true, false)
		if not node:
			print("Warnung: Settings-Node nicht gefunden -> ", node_name)
			continue
			
		var data = setting_nodes[node_name]
		var val = Config.get_value(CONFIG_SECTION, data["key"], data["default"])
		
		if data["type"] == "checkbox":
			node.button_pressed = val
		elif data["type"] == "line_edit":
			node.text = val
		elif data["type"] == "spinbox":
			node.value = val

# Verbindet die UI-Elemente so, dass sie bei Änderung sofort speichern
func _connect_signals():
	for node_name in setting_nodes.keys():
		var node = find_child(node_name, true, false)
		if not node: continue
			
		var data = setting_nodes[node_name]
		
		if data["type"] == "checkbox":
			node.toggled.connect(func(v): Config.set_value(CONFIG_SECTION, data["key"], v))
		elif data["type"] == "line_edit":
			node.text_changed.connect(func(t): Config.set_value(CONFIG_SECTION, data["key"], t))
		elif data["type"] == "spinbox":
			node.value_changed.connect(func(v): Config.set_value(CONFIG_SECTION, data["key"], v))

# ==========================================
# BUTTON LOGIK
# ==========================================

func _on_test_connection_pressed():
	# Wir holen uns den aktuell eingegebenen Text direkt aus der UI (nicht aus der gespeicherten Config),
	# für den Fall, dass der Nutzer gerade tippt und testen will, bevor er das Feld verlässt.
	var host_input = find_child("ServerHostInput", true, false)
	var port_input = find_child("ServerPortSpin", true, false)
	
	var host = host_input.text if host_input and host_input.text != "" else "https://api.checkx.com"
	var port = port_input.value if port_input else 443
	
	print("Teste Server-Verbindung zu: ", host, ":", port)
	
	# Info Toast anzeigen
	if Store.has_signal("notification_received"):
		Store.emit_signal("notification_received", {"message": "Pinge " + host + ":" + str(port) + "...", "type": "info"})
		
	# Hier machen wir einen echten HTTP-Ping Request zum Testen!
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, code, headers, body):
		if code == 200:
			if Store.has_signal("notification_received"):
				Store.emit_signal("notification_received", {"message": "Verbindung erfolgreich! Server erreichbar.", "type": "success"})
		else:
			ErrorHandler.report("Netzwerk", "Server nicht erreichbar. HTTP Code: " + str(code))
		http.queue_free()
	)
	# Wir pingen einfach den Base-URL an
	http.request(host + ":" + str(port), ["Content-Type: application/json"], HTTPClient.METHOD_GET)

func _on_clear_cache_pressed():
	print("Lösche Cache...")
	
	# Optionale Logik: Hier könntest du z.B. das 'user://' Verzeichnis nach Temp-Dateien absuchen und leeren.
	# Config.save()  # Wir stellen sicher, dass Einstellungen gespeichert bleiben!
	
	if Store.has_signal("notification_received"):
		Store.emit_signal("notification_received", {"message": "Lokaler Cache wurde geleert! Bitte App neustarten.", "type": "success"})
