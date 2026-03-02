extends Node2D

@onready var ui: UIOverlay = $UI
@onready var missions_root: Node2D = $Missions
@onready var units_root: Node2D = $Units

@export var rest_seconds: float = 5.0
@export var recover_seconds: float = 12.0

signal member_availability_changed
signal member_state_changed

var _selected_mission: Mission = null
var members = [
  { "name": "Bigfoot",    "available": true, "state": "READY", "scores": {"STR": 3, "DEX": 2, "INT": 2, "CHA": 1, "CON": 1}},
  { "name": "Mothman",    "available": true, "state": "READY", "scores": {"STR": 1, "DEX": 3, "INT": 2, "CHA": 2, "CON": 1}},
  { "name": "Gilledman",  "available": true, "state": "READY", "scores": {"STR": 1, "DEX": 1, "INT": 3, "CHA": 2, "CON": 2}},
  { "name": "Chupacabra", "available": true, "state": "READY", "scores": {"STR": 2, "DEX": 1, "INT": 1, "CHA": 3, "CON": 2}},
  { "name": "Nessie",     "available": true, "state": "READY", "scores": {"STR": 2, "DEX": 2, "INT": 1, "CHA": 1, "CON": 3}},
]

var UnitScene: PackedScene = preload("res://scenes/unit.tscn")
var MissionScene: PackedScene = preload("res://scenes/mission.tscn")

var mission_queue := [
	{
		"spawn_time": 2.0,
		"deadline": 20.0,
		"position": Vector2(-64, -40),
		"text": "Parece que os sacos de ra\u00e7\u00e3o acabaram mais r\u00e1pido essa semana. Precisamos de um carregamento emergencial antes que os ursos-coruja decidam mudar sua dieta.",
		"total_threshold": 6,
		"attr_thresholds": {"STR": 3},
	},
	{
		"spawn_time": 8.0,
		"deadline": 20.0,
		"position": Vector2(64, 32),
		"text": "Um viajante relatou ter visto luzes estranhas na floresta. Precisamos investigar antes que isso atraia curiosos indesejados.",
		"total_threshold": 5,
		"attr_thresholds": {"INT": 3},
	},
	{
		"spawn_time": 15.0,
		"deadline": 10.0,
		"position": Vector2(0, 48),
		"text": "Os aldeoes estao em panico. Um som gutural ecoa do pântano toda meia-noite. Alguem precisa ir convencer eles de que é inofensivo.",
		"total_threshold": 7,
		"attr_thresholds": {"CHA": 4},
	},
]

var _spawn_timers: Array = []

func _ready() -> void:
	ui.closed.connect(_on_ui_closed)
	ui.menu_opened.connect(_on_menu_opened)
	ui.send_pressed.connect(_on_send_pressed)
	for data in mission_queue:
		_spawn_timers.append({"remaining": data["spawn_time"], "data": data})
	set_process(true)

func _process(delta: float) -> void:
	for entry in _spawn_timers:
		entry["remaining"] -= delta
		if entry["remaining"] <= 0.0:
			_spawn_timers.erase(entry)
			_spawn_mission(entry["data"])
			return


func _spawn_mission(data: Dictionary) -> void:
	var mission := MissionScene.instantiate() as Mission
	mission.mission_text = data["text"]
	mission.total_score_threshold = data["total_threshold"]
	mission.attribute_thresholds = data["attr_thresholds"]
	mission.deadline_seconds = data["deadline"]
	mission.position = data["position"]
	missions_root.add_child(mission)
	mission.selected.connect(_on_mission_selected.bind(mission))
	

func _on_mission_selected(text: String, mission: Mission) -> void:
	_selected_mission = mission
	ui.show_mission(text)


func _on_menu_opened() -> void:
	get_tree().paused = true


func _on_ui_closed() -> void:
	_selected_mission = null
	get_tree().paused = false


func _on_send_pressed(unit_members: Array) -> void:
	get_tree().paused = false
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
	unit.returned_home.connect(_on_unit_returned_home.bind(unit.members, success))
	unit.go_home()


func _on_unit_returned_home(unit_members: Array, success: bool) -> void:
	var state := "RESTING" if success else "RECOVERING"
	var wait := rest_seconds if success else recover_seconds
	for m in unit_members:
		m["countdown"] = wait
	_set_member_states(unit_members, state)
	_tick_countdown(unit_members)


func _tick_countdown(unit_members: Array) -> void:
	get_tree().create_timer(1.0, false).timeout.connect(func():
		var any_left := false
		for m in unit_members:
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


func _set_member_states(unit_members: Array, state: String) -> void:
	for m in unit_members:
		m["state"] = state
		m["available"] = (state == "READY")
	member_availability_changed.emit()
	member_state_changed.emit()
