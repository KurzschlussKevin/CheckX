extends RefCounted
class_name JsonStore

var base_dir := "user://anviro2"

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)

func save_json(filename: String, data: Dictionary) -> void:
	_ensure_dir()
	var path = base_dir + "/" + filename
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write: " + path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func load_json(filename: String) -> Dictionary:
	_ensure_dir()
	var path = base_dir + "/" + filename
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot read: " + path)
		return {}
	var txt := f.get_as_text()
	f.close()
	var res = JSON.parse_string(txt)
	return res if typeof(res) == TYPE_DICTIONARY else {}
