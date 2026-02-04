extends Node
class_name UnsavedGuard

# Welche Domains gehören zu welcher Route?
const ROUTE_DOMAINS := {
	"customers_assets": [DataHub.D_CUSTOMERS, DataHub.D_ASSETS],
	"inventory": [DataHub.D_INVENTORY],
	"time": [DataHub.D_TIME],
	"dashboard": [],
	"schedule": [DataHub.D_SCHEDULE],
	"calibration": [DataHub.D_CALIBRATION],
	"sales": [DataHub.D_OFFERS],
	"export": [],
	"settings": [],
}

var _pending_route: String = ""
var _dialog: ConfirmUnsavedDialog = null

func set_dialog(dialog: ConfirmUnsavedDialog) -> void:
	_dialog = dialog

func request_route_change(next_route: String) -> bool:
	# Prüfe Dirty des aktuellen Moduls (basierend auf current_route)
	var cur := Scenerouter.current_route
	if cur == "" or cur == next_route:
		return true

	var domains: Array = ROUTE_DOMAINS.get(cur, [])
	var dirty := false
	for d in domains:
		if Datahub.is_dirty(d):
			dirty = true
			break

	if not dirty:
		return true

	# Dirty -> Dialog
	if _dialog == null:
		push_error("UnsavedGuard: dialog not set")
		return false

	_pending_route = next_route
	_dialog.open(
		"Ungespeicherte Änderungen",
		"Du hast ungespeicherte Daten im aktuellen Modul. Speichern?",
		_on_save_and_continue,
		_on_discard_and_continue,
		_on_cancel
	)
	return false

func _on_save_and_continue() -> void:
	Datahub.save_all()
	Scenerouter._force_goto(_pending_route)

func _on_discard_and_continue() -> void:
	# Reload -> verwirft nicht gespeichertes
	Datahub.load_all()
	Scenerouter._force_goto(_pending_route)

func _on_cancel() -> void:
	_pending_route = ""
