extends Control

signal entry_saved

var user_id = ""
var target_date = ""

func open(uid, date_str):
	user_id = uid
	target_date = date_str
	
	if has_node("%DateInfo"):
		%DateInfo.text = "Datum: " + date_str
	
	# Initial alles aktivieren
	if has_node("%SaveBtn"): 
		%SaveBtn.disabled = false
		%SaveBtn.text = "Speichern"
	if has_node("%ProjectInput"): %ProjectInput.editable = true
	if has_node("%TimeInput"): %TimeInput.editable = true
	
	# SPERR-CHECK VOM SERVER
	Store.is_day_locked(uid, date_str, func(is_locked):
		if is_locked:
			if has_node("%DateInfo"):
				%DateInfo.text = date_str + " (GESPERRT)"
				%DateInfo.modulate = Color(1, 0.4, 0.4) # Rot markieren
			
			if has_node("%SaveBtn"):
				%SaveBtn.disabled = true
				%SaveBtn.text = "Gesperrt"
			
			if has_node("%ProjectInput"): %ProjectInput.editable = false
			if has_node("%TimeInput"): %TimeInput.editable = false
		else:
			if has_node("%DateInfo"): %DateInfo.modulate = Color.WHITE
	)
	
	if has_node("%ProjectInput"): %ProjectInput.text = ""
	if has_node("%TimeInput"): %TimeInput.value = 0
	visible = true

func _ready():
	if has_node("%SaveBtn"):
		%SaveBtn.pressed.connect(_on_save)
	if has_node("%CancelBtn"):
		%CancelBtn.pressed.connect(func(): visible = false)

func _on_save():
	var mins = 0
	var proj = ""
	if has_node("%TimeInput"): mins = int(%TimeInput.value)
	if has_node("%ProjectInput"): proj = %ProjectInput.text
	
	if mins > 0:
		Store.add_manual_entry(user_id, target_date, mins, proj)
		entry_saved.emit()
		visible = false
