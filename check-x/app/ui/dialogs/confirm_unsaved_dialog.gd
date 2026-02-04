extends AcceptDialog
class_name ConfirmUnsavedDialog

var _on_save: Callable
var _on_discard: Callable
var _on_cancel: Callable

func _ready() -> void:
	%SaveBtn.pressed.connect(func():
		hide()
		if _on_save: _on_save.call()
	)
	%DiscardBtn.pressed.connect(func():
		hide()
		if _on_discard: _on_discard.call()
	)
	%CancelBtn.pressed.connect(func():
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
