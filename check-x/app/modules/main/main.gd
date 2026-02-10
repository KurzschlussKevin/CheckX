extends Control

@onready var module_container = %ModuleContainer
@onready var user_name_label = %UserLabel
@onready var layout = $Layout

func _ready() -> void:
	# 1. Fenster maximieren
	get_window().mode = Window.MODE_MAXIMIZED
	
	# 2. Sanftes Erscheinen der UI
	layout.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(layout, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	
	# 3. Platzhalter für Nutzerdaten
	user_name_label.text = "Administrator"
	
	print("Main Framework erfolgreich initialisiert.")

func load_module(path: String) -> void:
	for child in module_container.get_children():
		child.queue_free()
	
	var scene = load(path)
	if scene:
		var instance = scene.instantiate()
		module_container.add_child(instance)
		
		# Modul-Wechsel Animation
		instance.modulate.a = 0
		var t = create_tween()
		t.tween_property(instance, "modulate:a", 1.0, 0.4)
