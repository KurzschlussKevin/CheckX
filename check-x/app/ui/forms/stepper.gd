extends HBoxContainer
class_name Stepper

signal value_changed(value: int)

@export var label: String = "Label":
	set(v):
		label = v
		if is_node_ready():
			$Label.text = v

@export var value: int = 0:
	set(v):
		value = max(0, v)
		if is_node_ready():
			$Value.text = str(value)

func _ready() -> void:
	$Label.text = label
	$Value.text = str(value)
	$Minus.pressed.connect(func():
		value -= 1
		emit_signal("value_changed", value)
	)
	$Plus.pressed.connect(func():
		value += 1
		emit_signal("value_changed", value)
	)
