extends Area2D
class_name Mission

signal selected(text: String)

@export var mission_text := "Parece que os sacos de ração acabaram mais rápido essa semana. Precisamos de um carregamento emergencial antes que os ursos-coruja decidam mudar sua dieta.\nTomem cuidado, os sacos podem ser pesados, e podem atrair atenção indesejada de seres acima."
@export var total_score_threshold: int = 18
@export var attribute_thresholds: Dictionary = {}
@export var resolve_seconds: float = 3.0
@export var feedback_seconds: float = 2.0

signal resolved(success: bool)

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label

var _interactable := true
var _resolve_members: Array = []
var _countdown: float = 0.0
var _resolving: bool = false

func set_interactable(v: bool) -> void:
	_interactable = v
	input_pickable = v
	if collision:
		collision.disabled = !v
	
	if !v:
		label.text = "..."

func start_resolve(members: Array) -> void:
	_resolve_members = members
	_countdown = resolve_seconds
	_resolving = true
	set_process(true)

func _process(delta: float) -> void:
	if not _resolving:
		return
	_countdown -= delta
	label.text = str(ceili(_countdown))
	if _countdown <= 0.0:
		_resolving = false
		set_process(false)
		_do_resolve()

func _do_resolve() -> void:
	var totals := {}
	for member in _resolve_members:
		for attr in member["scores"]:
			totals[attr] = totals.get(attr, 0) + member["scores"][attr]

	var total := 0
	for attr in totals:
		total += totals[attr]

	var success := total >= total_score_threshold
	if success:
		for attr in attribute_thresholds:
			if totals.get(attr, 0) < attribute_thresholds[attr]:
				success = false
				break

	label.text = ":D" if success else "X("
	get_tree().create_timer(feedback_seconds).timeout.connect(queue_free)
	resolved.emit(success)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if !_interactable:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(mission_text)
