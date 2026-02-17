extends Control

var uid = "001" # In Punkt 4 wird dies dynamisch

func _ready():
	# Signale der Buttons in time_tracking_new verbinden
	%StartBtn.pressed.connect(_toggle_timer)
	%VacBtn.pressed.connect(func(): %VacationPopup.visible = true)
	%PdfBtn.pressed.connect(_export_pdf)
	
	# Kalender initialisieren
	%CalendarPanel.setup(uid)
	%CalendarPanel.request_manual.connect(func(d): %ManualPopup.open(uid, d))
	%ManualPopup.entry_saved.connect(func(): %CalendarPanel.refresh())
	
	%DateLabel.text = Time.get_date_string_from_system()
	
	# UI-Zustand prüfen, falls Timer bereits läuft
	if Store.is_timer_running(uid):
		%StartBtn.text = "STOP"

func _process(_delta):
	# Live-Update der Zahlen, wenn der Timer läuft
	if Store.is_timer_running(uid):
		var dur = Time.get_unix_time_from_system() - Store.get_timer_start(uid)
		var hours = int(dur / 3600)
		var minutes = int(fmod(dur, 3600) / 60)
		var seconds = int(fmod(dur, 60))
		%TimerLabel.text = "%02d:%02d:%02d" % [hours, minutes, seconds]

func _toggle_timer():
	if Store.is_timer_running(uid):
		# Projekt und Notizen aus den LineEdit/TextEdit Feldern holen
		var project = %ProjectInput.text
		var notes = %NotesInput.text
		
		Store.stop_timer(project, notes)
		
		# UI zurücksetzen
		%StartBtn.text = "START"
		%ProjectInput.text = ""
		%NotesInput.text = ""
		%TimerLabel.text = "00:00:00"
		%CalendarPanel.refresh()
	else:
		Store.start_timer(uid)
		%StartBtn.text = "STOP"

func _export_pdf():
	var file = FileAccess.open("user://report.txt", FileAccess.WRITE)
	file.store_string("BERICHT\n" + Time.get_date_string_from_system())
	file.close()
	OS.shell_open(ProjectSettings.globalize_path("user://"))
