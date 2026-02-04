extends PanelContainer
class_name StatCard

@export var title: String = "Title":
	set(v):
		title = v
		if is_node_ready(): %Title.text = v

@export var value_text: String = "0":
	set(v):
		value_text = v
		if is_node_ready(): %Value.text = v

@export var hint: String = "":
	set(v):
		hint = v
		if is_node_ready(): %Hint.text = v

func _ready() -> void:
	%Title.text = title
	%Value.text = value_text
	%Hint.text = hint
