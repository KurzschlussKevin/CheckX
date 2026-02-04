extends Control

func _ready() -> void:
	%CardWork.title = "Arbeitszeit (Monat)"
	%CardOrders.title = "Aufträge"
	%CardDue.title = "Fälligkeiten"

	_refresh()
	Datahub.data_changed.connect(func(_d): _refresh())

func _refresh() -> void:
	# Platzhalter-Logik (später echte Queries)
	%CardWork.value_text = "12:40 h"
	%CardWork.hint = "Fahrt+Arbeit"
	%CardOrders.value_text = "8 offen"
	%CardDue.value_text = "3 diese Woche"
