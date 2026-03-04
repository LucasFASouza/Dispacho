extends Node2D
class_name Unit

signal arrived
signal returned_home

@export var speed: float = 20.0 
@onready var label: Label = $Label

var _home_pos: Vector2
var _target_pos: Vector2
var _moving: bool = false
var _returning: bool = false
var members: Array = []

func _ready() -> void:
	_home_pos = global_position
	label.text = ", ".join(members.map(func(m): return m["name"]))

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

	var diff := _target_pos - global_position
	var step := speed * delta

	if abs(diff.x) > 0.5:
		global_position.x = move_toward(global_position.x, _target_pos.x, step)
	elif abs(diff.y) > 0.5:
		global_position.y = move_toward(global_position.y, _target_pos.y, step)
	else:
		global_position = _target_pos
		_moving = false
		set_process(false)

		if _returning:
			queue_free()
			returned_home.emit()
		else:
			arrived.emit()
