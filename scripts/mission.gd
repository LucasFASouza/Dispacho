extends Area2D
class_name Mission

signal selected(text: String)

@export var mission_text := "Parece que os sacos de ração acabaram mais rápido essa semana. Precisamos de um carregamento emergencial antes que os ursos-coruja decidam mudar sua dieta.\nTomem cuidado, os sacos podem ser pesados, e podem atrair atenção indesejada de seres acima."

@onready var _collision: CollisionShape2D = $CollisionShape2D

var _interactable := true

func set_interactable(v: bool) -> void:
	_interactable = v
	# garante que não vai receber clique nem por shape nem por picking
	input_pickable = v
	if _collision:
		_collision.disabled = !v

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if !_interactable:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(mission_text)
