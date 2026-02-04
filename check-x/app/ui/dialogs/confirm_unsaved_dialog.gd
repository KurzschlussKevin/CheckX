extends AcceptDialog
class_name ConfirmUnsavedDialog

var _on_save: Callable
var _on_discard: Callable
var _on_cancel: Callable

# Wir nutzen hier @onready, um sicherzustellen, dass die Nodes geladen sind
@onready var save_btn: Button = $HBox/SaveBtn
@onready var discard_btn: Button = $HBox/DiscardBtn
@onready var cancel_btn: Button = $HBox/CancelBtn

func _ready() -> void:
	save_btn.pressed.connect(func():
		hide()
		if _on_save: _on_save.call()
	)
	discard_btn.pressed.connect(func():
		hide()
		if _on_discard: _on_discard.call()
	)
	cancel_btn.pressed.connect(func():
		hide()
		if _on_cancel: _on_cancel.call()
	)

func open(t: String, text: String, on_save: Callable, on_discard: Callable, on_cancel: Callable) -> void:
	title = t
	dialog_text = text
	_on_save = on_save
	_on_discard = on_discard
	_on_cancel = on_cancel
	popup_centered(Vector2i(640, 220))
