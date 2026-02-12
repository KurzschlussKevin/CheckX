extends Control

signal entry_saved 
var target_date = ""
var user_id = ""

func _ready():
	%CancelBtn.pressed.connect(func(): visible = false)
	%SaveBtn.pressed.connect(_save)

func open(uid, date_str):
	user_id = uid
	target_date = date_str
	%DateInfo.text = "Datum: " + date_str
	%ProjectInput.text = ""
	%TimeInput.value = 0
	visible = true

func _save():
	var mins = int(%TimeInput.value)
	if mins > 0:
		Store.add_manual_entry(user_id, target_date, mins, %ProjectInput.text, "Manuell")
		visible = false
		emit_signal("entry_saved")
