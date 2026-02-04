extends Control

func _ready() -> void:
	%Stepper1.label = "1-phasige Automaten"
	%Stepper2.label = "3-phasige Automaten"
	%Stepper3.label = "RCDs"

	%Stepper1.value_changed.connect(func(_v): Datahub.set_dirty(DataHub.D_INVENTORY, true))
	%Stepper2.value_changed.connect(func(_v): Datahub.set_dirty(DataHub.D_INVENTORY, true))
	%Stepper3.value_changed.connect(func(_v): Datahub.set_dirty(DataHub.D_INVENTORY, true))
	%AssetId.text_changed.connect(func(_t): Datahub.set_dirty(DataHub.D_INVENTORY, true))

	%SaveBtn.pressed.connect(_on_save)

func _on_save() -> void:
	var asset_id = %AssetId.text.strip_edges()
	if asset_id == "":
		return

	var r := InventoryRecord.new()
	r.asset_id = asset_id
	r.count_1ph_automats = %Stepper1.value
	r.count_3ph_automats = %Stepper2.value
	r.count_rcd = %Stepper3.value
	Datahub.upsert_inventory(r)
	Datahub.save_all()
