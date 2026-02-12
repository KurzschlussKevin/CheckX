extends PanelContainer

signal request_manual(date)
var date = {"month": 1, "year": 2024}
var uid = ""
var sel_date = ""

func _ready():
	date = Time.get_date_dict_from_system()
	%PrevBtn.pressed.connect(func(): _nav(-1))
	%NextBtn.pressed.connect(func(): _nav(1))
	%AddBtn.pressed.connect(func(): emit_signal("request_manual", sel_date))

func setup(user_id):
	uid = user_id
	refresh()

func refresh():
	%HistoryBox.visible = true
	%DetailBox.visible = false
	_update_cal()
	_update_hist()

func _nav(d):
	date.month += d
	if date.month > 12:
		date.month = 1
		date.year += 1
	elif date.month < 1:
		date.month = 12
		date.year -= 1
	refresh()

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
		
		if Store.get_entries_for_date(uid, ds).size() > 0:
			btn.modulate = Color(0.2, 0.8, 0.4)
		else: btn.modulate = Color(1,1,1,0.5)
		
		btn.pressed.connect(func(): _click(ds))
		%Grid.add_child(btn)

func _update_hist():
	for c in %List.get_children(): c.queue_free()
	var entries = Store.get_entries_by_employee(uid)
	var count = 0
	for i in range(entries.size()-1, -1, -1):
		if count >= 3: break
		var l = Label.new()
		l.text = "• " + entries[i].project
		%List.add_child(l)
		count += 1

func _click(ds):
	sel_date = ds
	%HistoryBox.visible = false
	%DetailBox.visible = true
	%DetailLabel.text = ds
	for c in %EntryList.get_children(): c.queue_free()
	for e in Store.get_entries_for_date(uid, ds):
		var l = Label.new()
		l.text = e.project + " (" + str(int(e.duration/60)) + " min)"
		%EntryList.add_child(l)

func _get_days(m, y):
	if m in [1,3,5,7,8,10,12]: return 31
	elif m in [4,6,9,11]: return 30
	return 29 if (y%4==0 and y%100!=0) or y%400==0 else 28
