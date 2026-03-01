extends Area2D
class_name Unit

signal arrived
signal returned_home

@export var speed: float = 40.0  # ajuste como quiser (px/s)

var _home_pos: Vector2
var _target_pos: Vector2
var _moving: bool = false
var _returning: bool = false

func _ready() -> void:
	_home_pos = global_position

func go_to(world_pos: Vector2) -> void:
	_target_pos = world_pos
	_moving = true
	_returning = false
	set_process(true)

func go_home() -> void:
	_target_pos = _home_pos
	_moving = true
	_returning = true
	set_process(true)

func _process(delta: float) -> void:
	if !_moving:
		set_process(false)
		return

	global_position = global_position.move_toward(_target_pos, speed * delta)

	if global_position.distance_to(_target_pos) <= 0.5:
		global_position = _target_pos
		_moving = false
		set_process(false)

		if _returning:
			returned_home.emit()
		else:
			arrived.emit()
