extends Control

var uid = "001"

func _ready():
	%DateLabel.text = Time.get_date_string_from_system()
	
	%CalendarPanel.setup(uid)
	%CalendarPanel.request_manual.connect(func(d): %ManualPopup.open(uid, d))
	%ManualPopup.entry_saved.connect(func(): %CalendarPanel.refresh())
	%VacationPopup.requested.connect(func(): 
		%VacBtn.text = "Beantragt!"
		await get_tree().create_timer(1).timeout
		%VacBtn.text = "Urlaub"
	)
	
	%VacBtn.pressed.connect(func(): %VacationPopup.open(uid))
	%PdfBtn.pressed.connect(_export_pdf)
	%StartBtn.pressed.connect(_toggle_timer)

func _toggle_timer():
	if Store.is_timer_running(uid):
		Store.stop_timer(uid, %ProjectInput.text)
		%StartBtn.text = "START"
		%CalendarPanel.refresh()
	else:
		Store.start_timer(uid)
		%StartBtn.text = "STOP"

func _process(_delta):
	if Store.is_timer_running(uid):
		var dur = Time.get_unix_time_from_system() - Store.get_timer_start(uid)
		%TimerLabel.text = "%02d:%02d" % [int(dur/3600), int(fmod(dur, 3600)/60)]

func _export_pdf():
	var file = FileAccess.open("user://report.txt", FileAccess.WRITE)
	file.store_string("BERICHT\n" + Time.get_date_string_from_system())
	file.close()
	OS.shell_open(ProjectSettings.globalize_path("user://"))
