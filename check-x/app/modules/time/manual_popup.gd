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
	
	# Initial alles aktivieren
	%SaveBtn.disabled = false
	%ProjectInput.editable = true
	%TimeInput.editable = true
	%SaveBtn.text = "Speichern"
	
	# Sperrstatus prüfen
	Store.is_day_locked(uid, date_str, func(is_locked):
		if is_locked:
			%DateInfo.text = "Datum: " + date_str + " (GESPERRT)"
			%DateInfo.modulate = Color.RED
			%SaveBtn.disabled = true
			%SaveBtn.text = "Vom Admin bestätigt"
			%ProjectInput.editable = false
			%TimeInput.editable = false
			# Hier könnte man einen Button "Korrektur beantragen" einblenden
		else:
			%DateInfo.modulate = Color.WHITE
	)
	
	%ProjectInput.text = ""
	%TimeInput.value = 0
	visible = true

func _save():
	var mins = int(%TimeInput.value)
	if mins > 0:
		Store.add_manual_entry(user_id, target_date, mins, %ProjectInput.text, "Manuell")
		visible = false
		emit_signal("entry_saved")
