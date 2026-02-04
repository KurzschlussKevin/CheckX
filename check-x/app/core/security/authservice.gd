extends Node
class_name AuthService

signal login_success(user: Dictionary)
signal login_failed(reason: String)
signal logout()

var current_user: Dictionary = {}   # { "username": "...", "role": "..." }

# Für echten Betrieb: Hash + Salt + externes User-Repo (oder AD/LDAP).
const USERS := {
	"admin": {"password": "admin123", "role": "admin"},
	"tech": {"password": "tech123", "role": "technician"},
	"sales": {"password": "sales123", "role": "sales"},
}

func login(username: String, password: String) -> void:
	username = username.strip_edges()
	if not USERS.has(username):
		emit_signal("login_failed", "Benutzer nicht gefunden")
		return
	if USERS[username]["password"] != password:
		emit_signal("login_failed", "Falsches Passwort")
		return

	current_user = {"username": username, "role": USERS[username]["role"]}
	emit_signal("login_success", current_user)

func do_logout() -> void:
	current_user = {}
	emit_signal("logout")

func has_role(role: String) -> bool:
	return current_user.get("role", "") == role
