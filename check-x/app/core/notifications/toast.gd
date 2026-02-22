extends Control

@onready var panel = %Panel
@onready var title_label = %Title
@onready var message_label = %Message
@onready var icon_rect = %Icon

# Konfiguration der Farben basierend auf dem Typ
var type_colors = {
	"vacation": Color("2ecc71"),    # Grün für Urlaub (Genehmigt)
	"correction": Color("e74c3c"),  # Rot für Korrekturanfragen
	"info": Color("3498db")         # Blau für allgemeine Infos
}

func _ready() -> void:
	# Initial unsichtbar für die Animation
	modulate.a = 0
	# Start-Position etwas weiter rechts für "Einfliegen"
	position.x += 50

func display(message: String, type: String = "info") -> void:
	# Text setzen
	message_label.text = message
	
	# Titel und Farbe anpassen
	var bg_color = type_colors.get(type, type_colors["info"])
	match type:
		"vacation":
			title_label.text = "URLAUBS-UPDATE"
		"correction":
			title_label.text = "KORREKTUR ERFORDERLICH"
		"info":
			title_label.text = "SYSTEM-INFO"
	
	# Hintergrundfarbe des Panels anpassen (StyleBox-Override)
	var new_style = panel.get_theme_stylebox("panel").duplicate()
	if new_style is StyleBoxFlat:
		new_style.bg_color = bg_color
		# Optional: Randfarbe etwas dunkler
		new_style.border_color = bg_color.darkened(0.2)
		panel.add_theme_stylebox_override("panel", new_style)
	
	# Animation starten
	_animate_toast()

func _animate_toast() -> void:
	var tween = create_tween().set_parallel(true)
	
	# 1. Einblenden und Einfliegen
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:x", position.x - 50, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 2. Warten und dann Ausblenden
	await get_tree().create_timer(5.0).timeout
	
	var fade_out = create_tween().set_parallel(true)
	fade_out.tween_property(self, "modulate:a", 0.0, 0.5)
	fade_out.tween_property(self, "position:y", position.y - 20, 0.5)
	
	# 3. Objekt entfernen
	fade_out.chain().tween_callback(queue_free)
