extends Control

var uid = "" # Wird dynamisch geladen

func _ready():
	# Mitarbeiter-ID vom Store beziehen
	uid = Store.get_current_user_id()
	
	# Signale der Buttons verbinden
	%StartBtn.pressed.connect(_toggle_timer)
	
	# WICHTIG: Das Popup mit der ID initialisieren und öffnen
	%VacBtn.pressed.connect(func(): %VacationPopup.open(uid))
	
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
	if Store.is_timer_running(uid):
		var dur = Time.get_unix_time_from_system() - Store.get_timer_start(uid)
		var hours = int(dur / 3600)
		var minutes = int(fmod(dur, 3600) / 60)
		var seconds = int(fmod(dur, 60))
		%TimerLabel.text = "%02d:%02d:%02d" % [hours, minutes, seconds]

func _toggle_timer():
	if Store.is_timer_running(uid):
		var project = %ProjectInput.text
		var notes = %NotesInput.text
		Store.stop_timer(project, notes) # Nutzt intern die aktuelle ID
		
		%StartBtn.text = "START"
		%ProjectInput.text = ""
		%NotesInput.text = ""
		%TimerLabel.text = "00:00:00"
		%CalendarPanel.refresh()
	else:
		var project = %ProjectInput.text if !%ProjectInput.text.is_empty() else "Allgemein"
		Store.start_timer(project)
		%StartBtn.text = "STOP"

func _export_pdf():
	var file = FileAccess.open("user://report.txt", FileAccess.WRITE)
	file.store_string("BERICHT\n" + Time.get_date_string_from_system())
	file.close()
	OS.shell_open(ProjectSettings.globalize_path("user://"))
