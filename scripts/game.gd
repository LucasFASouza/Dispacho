extends Node2D

@onready var ui: UIOverlay = $UI
@onready var missions_root: Node2D = $Missions
@onready var unit: Unit = $Units/Unit

@export var resolve_seconds: float = 1.5

var _selected_mission: Mission = null
var _busy: bool = false

func _ready() -> void:
	# Conecta cada missão passando a própria missão como argumento extra (bind)
	for n in missions_root.get_children():
		if n is Mission:
			(n as Mission).selected.connect(_on_mission_selected.bind(n))

	ui.closed.connect(_on_ui_closed)
	ui.send_pressed.connect(_on_send_pressed)

	unit.arrived.connect(_on_unit_arrived)
	unit.returned_home.connect(_on_unit_returned_home)

func _on_mission_selected(text: String, mission: Mission) -> void:
	if _busy:
		return
	_selected_mission = mission
	ui.show_mission(text)

func _on_ui_closed() -> void:
	_selected_mission = null

func _on_send_pressed() -> void:
	if _busy:
		return
	if _selected_mission == null or !is_instance_valid(_selected_mission):
		return

	_busy = true
	ui.hide_overlay_silent()

	_selected_mission.set_interactable(false)
	unit.go_to(_selected_mission.global_position)

func _on_unit_arrived() -> void:
	# chegou: espera, remove missão, volta
	if _selected_mission != null and is_instance_valid(_selected_mission):
		await get_tree().create_timer(resolve_seconds).timeout
		_selected_mission.queue_free()

	_selected_mission = null
	unit.go_home()

func _on_unit_returned_home() -> void:
	_busy = false
