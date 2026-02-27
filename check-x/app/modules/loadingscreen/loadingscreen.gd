extends Control

@onready var progress_bar = %ProgressBar
@onready var loading_label = %LoadingLabel
@onready var status_label = %StatusLabel
@onready var percent_label = %PercentLabel
@onready var data_particles = $DataParticles
@onready var background = $Background

# Pfad zu deiner Hauptszene nach dem Login
var target_scene_path = "res://app/modules/main/main.tscn"
var progress = []
var display_progress = 0.0

func _ready() -> void:
	var reduced_motion = Config.get_value("general", "reduced_motion", false)
	
	# 1. Alles initial verstecken für Fade-in
	if reduced_motion:
		modulate.a = 1.0
	else:
		modulate.a = 0
		var f_tween = create_tween()
		f_tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	# 2. Fenster-Morphing von klein auf 1080p starten
	_morph_window_to_full()
	
	# 3. Hintergrund-Pulsieren starten
	_start_bg_pulse()
	
	# 4. Hintergrund-Laden der nächsten Szene anfordern
	ResourceLoader.load_threaded_request(target_scene_path)
	_update_status_texts()

func _process(delta: float) -> void:
	# Lade-Status abfragen
	var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	
	# Fortschritt weich interpolieren (kein Springen)
	display_progress = lerp(display_progress, float(progress[0] * 100), 4 * delta)
	progress_bar.value = display_progress
	percent_label.text = str(int(display_progress)) + "%"
	
	# Hintergrund-Partikel beschleunigen sich bei steigendem Fortschritt
	data_particles.speed_scale = 1.0 + (display_progress / 33.0) 
	
	# Wenn fertig geladen (und Balken optisch bei 100%)
	if status == ResourceLoader.THREAD_LOAD_LOADED and display_progress > 99.5:
		set_process(false)
		_finish_loading()

func _start_bg_pulse() -> void:
	var reduced_motion = Config.get_value("general", "reduced_motion", false)
	
	if reduced_motion:
		# Wenn Animationen reduziert sind, einfach hell lassen und stoppen
		background.self_modulate = Color(1, 1, 1, 1.0)
		return
		
	# Lässt den Hintergrund dezent hell und dunkel werden (Atmen)
	var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(background, "self_modulate", Color(1, 1, 1, 0.6), 2.5)
	tween.tween_property(background, "self_modulate", Color(1, 1, 1, 1.0), 2.5)

func _update_status_texts() -> void:
	# Liste mit Enterprise-Statusmeldungen
	var texts = [
		"Initialisiere Enterprise-Module...",
		"Synchronisiere Cloud-Datenbank...",
		"Sichere API-Verbindung...",
		"Lade Benutzer-Voreinstellungen...",
		"Bereite Dashboard-Interface vor..."
	]
	
	if is_inside_tree() and display_progress < 100:
		var reduced_motion = Config.get_value("general", "reduced_motion", false)
		
		if reduced_motion:
			# Text sofort ohne Fade-In/Out umschalten
			status_label.text = texts.pick_random()
		else:
			var t = create_tween()
			t.tween_property(status_label, "modulate:a", 0.0, 0.25)
			t.set_trans(Tween.TRANS_LINEAR)
			t.tween_callback(func(): status_label.text = texts.pick_random())
			t.tween_property(status_label, "modulate:a", 1.0, 0.25)
		
		# Alle 1.5 Sekunden Text wechseln
		await get_tree().create_timer(1.5).timeout
		_update_status_texts()

func _morph_window_to_full() -> void:
	var win = get_window()
	var target_res = Vector2i(1920, 1080)
	
	# Zentrum berechnen
	var screen_rect = DisplayServer.screen_get_usable_rect(win.current_screen)
	var center_pos = Vector2(screen_rect.position) + (Vector2(screen_rect.size) / 2.0) - (Vector2(target_res) / 2.0)
	
	var reduced_motion = Config.get_value("general", "reduced_motion", false)
	
	if reduced_motion:
		# Sofortiges Vergrößern und Zentrieren, kein sanftes Skalieren
		win.size = target_res
		win.content_scale_size = target_res
		win.position = Vector2i(center_pos)
	else:
		# Physikalische Transformation des Betriebssystem-Fensters
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(win, "size", target_res, 0.8)
		tween.tween_property(win, "content_scale_size", target_res, 0.8)
		tween.tween_property(win, "position", Vector2i(center_pos), 0.8)

func _finish_loading() -> void:
	# Letzte Anzeige vor dem Wechsel
	percent_label.text = "100%"
	progress_bar.value = 100
	loading_label.text = "SYSTEM BEREIT"
	status_label.text = "Starte Module..."
	
	var reduced_motion = Config.get_value("general", "reduced_motion", false)
	
	if not reduced_motion:
		# Sanftes Ausblenden des gesamten Ladescreens nur wenn Animationen aktiv sind
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
		await tween.finished
	
	# Szene wechseln
	var packed_scene = ResourceLoader.load_threaded_get(target_scene_path)
	get_tree().change_scene_to_packed(packed_scene)
