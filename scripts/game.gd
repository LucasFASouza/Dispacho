extends Node2D

@onready var ui: UIOverlay = $UI
@onready var missions_root: Node2D = $Missions
@onready var units_root: Node2D = $Units

@export var resolve_seconds: float = 3.0

signal member_availability_changed

var _selected_mission: Mission = null
var members = [
	{ "name": ":)", "available": true },
	{ "name": ";|", "available": true },
	{ "name": ":P", "available": true },
	{ "name": "B)", "available": true },
	{ "name": "XD", "available": true },
]

var UnitScene: PackedScene = preload("res://scenes/unit.tscn")

func _ready() -> void:
	for n in missions_root.get_children():
		if n is Mission:
			(n as Mission).selected.connect(_on_mission_selected.bind(n))

	ui.closed.connect(_on_ui_closed)
	ui.send_pressed.connect(_on_send_pressed)
	

func _on_mission_selected(text: String, mission: Mission) -> void:
	_selected_mission = mission
	ui.show_mission(text)


func _on_ui_closed() -> void:
	_selected_mission = null


func _on_send_pressed(unit_members: Array) -> void:
	if _selected_mission == null or !is_instance_valid(_selected_mission):
		return
	if unit_members.is_empty():
		return

	var mission := _selected_mission
	_selected_mission = null
	ui.hide_overlay_silent()

	var unit := UnitScene.instantiate() as Unit
	unit.members = unit_members
	units_root.add_child(unit)
	unit.arrived.connect(_on_unit_arrived.bind(unit, mission))

	mission.set_interactable(false)
	unit.go_to(mission.global_position)
	_set_members_available(unit_members, false)
	unit.returned_home.connect(_on_unit_returned_home.bind(unit_members))


func _on_unit_arrived(unit: Unit, mission: Mission) -> void:
	if is_instance_valid(mission):
		await get_tree().create_timer(resolve_seconds).timeout
		mission.queue_free()
	unit.go_home()


func _on_unit_returned_home(unit_members: Array) -> void:
	_set_members_available(unit_members, true)


func _set_members_available(unit_members: Array, available: bool) -> void:
	for m in unit_members:
		m["available"] = available
	member_availability_changed.emit()
