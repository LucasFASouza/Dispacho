extends Area2D
class_name Mission

signal selected(mission: Mission)
signal resolved(success: bool)

@export var mission_text := ""
@export var success_text: String = "Missão concluída com sucesso!"
@export var fail_text: String = "A missão falhou."
@export var missed_text: String = "Ninguém chegou a tempo."
@export var success_cases: Array = []
@export var mission_gravity: int = 1
@export var resolve_seconds: float = 5.0
@export var deadline_seconds: float = 30.0

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label

## Reference kept so game.gd can read in_success / in_failure on confirm
var source_data: MissionData = null

var _interactable := true
var _resolve_members: Array = []
var _resolve_countdown: float = 0.0
var _resolving: bool = false
var _deadline_countdown: float = 0.0
var _deadline_active: bool = false

var expired: bool = false
var done: bool = false
var resolved_success: bool = false
var player_totals: Dictionary = {}


func _ready() -> void:
	if deadline_seconds > 0:
		_deadline_countdown = deadline_seconds
		_deadline_active = true
		set_process(true)


func _process(delta: float) -> void:
	if _resolving:
		_resolve_countdown -= delta
		label.text = "..." + str(ceili(_resolve_countdown))
		if _resolve_countdown <= 0.0:
			_resolving = false
			set_process(false)
			_do_resolve()

	elif _deadline_active:
		_deadline_countdown -= delta
		label.text = "!" + str(ceili(_deadline_countdown))
		if _deadline_countdown <= 0.0:
			_deadline_active = false
			set_process(false)
			_on_deadline_expired()


# --- Public API ---

func init_from_data(data: MissionData, deadline: float) -> void:
	source_data    = data
	mission_text   = data.mission_text
	success_text   = data.success_text
	fail_text      = data.error_text
	missed_text    = data.missed_text
	success_cases  = data.success_cases
	mission_gravity  = data.mission_gravity
	deadline_seconds = deadline

func set_interactable(v: bool) -> void:
	_interactable = v
	input_pickable = v
	if collision:
		collision.disabled = !v

func start_resolve(members: Array) -> bool:
	if expired:
		return false
	_deadline_active = false
	_resolve_members = members
	_resolve_countdown = resolve_seconds
	_resolving = true
	set_process(true)
	return true

func confirm() -> void:
	queue_free()
	if not expired:
		resolved.emit(resolved_success)


# --- Resolution ---

func _on_deadline_expired() -> void:
	expired = true
	done = true
	resolved_success = false
	label.text = "X("
	resolved.emit(false)
	set_interactable(true)

func _do_resolve() -> void:
	var totals := {}
	for member in _resolve_members:
		for attr in member["scores"]:
			totals[attr] = totals.get(attr, 0) + member["scores"][attr]

	# OR logic: succeed if at least one case has all its attrs met
	var success := false
	for case in success_cases:
		var case_ok := true
		for attr in case:
			if totals.get(attr, 0) < case[attr]:
				case_ok = false
				break
		if case_ok:
			success = true
			break

	done = true
	resolved_success = success
	player_totals = totals
	label.text = ":D" if success else "X("
	set_interactable(true)


# --- Input ---

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if !_interactable:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(self)
