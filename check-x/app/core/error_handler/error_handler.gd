extends Node

# Signal, um ein UI-Popup zu öffnen (wird von der Main-UI abonniert)
signal error_occurred(module_name, message, stack_trace)

func report(module: String, message: String, stack_trace: String = ""):
	var emp_id = Store.get_current_user_id()
	var device_info = OS.get_name() + " - " + OS.get_model_name()
	
	var data = {
		"emp_id": emp_id,
		"module": module,
		"error_message": message,
		"stack_trace": stack_trace,
		"device_info": device_info
	}
	
	# Sende den Bug-Report an das neue Backend-Endpunkt
	var url = Config.get_api_url() + "/system/report_bug"
	var http = HTTPRequest.new()
	add_child(http)
	
	var json_data = JSON.stringify(data)
	var headers = ["Content-Type: application/json"]
	
	http.request(url, headers, HTTPClient.METHOD_POST, json_data)
	
	# Wir warten nicht auf die Antwort, sondern triggern sofort das UI-Signal
	emit_signal("error_occurred", module, message, stack_trace)
	
	http.request_completed.connect(func(_r, code, _h, _b):
		print("Bug-Report gesendet, Status: ", code)
		http.queue_free()
	)
