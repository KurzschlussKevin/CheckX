extends Resource
class_name Customer

@export var id: String = ""
@export var name: String = ""
@export var address: String = ""
@export var contact_name: String = ""
@export var contact_phone: String = ""
@export var contact_email: String = ""

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"address": address,
		"contact_name": contact_name,
		"contact_phone": contact_phone,
		"contact_email": contact_email,
	}

static func from_dict(d: Dictionary) -> Customer:
	var c := Customer.new()
	c.id = d.get("id", "")
	c.name = d.get("name", "")
	c.address = d.get("address", "")
	c.contact_name = d.get("contact_name", "")
	c.contact_phone = d.get("contact_phone", "")
	c.contact_email = d.get("contact_email", "")
	return c
