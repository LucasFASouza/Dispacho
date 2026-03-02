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
  { "name": "Bigfoot",    "available": true, "state": "READY", "scores": {"STR": 3, "DEX": 2, "INT": 1, "CHA": 1, "CON": 0}},
  { "name": "Mothman",    "available": true, "state": "READY", "scores": {"STR": 0, "DEX": 3, "INT": 2, "CHA": 1, "CON": 1}},
  { "name": "Gilledman",  "available": true, "state": "READY", "scores": {"STR": 1, "DEX": 0, "INT": 3, "CHA": 2, "CON": 1}},
  { "name": "Chupacabra", "available": true, "state": "READY", "scores": {"STR": 1, "DEX": 1, "INT": 0, "CHA": 3, "CON": 2}},
  { "name": "Nessie",     "available": true, "state": "READY", "scores": {"STR": 2, "DEX": 1, "INT": 1, "CHA": 0, "CON": 3}},
]

var UnitScene: PackedScene = preload("res://scenes/unit.tscn")
var MissionScene: PackedScene = preload("res://scenes/mission.tscn")

var mission_queue := [
	{
		"spawn_time": 2.0,
		"deadline": 20.0,
		"position": Vector2(-64, -40),
		"mission_text": "Parece que os sacos de ra\u00e7\u00e3o acabaram mais r\u00e1pido essa semana. Precisamos de um carregamento emergencial antes que os ursos-coruja decidam mudar sua dieta. Tomem cuidado, os sacos podem ser pesados, e podem atrair atenção indesejada de seres acima.",
		"success_text": "Os ursos-corujas terão seu jantar garantido pelos próximos dias.",
		"error_text": "Parece que a carga foi derrubada pelo caminho... Alguém sabe se os ursos-coruja fazem dieta?",
		"missed_text": "Parece que os ursos-coruja foram atrás de seu próprio jantar. Atenção aos salmões e sementes de girassol.",
		"attr_thresholds": {"STR": 3, "DEX": 2},
	},
	{
		"spawn_time": 10.0,
		"deadline": 20.0,
		"position": Vector2(64, 32),
		"mission_text": "Um ouriço azul está preso em cima de uma árvore. Ele parece estar com medo de descer. Precisamos de alguém para acalmá-lo e ajudá-lo a descer em segurança.",
		"success_text": "O ouriço foi salvo e saiu correndo... estranhamento rápido.",
		"error_text": "O ouriço foi assustado e entrou em super-nova. Ele não é mais um problema, mas também não é mais um ouriço.",
		"missed_text": "O ouriço não conseguiu se segurar e acabou caindo. Achamos apenas alguns aneis no chão, deveríamos nos preocupar?",
		"attr_thresholds": {"CHA": 3, "CON": 2},
	},
	{
		"spawn_time": 18.0,
		"deadline": 20.0,
		"position": Vector2(0, 48),
		"mission_text": "O som de goblins chorando por não conseguirem resolver cubos-mágicos está incomodando a fauna local. Como foi que eles conseguiram os cubos, aliás?",
		"success_text": "O algoritmo de resolução de cubos-mágicos foi ensinado didáticamente. Paulo Freire estaria orgulhoso.",
		"error_text": "Aparentemente aqueles objetos geométricos mágicos são difíceis de resolver para uma grande gama de espécies.",
		"missed_text": "O silêncio repentino e peças coloridas flutuando no rio indicam que os goblins encontraram uma solução alternativa.",
		"attr_thresholds": {"INT": 3, "CHA": 2},
	}
]

var _spawn_timers: Array = []

func _ready() -> void:
	ui.closed.connect(_on_ui_closed)
	ui.menu_opened.connect(_on_menu_opened)
	ui.send_pressed.connect(_on_send_pressed)
	ui.ok_pressed.connect(_on_ok_pressed)
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
	mission.mission_text = data["mission_text"]
	mission.success_text = data.get("success_text", "")
	mission.fail_text = data.get("error_text", "")
	mission.missed_text = data.get("missed_text", "")
	mission.attribute_thresholds = data["attr_thresholds"]
	mission.deadline_seconds = data["deadline"]
	mission.position = data["position"]
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
