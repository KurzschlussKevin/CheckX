extends Node
class_name DataHub

signal data_changed(domain: String)     # z.B. "customers", "inventory", ...
signal dirty_changed(domain: String, is_dirty: bool)

const FILE_DB := "db.json"

# Domains
const D_CUSTOMERS := "customers"
const D_ASSETS := "assets"
const D_INVENTORY := "inventory"
const D_TIME := "time"
const D_SCHEDULE := "schedule"
const D_CALIBRATION := "calibration"
const D_OFFERS := "offers"

var _store := JsonStore.new()

var customers: Dictionary = {}   # id -> Customer(dict)
var assets: Dictionary = {}      # id -> Asset(dict)
var inventory: Dictionary = {}   # id -> InventoryRecord(dict)
var time_entries: Dictionary = {}# id -> TimeEntry(dict)

var _dirty: Dictionary = {
	D_CUSTOMERS: false,
	D_ASSETS: false,
	D_INVENTORY: false,
	D_TIME: false,
	D_SCHEDULE: false,
	D_CALIBRATION: false,
	D_OFFERS: false,
}

func _ready() -> void:
	load_all()

func is_dirty(domain: String) -> bool:
	return bool(_dirty.get(domain, false))

func set_dirty(domain: String, v: bool) -> void:
	if _dirty.get(domain, false) == v:
		return
	_dirty[domain] = v
	emit_signal("dirty_changed", domain, v)

func mark_changed(domain: String) -> void:
	set_dirty(domain, true)
	emit_signal("data_changed", domain)

func save_all() -> void:
	var db := {
		"customers": customers,
		"assets": assets,
		"inventory": inventory,
		"time_entries": time_entries,
		"meta": {"saved_unix": Time.get_unix_time_from_system()}
	}
	_store.save_json(FILE_DB, db)
	# Alles als "gespeichert" markieren:
	for k in _dirty.keys():
		set_dirty(k, false)

func load_all() -> void:
	var db := _store.load_json(FILE_DB)
	customers = db.get("customers", {})
	assets = db.get("assets", {})
	inventory = db.get("inventory", {})
	time_entries = db.get("time_entries", {})
	# nach Load: nicht dirty
	for k in _dirty.keys():
		set_dirty(k, false)

# --- CRUD helpers (minimal, erweiterbar) ---

func upsert_customer(c: Customer) -> void:
	if c.id == "":
		c.id = Id.new_id()
	customers[c.id] = c.to_dict()
	mark_changed(D_CUSTOMERS)

func delete_customer(id: String) -> void:
	customers.erase(id)
	mark_changed(D_CUSTOMERS)

func upsert_asset(a: Asset) -> void:
	if a.id == "":
		a.id = Id.new_id()
	assets[a.id] = a.to_dict()
	mark_changed(D_ASSETS)

func upsert_inventory(r: InventoryRecord) -> void:
	if r.id == "":
		r.id = Id.new_id()
	r.updated_unix = Time.get_unix_time_from_system()
	inventory[r.id] = r.to_dict()
	mark_changed(D_INVENTORY)

func upsert_time_entry(t: TimeEntry) -> void:
	if t.id == "":
		t.id = Id.new_id()
	time_entries[t.id] = t.to_dict()
	mark_changed(D_TIME)

func get_customers_list() -> Array[Customer]:
	var arr: Array[Customer] = []
	for id in customers.keys():
		arr.append(Customer.from_dict(customers[id]))
	arr.sort_custom(func(a, b): return a.name.to_lower() < b.name.to_lower())
	return arr
