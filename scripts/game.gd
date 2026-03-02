extends Node2D

@onready var ui: UIOverlay = $UI
@onready var missions_root: Node2D = $Missions
@onready var units_root: Node2D = $Units

@export var rest_seconds: float = 5.0
@export var recover_seconds: float = 12.0

signal member_availability_changed
signal member_state_changed

var _selected_mission: Mission = null
var members: Array[Dictionary] = [
  { "name": "Bigfoot",	"available": true, "state": "READY", "scores": {"STR": 3, "DEX": 2, "INT": 1, "CHA": 1, "CON": 0}},
  { "name": "Mothman",	"available": true, "state": "READY", "scores": {"STR": 0, "DEX": 3, "INT": 2, "CHA": 1, "CON": 1}},
  { "name": "Gilledman",  "available": true, "state": "READY", "scores": {"STR": 1, "DEX": 0, "INT": 3, "CHA": 2, "CON": 1}},
  { "name": "Chupacabra", "available": true, "state": "READY", "scores": {"STR": 1, "DEX": 1, "INT": 0, "CHA": 3, "CON": 2}},
  { "name": "Nessie",	 "available": true, "state": "READY", "scores": {"STR": 2, "DEX": 1, "INT": 1, "CHA": 0, "CON": 3}},
]

var UnitScene: PackedScene = preload("res://scenes/unit.tscn")
var MissionScene: PackedScene = preload("res://scenes/mission.tscn")

var _mission_data: Dictionary = {}

func _load_mission_data() -> void:
	var file := FileAccess.open("res://data/missions.json", FileAccess.READ)
	if file == null:
		push_error("Failed to open missions.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("Failed to parse missions.json")
		return
	for entry: Dictionary in json.data:
		_mission_data[entry["id"]] = entry

var mission_queue: Array = [
	{
		"id": "ration_bags",
		"spawn_time": 2.0,
		"deadline": 20.0,
		"position": Vector2(-72, -48),
	},
	{
		"id": "blue_hedgehog",
		"spawn_time": 2.5,
		"deadline": 20.0,
		"position": Vector2(-72, 48),
	},
	{
		"id": "goblin_cubes",
		"spawn_time": 3.0,
		"deadline": 20.0,
		"position": Vector2(96, 0),
	}
]

var _spawn_timers: Array[Dictionary] = []

func _ready() -> void:
	_load_mission_data()
	ui.closed.connect(_on_ui_closed)
	ui.menu_opened.connect(_on_menu_opened)
	ui.send_pressed.connect(_on_send_pressed)
	ui.ok_pressed.connect(_on_ok_pressed)
	for data: Dictionary in mission_queue:
		_spawn_timers.append({"remaining": data["spawn_time"], "data": data})
	set_process(true)

func _process(delta: float) -> void:
	for entry: Dictionary in _spawn_timers:
		entry["remaining"] -= delta
		if entry["remaining"] <= 0.0:
			_spawn_timers.erase(entry)
			_spawn_mission(entry["data"] as Dictionary)
			return


func _spawn_mission(data: Dictionary) -> void:
	var merged := data.duplicate()
	if _mission_data.has(data["id"]):
		merged.merge(_mission_data[data["id"]])
	var mission := MissionScene.instantiate() as Mission
	mission.init(merged)
	missions_root.add_child(mission)
	mission.selected.connect(_on_mission_selected)
	

func _on_mission_selected(mission: Mission) -> void:
	if mission.done:
		ui.show_review(mission)
	else:
		_selected_mission = mission
		ui.show_active(mission)


func _on_menu_opened() -> void:
	get_tree().paused = true


func _on_ok_pressed(mission: Mission) -> void:
	ui.hide_overlay_silent()
	get_tree().paused = false
	if is_instance_valid(mission):
		mission.confirm()


func _on_ui_closed() -> void:
	_selected_mission = null
	get_tree().paused = false


func _on_send_pressed(unit_members: Array[Dictionary]) -> void:
	if _selected_mission == null or !is_instance_valid(_selected_mission):
		return
	if unit_members.is_empty():
		return
		
	get_tree().paused = false

	var mission := _selected_mission
	_selected_mission = null
	ui.hide_overlay_silent()

	var unit := UnitScene.instantiate() as Unit
	unit.members = unit_members
	units_root.add_child(unit)
	unit.arrived.connect(_on_unit_arrived.bind(unit, mission))
	mission.resolved.connect(_on_mission_resolved.bind(unit))

	mission.set_interactable(false)
	unit.go_to(mission.global_position)
	_set_member_states(unit_members, "MOVING")


func _on_unit_arrived(unit: Unit, mission: Mission) -> void:
	if not is_instance_valid(mission) or mission.expired:
		return
	_set_member_states(unit.members, "IN_MISSION")
	if not mission.start_resolve(unit.members):
		_finish_unit(unit, false)


func _on_mission_resolved(success: bool, unit: Unit) -> void:
	_finish_unit(unit, success)


func _finish_unit(unit: Unit, success: bool) -> void:
	_set_member_states(unit.members, "RETURNING")
	unit.returned_home.connect(_on_unit_returned_home.bind(unit.members as Array[Dictionary], success))
	unit.go_home()


func _on_unit_returned_home(unit_members: Array[Dictionary], success: bool) -> void:
	var state := "RESTING" if success else "RECOVERING"
	var wait := rest_seconds if success else recover_seconds
	for m in unit_members:
		m["countdown"] = wait
	_set_member_states(unit_members, state)
	_tick_countdown(unit_members)


func _tick_countdown(unit_members: Array[Dictionary]) -> void:
	get_tree().create_timer(1.0, false).timeout.connect(func():
		var any_left := false
		for m: Dictionary in unit_members:
			if m["state"] == "RESTING" or m["state"] == "RECOVERING":
				m["countdown"] -= 1
				if m["countdown"] <= 0:
					m["state"] = "READY"
					m["available"] = true
				else:
					any_left = true
		member_availability_changed.emit()
		member_state_changed.emit()
		if any_left:
			_tick_countdown(unit_members)
	)


func _set_member_states(unit_members: Array[Dictionary], state: String) -> void:
	for m: Dictionary in unit_members:
		m["state"] = state
		m["available"] = (state == "READY")
	member_availability_changed.emit()
	member_state_changed.emit()
