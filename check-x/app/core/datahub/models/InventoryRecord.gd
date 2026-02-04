extends Resource
class_name InventoryRecord

@export var id: String = ""
@export var asset_id: String = ""

# Komponenten-Zähler (Stepper):
@export var count_1ph_automats: int = 0
@export var count_3ph_automats: int = 0
@export var count_rcd: int = 0
@export var count_spd: int = 0        # Überspannungsschutz (optional)
@export var count_other: int = 0

@export var updated_unix: int = 0

func to_dict() -> Dictionary:
	return {
		"id": id,
		"asset_id": asset_id,
		"count_1ph_automats": count_1ph_automats,
		"count_3ph_automats": count_3ph_automats,
		"count_rcd": count_rcd,
		"count_spd": count_spd,
		"count_other": count_other,
		"updated_unix": updated_unix,
	}

static func from_dict(d: Dictionary) -> InventoryRecord:
	var r := InventoryRecord.new()
	r.id = d.get("id", "")
	r.asset_id = d.get("asset_id", "")
	r.count_1ph_automats = int(d.get("count_1ph_automats", 0))
	r.count_3ph_automats = int(d.get("count_3ph_automats", 0))
	r.count_rcd = int(d.get("count_rcd", 0))
	r.count_spd = int(d.get("count_spd", 0))
	r.count_other = int(d.get("count_other", 0))
	r.updated_unix = int(d.get("updated_unix", 0))
	return r
