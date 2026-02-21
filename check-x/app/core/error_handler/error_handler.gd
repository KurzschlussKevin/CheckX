extends Node

signal show_error_dialog(module_name, error_msg)
var current_error_data = {}

func report(module: String, message: String):
	# Wir sammeln Daten, aber sichern alles mit "Unknown" ab, falls der Store klemmt
	var emp_id = "Unknown"
	if Store and Store.has_method("get_current_user_id"):
		var stored_id = Store.get_current_user_id()
		if str(stored_id) != "":
			emp_id = str(stored_id)
		
	current_error_data = {
		"emp_id": emp_id,
		"module": module,
		"error_message": message,
		"device_info": OS.get_name() + " " + OS.get_model_name(),
		"stack_trace": Time.get_datetime_string_from_system()
	}
	
	# WICHTIG: Erst das Signal senden, damit das Fenster aufpoppt
	emit_signal("show_error_dialog", module, message)

func send_report_to_server(user_note: String = ""):
	if current_error_data.is_empty(): return
	
	if user_note != "":
		current_error_data["error_message"] += "\nUser-Notiz: " + user_note
	
	# Hier lag der Fehler: Wir nutzen jetzt sicher Store statt Config
	var url = Store.get_api_url() + "/system/report_bug"
	
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify(current_error_data)
	
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	
	http.request_completed.connect(func(_r, code, _h, _b):
		print("Bug-Report erfolgreich an Server gesendet. Status: ", code)
		http.queue_free()
	)
