extends Resource
class_name TimeEntry

@export var id: String = ""
@export var customer_id: String = ""
@export var asset_id: String = ""
@export var technician: String = ""

@export var date_iso: String = ""      # "YYYY-MM-DD"
@export var drive_minutes: int = 0
@export var work_minutes: int = 0
@export var diary_notes: String = ""

@export var signed_by: String = ""
@export var signature_png_base64: String = ""  # simple storage, export later

func to_dict() -> Dictionary:
	return {
		"id": id,
		"customer_id": customer_id,
		"asset_id": asset_id,
		"technician": technician,
		"date_iso": date_iso,
		"drive_minutes": drive_minutes,
		"work_minutes": work_minutes,
		"diary_notes": diary_notes,
		"signed_by": signed_by,
		"signature_png_base64": signature_png_base64,
	}

static func from_dict(d: Dictionary) -> TimeEntry:
	var t := TimeEntry.new()
	t.id = d.get("id", "")
	t.customer_id = d.get("customer_id", "")
	t.asset_id = d.get("asset_id", "")
	t.technician = d.get("technician", "")
	t.date_iso = d.get("date_iso", "")
	t.drive_minutes = int(d.get("drive_minutes", 0))
	t.work_minutes = int(d.get("work_minutes", 0))
	t.diary_notes = d.get("diary_notes", "")
	t.signed_by = d.get("signed_by", "")
	t.signature_png_base64 = d.get("signature_png_base64", "")
	return t
