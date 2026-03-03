extends Control

# UI Referenzen (Bestehende)
@onready var work_hours_spin = %WorkHoursSpin
@onready var break_time_spin = %BreakTimeSpin
@onready var core_start_spin = $Arbeitszeit/M/V/Card_Rules/V/CoreTimeStart
@onready var core_end_spin = $Arbeitszeit/M/V/Card_Rules/V/CoreTimeEnd
@onready var auto_break_check = $Arbeitszeit/M/V/Card_Rules/V/BreakRuleCheck
@onready var holiday_opt = $Arbeitszeit/M/V/Card_Rules/V/HolidayOption
@onready var vacation_spin = $Arbeitszeit/M/V/Card_Quota/V/VacationQuotaSpin

# UI Referenzen (NEU: Erfassung - für jeden Nutzer frei)
@onready var default_project_input = %DefaultProjectInput
@onready var auto_stop_check = %AutoStopCheck
@onready var require_desc_check = $Arbeitszeit/M/V/Card_Tracking/V/RequireDescCheck

# UI Referenzen (NEU: Dokumente / PDF-Export)
@onready var timesheet_path_edit = %TimesheetPathEdit
@onready var timesheet_btn = %TimesheetBtn
@onready var invoice_path_edit = %InvoicePathEdit
@onready var invoice_btn = %InvoiceBtn
@onready var export_name_edit = %ExportNameEdit
@onready var pdf_file_dialog = %PdfFileDialog

# Speichert, welcher Button den FileDialog geöffnet hat ("timesheet" oder "invoice")
var _current_dialog_target: String = ""

# NEU: HTTP Request für den Datei-Upload
var upload_http: HTTPRequest

func _ready() -> void:
	_load_business_settings()
	_check_admin_permissions()
	_connect_signals()
	
	_format_time_display(core_start_spin)
	_format_time_display(core_end_spin)
	
	# NEU: HTTP Node instanziieren
	upload_http = HTTPRequest.new()
	add_child(upload_http)
	upload_http.request_completed.connect(_on_upload_completed)

# 1. PRÜFUNG: Admin vs. Nutzer
func _check_admin_permissions() -> void:
	var is_admin = Store.current_user.get("role", "") == "Admin"
	
	# Diese Felder bleiben Admin-exklusiv (Firmenregeln)
	work_hours_spin.editable = is_admin
	break_time_spin.editable = is_admin
	core_start_spin.editable = is_admin
	core_end_spin.editable = is_admin
	auto_break_check.disabled = !is_admin
	holiday_opt.disabled = !is_admin
	vacation_spin.editable = is_admin
	
	# NEU: Vorlagen dürfen nur von Admins geändert werden
	timesheet_btn.disabled = !is_admin
	invoice_btn.disabled = !is_admin
	export_name_edit.editable = is_admin
	
	# DIESER BEREICH IST JETZT FÜR JEDEN FREI:
	default_project_input.editable = true 
	auto_stop_check.disabled = false
	require_desc_check.disabled = false

# 2. LADEN: Werte aus Config
func _load_business_settings() -> void:
	# Admin-Werte
	work_hours_spin.value = Config.get_value("business", "daily_work_hours", 8.0)
	break_time_spin.value = Config.get_value("business", "daily_break_minutes", 30)
	core_start_spin.value = Config.get_value("business", "core_time_start", 9.0)
	core_end_spin.value = Config.get_value("business", "core_time_end", 15.0)
	auto_break_check.button_pressed = Config.get_value("business", "auto_break_after_6h", true)
	holiday_opt.selected = Config.get_value("business", "holiday_region", 0)
	vacation_spin.value = Config.get_value("business", "vacation_days_quota", 30)
	
	# Erfassungs-Werte (Nutzer-individuell)
	default_project_input.text = Config.get_value("business", "default_project", "Allgemein")
	auto_stop_check.button_pressed = Config.get_value("business", "auto_stop_on_exit", false)
	require_desc_check.button_pressed = Config.get_value("business", "require_description", false)
	
	# Dokumenten-Werte (PDF Vorlagen)
	timesheet_path_edit.text = Config.get_value("business", "timesheet_template", "")
	invoice_path_edit.text = Config.get_value("business", "invoice_template", "")
	export_name_edit.text = Config.get_value("business", "export_filename_format", "Stundenzettel_%Name%_%Monat%")

# 3. VERBINDEN & SPEICHERN
func _connect_signals() -> void:
	# Formatierung für Admin-Spins
	core_start_spin.value_changed.connect(func(v): _format_time_display(core_start_spin))
	core_end_spin.value_changed.connect(func(v): _format_time_display(core_end_spin))
	
	# Signale für Admin-Werte (nur wenn Admin)
	if Store.current_user.get("role") == "Admin":
		work_hours_spin.value_changed.connect(func(v): Config.set_value("business", "daily_work_hours", v))
		break_time_spin.value_changed.connect(func(v): Config.set_value("business", "daily_break_minutes", int(v)))
		core_start_spin.value_changed.connect(func(v): Config.set_value("business", "core_time_start", v))
		core_end_spin.value_changed.connect(func(v): Config.set_value("business", "core_time_end", v))
		auto_break_check.toggled.connect(func(v): Config.set_value("business", "auto_break_after_6h", v))
		holiday_opt.item_selected.connect(func(v): Config.set_value("business", "holiday_region", v))
		vacation_spin.value_changed.connect(func(v): Config.set_value("business", "vacation_days_quota", int(v)))
	
	# Signale für JEDEN NUTZER (Erfassung)
	default_project_input.text_changed.connect(func(new_text): 
		Config.set_value("business", "default_project", new_text)
	)
	auto_stop_check.toggled.connect(func(v): 
		Config.set_value("business", "auto_stop_on_exit", v)
	)
	require_desc_check.toggled.connect(func(v): 
		Config.set_value("business", "require_description", v)
	)
	
	# Signale für PDF-Dokumentenverwaltung
	timesheet_btn.pressed.connect(_on_timesheet_btn_pressed)
	invoice_btn.pressed.connect(_on_invoice_btn_pressed)
	pdf_file_dialog.file_selected.connect(_on_pdf_file_selected)
	
	export_name_edit.text_changed.connect(func(new_text): 
		Config.set_value("business", "export_filename_format", new_text)
	)

func _format_time_display(spin: SpinBox) -> void:
	var val = spin.value
	var hours = int(val)
	var minutes = int((val - hours) * 60)
	spin.suffix = " (%02d:%02d Uhr)" % [hours, minutes]

# --- NEUE FUNKTIONEN FÜR DEN FILE DIALOG ---

func _on_timesheet_btn_pressed() -> void:
	_current_dialog_target = "timesheet"
	pdf_file_dialog.title = "Stundenzettel-Vorlage auswählen"
	if timesheet_path_edit.text != "":
		pdf_file_dialog.current_dir = timesheet_path_edit.text.get_base_dir()
	pdf_file_dialog.popup_centered_ratio(0.5)

func _on_invoice_btn_pressed() -> void:
	_current_dialog_target = "invoice"
	pdf_file_dialog.title = "Rechnungs-Vorlage auswählen"
	if invoice_path_edit.text != "":
		pdf_file_dialog.current_dir = invoice_path_edit.text.get_base_dir()
	pdf_file_dialog.popup_centered_ratio(0.5)

func _on_pdf_file_selected(path: String) -> void:
	# Wird aufgerufen, wenn der Nutzer im FileDialog auf "Öffnen" klickt
	if _current_dialog_target == "timesheet":
		timesheet_path_edit.text = path
		Config.set_value("business", "timesheet_template", path)
		_upload_pdf_to_server(path, "timesheet")
	elif _current_dialog_target == "invoice":
		invoice_path_edit.text = path
		Config.set_value("business", "invoice_template", path)
		_upload_pdf_to_server(path, "invoice")

# --- NEUE FUNKTIONEN FÜR DEN UPLOAD (MULTIPART) ---

func _upload_pdf_to_server(path: String, template_type: String) -> void:
	print("Starte Upload für: ", template_type)
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("❌ Fehler beim Lesen der PDF-Datei!")
		return
		
	var file_data = file.get_buffer(file.get_length())
	var boundary = "GodotCheckXBoundary12345"
	var body = PackedByteArray()
	
	# 1. Das "template_type" Text-Feld
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"template_type\"\r\n\r\n").to_utf8_buffer())
	body.append_array((template_type + "\r\n").to_utf8_buffer())
	
	# 2. Das PDF "file" Feld
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"file\"; filename=\"" + path.get_file() + "\"\r\n").to_utf8_buffer())
	body.append_array(("Content-Type: application/pdf\r\n\r\n").to_utf8_buffer())
	body.append_array(file_data)
	body.append_array(("\r\n--" + boundary + "--\r\n").to_utf8_buffer())
	
	var token = Store.token if "token" in Store else ""
	var headers = [
		"Content-Type: multipart/form-data; boundary=" + boundary,
		"Authorization: Bearer " + token
	]
	
	var url = Config.API_URL + "/templates/upload_pdf"
	upload_http.request_raw(url, headers, HTTPClient.METHOD_POST, body)

func _on_upload_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		print("✅ Vorlage erfolgreich auf den Server hochgeladen!")
	else:
		print("❌ Fehler beim Upload. Server antwortet mit Code: ", response_code)
