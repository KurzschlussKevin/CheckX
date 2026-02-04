extends RefCounted
class_name Id

static func new_id() -> String:
	# simple unique-ish id without external libs
	var t := str(Time.get_unix_time_from_system())
	var r := str(randi() % 1000000).pad_zeros(6)
	return t + "-" + r
