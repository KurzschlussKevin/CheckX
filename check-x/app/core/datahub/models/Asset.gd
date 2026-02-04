extends Resource
class_name Asset

@export var id: String = ""
@export var customer_id: String = ""
@export var site_name: String = ""        # Anlage/Standort
@export var location: String = ""         # Adresse/Ortsteil
@export var notes: String = ""

# Zuständigkeiten:
@export var responsible_intake: String = ""
@export var responsible_testing: String = ""
@export var responsible_report: String = ""

func to_dict() -> Dictionary:
	return {
		"id": id,
		"customer_id": customer_id,
		"site_name": site_name,
		"location": location,
		"notes": notes,
		"responsible_intake": responsible_intake,
		"responsible_testing": responsible_testing,
		"responsible_report": responsible_report,
	}

static func from_dict(d: Dictionary) -> Asset:
	var a := Asset.new()
	a.id = d.get("id", "")
	a.customer_id = d.get("customer_id", "")
	a.site_name = d.get("site_name", "")
	a.location = d.get("location", "")
	a.notes = d.get("notes", "")
	a.responsible_intake = d.get("responsible_intake", "")
	a.responsible_testing = d.get("responsible_testing", "")
	a.responsible_report = d.get("responsible_report", "")
	return a
