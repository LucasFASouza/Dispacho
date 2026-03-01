extends Area2D
class_name Mission

signal selected(text: String)

@export var mission_text := "Parece que os sacos de ração acabaram mais rápido essa semana. Precisamos de um carregamento emergencial antes que os ursos-coruja decidam mudar sua dieta.\nTomem cuidado, os sacos podem ser pesados, e podem atrair atenção indesejada de seres acima."
@export var total_score_threshold: int = 18
@export var attribute_thresholds: Dictionary = {}

@onready var collision: CollisionShape2D = $CollisionShape2D

var _interactable := true

func set_interactable(v: bool) -> void:
	_interactable = v
	input_pickable = v
	if collision:
		collision.disabled = !v

func resolve(members: Array) -> void:
	var totals := {}
	for member in members:
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

	if success:
		print("SUCCESS: ", mission_text.substr(0, 30), "...")
	else:
		print("FAIL: ", mission_text.substr(0, 30), "...")

	queue_free()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if !_interactable:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(mission_text)
