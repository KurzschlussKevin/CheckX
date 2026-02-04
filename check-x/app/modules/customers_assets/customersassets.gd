extends Control

var _selected_customer_id: String = ""

func _ready() -> void:
	%Search.text_changed.connect(func(_t): _refresh_list())
	%AddBtn.pressed.connect(_on_add)
	%List.item_selected.connect(_on_select)
	%SaveBtn.pressed.connect(_on_save)

	_refresh_list()
	Datahub.data_changed.connect(func(d):
		if d == DataHub.D_CUSTOMERS:
			_refresh_list()
	)

func _refresh_list() -> void:
	%List.clear()
	var q = %Search.text.to_lower().strip_edges()
	for c in Datahub.get_customers_list():
		if q != "" and not c.name.to_lower().contains(q):
			continue
		%List.add_item(c.name)
		%List.set_item_metadata(%List.item_count - 1, c.id)

func _on_add() -> void:
	var c := Customer.new()
	c.name = "Neuer Kunde"
	Datahub.upsert_customer(c)
	Datahub.set_dirty(Datahub.D_CUSTOMERS, true)

func _on_select(idx: int) -> void:
	_selected_customer_id = str(%List.get_item_metadata(idx))
	var d: Dictionary = Datahub.customers.get(_selected_customer_id, {})
	var c := Customer.from_dict(d)
	%Name.text = c.name
	%Address.text = c.address

func _on_save() -> void:
	if _selected_customer_id == "":
		return
	var c := Customer.new()
	c.id = _selected_customer_id
	c.name = %Name.text
	c.address = %Address.text
	Datahub.upsert_customer(c)
	# upsert_customer markiert dirty bereits
