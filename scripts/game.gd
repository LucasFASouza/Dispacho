extends Node2D

@onready var ui: UIOverlay = $UI
@onready var locations_root: Node2D = $Locations
@onready var units_root: Node2D = $Units

var _locations: Dictionary = {}

@export var rest_seconds: float = 5.0
@export var recover_seconds: float = 12.0
@export var deadline_seconds: float = 30.0
@export var max_missions: int = 3
@export var mission_queue_res: MissionQueueResource

@export var members_res: Array[MemberData]

signal member_availability_changed
signal member_state_changed

var _selected_mission: Mission = null
var members: Array[Dictionary] = []

var UnitScene: PackedScene = preload("res://scenes/unit.tscn")
var MissionScene: PackedScene = preload("res://scenes/mission.tscn")

var _pending_queue: Array[MissionData] = []
var _queue_timer: float = 0.0
var _mission_registry: Dictionary = {}

func _ready() -> void:
	if members_res.is_empty():
		push_error("Game: members_res is empty. Assign MemberData resources in the Inspector.")
		return
	if mission_queue_res == null:
		push_error("Game: mission_queue_res is not assigned. Run build_missions.gd and assign data/missions/queue.tres in the Inspector.")
		return
	for child in locations_root.get_children():
		if child is Location:
			_locations[child.location_id] = child
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

	var dir := DirAccess.open("res://data/missions/")
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".tres") and fname != "queue.tres":
				var res := load("res://data/missions/" + fname)
				if res is MissionData:
					_mission_registry[res.id] = res
			fname = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("Game: could not open res://data/missions/")

	# Seed queue with all starter missions from the registry (shuffled)
	for res: MissionData in _mission_registry.values():
		if res.starter:
			_pending_queue.append(res)
	_pending_queue.shuffle()

	_roll_queue_timer()
	set_process(true)

func _roll_queue_timer() -> void:
	_queue_timer = randf_range(mission_queue_res.min_wait, mission_queue_res.max_wait)

func _process(delta: float) -> void:
	_queue_timer -= delta
	if _queue_timer <= 0.0:
		if not _try_spawn_next():
			# All locations occupied — retry shortly
			_queue_timer = 2.0


func _active_mission_count() -> int:
	var count := 0
	for loc: Location in _locations.values():
		if not loc.is_available():
			count += 1
	return count


## Picks a random queued mission whose location is currently free and spawns it,
## provided the number of active missions is below max_missions.
## Returns true when something was spawned (timer will be re-rolled by caller).
func _try_spawn_next() -> bool:
	if _active_mission_count() >= max_missions:
		return false

	# Collect indices of candidates whose target location is free
	var candidates: Array[int] = []
	var i := 0
	while i < _pending_queue.size():
		var data: MissionData = _pending_queue[i]
		var loc: Location = _locations.get(data.location)
		if loc == null:
			push_error("Location not found: " + data.location)
			_pending_queue.remove_at(i)
			continue
		if loc.is_available():
			candidates.append(i)
		i += 1

	if candidates.is_empty():
		return false

	var pick: int = candidates[randi() % candidates.size()]
	var data: MissionData = _pending_queue[pick]
	_pending_queue.remove_at(pick)
	_spawn_mission_data(data)
	_roll_queue_timer()
	return true


func _spawn_mission_data(data: MissionData) -> void:
	var loc: Location = _locations.get(data.location)
	if loc == null:
		push_error("Location not found: " + data.location)
		return
	var mission := loc.try_spawn(data, MissionScene, deadline_seconds)
	if mission == null:
		push_warning("Location occupied, skipping: " + data.location)
		return
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
		# Inject triggered follow-up at front of queue before confirming
		var sd := mission.source_data
		if sd != null:
			var next_id := sd.in_success if mission.resolved_success else sd.in_failure
			if next_id != "":
				var next_data: MissionData = _mission_registry.get(next_id)
				if next_data != null:
					_pending_queue.push_front(next_data)
				else:
					push_error("Mission not found in registry: " + next_id)
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
