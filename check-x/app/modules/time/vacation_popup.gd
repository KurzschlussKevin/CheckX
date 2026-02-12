extends Control

var date = {"month": 1, "year": 2024}
var start = ""
var end = ""
var uid = ""

signal requested

func _ready():
	date = Time.get_date_dict_from_system()
	_update_cal()
	%PrevBtn.pressed.connect(func(): _nav(-1))
	%NextBtn.pressed.connect(func(): _nav(1))
	%CancelBtn.pressed.connect(func(): visible = false)
	%SaveBtn.pressed.connect(_save)

func open(user_id):
	uid = user_id
	start = ""
	end = ""
	%Info.text = "Startdatum wählen..."
	visible = true
	_update_cal()

func _nav(d):
	date.month += d
	if date.month > 12:
		date.month = 1
		date.year += 1
	elif date.month < 1:
		date.month = 12
		date.year -= 1
	_update_cal()

func _update_cal():
	for c in %Grid.get_children(): c.queue_free()
	var months = ["", "JAN", "FEB", "MÄR", "APR", "MAI", "JUN", "JUL", "AUG", "SEP", "OKT", "NOV", "DEZ"]
	%MonthLabel.text = "%s %d" % [months[date.month], date.year]
	
	var days = _get_days(date.month, date.year)
	for d in range(1, days + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(35, 35)
		btn.text = str(d)
		var ds = "%d-%02d-%02d" % [date.year, date.month, d]
		
		if ds == start or ds == end: btn.modulate = Color(0.3, 0.7, 1)
		elif start != "" and end != "" and ds > start and ds < end: btn.modulate = Color(0.3, 0.7, 1, 0.5)
		else: btn.modulate = Color(1,1,1,0.5)
		
		btn.pressed.connect(func(): _click(ds))
		%Grid.add_child(btn)

func _click(ds):
	if start == "":
		start = ds
		%Info.text = "Ende wählen..."
	elif end == "":
		if ds < start:
			end = start
			start = ds
		else: end = ds
		%Info.text = start + " bis " + end
	else:
		start = ds
		end = ""
		%Info.text = "Neuer Start: " + ds
	_update_cal()

func _save():
	if start != "" and end != "":
		Store.request_vacation(uid, start, end, "Erholung")
		visible = false
		emit_signal("requested")

func _get_days(m, y):
	if m in [1,3,5,7,8,10,12]: return 31
	elif m in [4,6,9,11]: return 30
	return 29 if (y%4==0 and y%100!=0) or y%400==0 else 28
