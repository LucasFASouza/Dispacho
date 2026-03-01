extends Node2D

@onready var ui: UIOverlay = $UI
@onready var missions_root: Node2D = $Missions
@onready var units_root: Node2D = $Units

@export var resolve_seconds: float = 1.5

var _selected_mission: Mission = null
var _active_unit: Unit = null
var _busy: bool = false
var members = [
	{
		"name": ":)",
	},
	{
		"name": ";|",
	},
	{
		"name": ":P",
	},
	{
		"name": "B)",
	},
	{
		"name": "XD",
	}
]

var UnitScene: PackedScene = preload("res://scenes/unit.tscn")

func _ready() -> void:
	for n in missions_root.get_children():
		if n is Mission:
			(n as Mission).selected.connect(_on_mission_selected.bind(n))

	ui.closed.connect(_on_ui_closed)
	ui.send_pressed.connect(_on_send_pressed)




func _on_mission_selected(text: String, mission: Mission) -> void:
	if _busy:
		return
	_selected_mission = mission
	ui.show_mission(text)


func _on_ui_closed() -> void:
	_selected_mission = null


func _on_send_pressed(unit_members: Array) -> void:
	if _busy:
		return
	if _selected_mission == null or !is_instance_valid(_selected_mission):
		return
	if unit_members.is_empty():
		return

	_busy = true
	ui.hide_overlay_silent()

	_active_unit = UnitScene.instantiate() as Unit
	_active_unit.members = unit_members
	units_root.add_child(_active_unit)
	_active_unit.arrived.connect(_on_unit_arrived)
	_active_unit.returned_home.connect(_on_unit_returned_home)

	_selected_mission.set_interactable(false)
	_active_unit.go_to(_selected_mission.global_position)


func _on_unit_arrived() -> void:
	if _selected_mission != null and is_instance_valid(_selected_mission):
		await get_tree().create_timer(resolve_seconds).timeout
		_selected_mission.queue_free()

	_selected_mission = null
	_active_unit.go_home()


func _on_unit_returned_home() -> void:
	_active_unit = null
	_busy = false
