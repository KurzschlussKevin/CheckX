extends Control

# Direkte Pfade statt Unique Names für maximale Stabilität
@onready var main_layout = $MainLayout
@onready var module_container = $MainLayout/ContentLayout/ModuleContainer
@onready var page_title = $MainLayout/ContentLayout/TopBar/Margin/HBox/PageTitle
# Pfad zur Sidebar-VBox, wo die Buttons landen sollen
@onready var nav_container = $MainLayout/Sidebar/Margin/VBox/NavButtons

# Vorlage für die Buttons laden
var nav_button_scene = preload("res://app/modules/main/nav_button.tscn")

# Liste der Module und ihrer Pfade
var modules = {
	"Dashboard": "res://app/modules/dashboard/dashboard.tscn",
	"Zeiterfassung": "res://app/modules/time/time_tracking_new.tscn",
	"Mitarbeiter": "res://app/modules/employees/employees.tscn",
	"Einstellungen": "res://app/modules/settings/settings.tscn"
}

func _ready() -> void:
	# 1. FENSTER MAXIMIEREN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	
	# Sicherheits-Check: Existiert der Container für die Buttons?
	if nav_container == null:
		printerr("Fehler: NavButtons Container wurde nicht gefunden! Prüfe den Pfad in main.gd.")
		return
	
	# 2. Sidebar mit Buttons füllen
	_setup_sidebar()
	
	# 3. Das Dashboard als Startseite laden
	load_module(modules["Dashboard"], "Dashboard")
	
	# 4. Sanftes Einblenden der UI
	main_layout.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(main_layout, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

func _setup_sidebar() -> void:
	# Alle alten Kinder im Container löschen
	for child in nav_container.get_children():
		child.queue_free()
	
	# Für jeden Eintrag in 'modules' einen Button erstellen
	for module_name in modules:
		var btn = nav_button_scene.instantiate()
		btn.text = "  " + module_name
		
		# Verbindet den Klick auf den Button mit der Lade-Funktion
		btn.pressed.connect(func(): load_module(modules[module_name], module_name))
		
		nav_container.add_child(btn)

func load_module(path: String, title: String = "") -> void:
	if title != "" and page_title:
		page_title.text = title.to_upper()
	
	if not module_container: return
	
	for child in module_container.get_children():
		child.queue_free()
	
	if ResourceLoader.exists(path):
		var scene = load(path)
		var instance = scene.instantiate()
		module_container.add_child(instance)
		
		instance.modulate.a = 0
		var t = create_tween()
		t.tween_property(instance, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	else:
		print("Hinweis: Szene existiert noch nicht: ", path)
