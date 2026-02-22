extends Control

# Da wir die Szenen instanziiert haben, greifen wir auf die Werte über den Pfad zu
@onready var lbl_revenue = $ScrollContainer/Margin/VBox/TileGrid/StatRevenue/Margin/VBox/Value
@onready var lbl_hours = $ScrollContainer/Margin/VBox/TileGrid/StatHours/Margin/VBox/Value
@onready var lbl_tasks = $ScrollContainer/Margin/VBox/TileGrid/StatTasks/Margin/VBox/Value
@onready var welcome_label = %WelcomeLabel
@onready var refresh_btn = %RefreshBtn

var current_uid = ""

func _ready():
	current_uid = Store.get_current_user_id()
	
	# Zugriff auf das neue User-Objekt im Store
	var user_data = Store.current_user 
	
	if user_data and user_data.has("name"):
		welcome_label.text = "Willkommen, " + str(user_data["name"])
	else:
		welcome_label.text = "Willkommen, Gast"
	
	if refresh_btn:
		refresh_btn.pressed.connect(fetch_stats)
	
	fetch_stats()

func fetch_stats():
	var url = Store.get_api_url() + "/dashboard/stats?emp_id=" + str(current_uid)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, c, _h, body):
		if c == 200:
			var data = JSON.parse_string(body.get_string_from_utf8())
			if data:
				_update_ui(data)
		http.queue_free()
	)
	http.request(url)

func _update_ui(data):
	if lbl_revenue:
		var rev = data.get("revenue_week", 0.0)
		lbl_revenue.text = "%.2f €" % rev
		lbl_revenue.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4) if rev > 0 else Color.WHITE)
		
	if lbl_hours:
		lbl_hours.text = str(data.get("hours_week", 0.0)) + " Std."
		
	if lbl_tasks:
		lbl_tasks.text = str(data.get("open_tasks", 0))
