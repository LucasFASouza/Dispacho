extends Node2D

@onready var ui: UIOverlay = $UI
@onready var missions_root: Node2D = $Missions
@onready var units_root: Node2D = $Units

@export var rest_seconds: float = 5.0
@export var recover_seconds: float = 12.0
@export var mission_queue_res: MissionQueueResource
@export var members_res: Array[MemberData]

signal member_availability_changed
signal member_state_changed

var _selected_mission: Mission = null
var members: Array[Dictionary] = []

var UnitScene: PackedScene = preload("res://scenes/unit.tscn")
var MissionScene: PackedScene = preload("res://scenes/mission.tscn")

var _spawn_timers: Array[Dictionary] = []

func _ready() -> void:
	if members_res.is_empty():
		push_error("Game: members_res is empty. Assign MemberData resources in the Inspector.")
		return
	if mission_queue_res == null:
		push_error("Game: mission_queue_res is not assigned. Run build_missions.gd and assign data/missions/queue.tres in the Inspector.")
		return
	for data: MemberData in members_res:
		members.append({
			"name": data.member_name,
			"available": true,
			"state": "READY",
			"scores": data.scores,
		})
	ui.init_members(members)
	ui.closed.connect(_on_ui_closed)
	ui.menu_opened.connect(_on_menu_opened)
	ui.send_pressed.connect(_on_send_pressed)
	ui.ok_pressed.connect(_on_ok_pressed)
	for entry: MissionQueueEntry in mission_queue_res.entries:
		_spawn_timers.append({"remaining": entry.spawn_time, "entry": entry})
	set_process(true)

func _process(delta: float) -> void:
	for entry: Dictionary in _spawn_timers:
		entry["remaining"] -= delta
		if entry["remaining"] <= 0.0:
			_spawn_timers.erase(entry)
			_spawn_mission(entry["entry"] as MissionQueueEntry)
			return


func _spawn_mission(entry: MissionQueueEntry) -> void:
	var mission := MissionScene.instantiate() as Mission
	mission.init_from_resource(entry)
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
