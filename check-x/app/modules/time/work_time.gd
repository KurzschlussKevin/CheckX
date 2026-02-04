extends Control

var _drive_running := false
var _work_running := false
var _drive_start_unix := 0
var _work_start_unix := 0

var _drive_minutes := 0
var _work_minutes := 0

func _ready() -> void:
	%DriveBtn.pressed.connect(_toggle_drive)
	%WorkBtn.pressed.connect(_toggle_work)
	%Diary.text_changed.connect(func(): Datahub.set_dirty(Datahub.D_TIME, true))
	%Date.text_changed.connect(func(_t): Datahub.set_dirty(Datahub.D_TIME, true))
	%SignName.text_changed.connect(func(_t): Datahub.set_dirty(Datahub.D_TIME, true))
	%SaveBtn.pressed.connect(_save)

	_update_totals()

func _toggle_drive() -> void:
	Datahub.set_dirty(Datahub.D_TIME, true)
	if not _drive_running:
		_drive_running = true
		_drive_start_unix = Time.get_unix_time_from_system()
		%DriveBtn.text = "Fahrt STOP"
	else:
		_drive_running = false
		var delta := Time.get_unix_time_from_system() - _drive_start_unix
		_drive_minutes += int(delta / 60)
		%DriveBtn.text = "Fahrt START"
	_update_totals()

func _toggle_work() -> void:
	Datahub.set_dirty(Datahub.D_TIME, true)
	if not _work_running:
		_work_running = true
		_work_start_unix = Time.get_unix_time_from_system()
		%WorkBtn.text = "Arbeit STOP"
	else:
		_work_running = false
		var delta := Time.get_unix_time_from_system() - _work_start_unix
		_work_minutes += int(delta / 60)
		%WorkBtn.text = "Arbeit START"
	_update_totals()

func _update_totals() -> void:
	%Totals.text = "Fahrt: %d min | Arbeit: %d min" % [_drive_minutes, _work_minutes]

func _save() -> void:
	# Wenn Timer laufen, stoppe logisch nicht automatisch – du kannst das ändern.
	var t := TimeEntry.new()
	t.date_iso = %Date.text.strip_edges()
	t.drive_minutes = _drive_minutes
	t.work_minutes = _work_minutes
	t.diary_notes = %Diary.text
	t.signed_by = %SignName.text.strip_edges()
	t.technician = Authservice.current_user.get("username", "unknown")

	Datahub.upsert_time_entry(t)
	Datahub.save_all()
