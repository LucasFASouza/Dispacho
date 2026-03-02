extends VBoxContainer
class_name MissionMenu

signal send_pressed(members: Array[Dictionary])
signal ok_pressed(mission: Mission)

@onready var mission_label: Label = $HBoxContainer/Mission
@onready var unit_selector: VBoxContainer = $HBoxContainer/UnitSelector
@onready var send_button: Button = $SendButton
@onready var player_scores: VBoxContainer = $HBoxContainer/PlayerScores
@onready var target_scores: VBoxContainer = $HBoxContainer/TargetScores

const ATTR_LABELS := {"STR": "Força", "DEX": "Destreza", "INT": "Inteligência", "CHA": "Carisma", "CON": "Constituição"}
const ATTR_MAX := 10
const AttContainerScene := preload("res://scenes/att_container.tscn")

var _att_containers: Dictionary = {}
var _current_mission: Mission = null
var _in_review: bool = false


func _ready() -> void:
	visible = false

func init_members(members: Array[Dictionary]) -> void:
	for member in members:
		var check := CheckButton.new()
		check.text = member["name"]
		check.toggled.connect(_update_scores.unbind(1))
		unit_selector.add_child(check)

	for attr in ATTR_LABELS:
		var container := AttContainerScene.instantiate()
		player_scores.add_child(container)
		container.setup(ATTR_LABELS[attr], ATTR_MAX)
		_att_containers[attr] = container

	var game: Node = get_tree().get_root().get_node("Game")
	game.member_availability_changed.connect(_refresh_checkboxes)
	_update_scores()


# --- Display ---

func show_active(mission: Mission) -> void:
	_in_review = false
	_current_mission = null

	mission_label.text = mission.mission_text
	unit_selector.visible = true
	target_scores.visible = false
	send_button.text = "Enviar"
	send_button.visible = true

	# rebuild player_scores containers (may have been freed by a previous review)
	for child in player_scores.get_children():
		child.queue_free()
	_att_containers.clear()
	for attr in ATTR_LABELS:
		var container := AttContainerScene.instantiate()
		player_scores.add_child(container)
		container.setup(ATTR_LABELS[attr], ATTR_MAX)
		_att_containers[attr] = container
	player_scores.visible = true

	for child in unit_selector.get_children():
		if child is CheckButton:
			child.button_pressed = false
	_update_scores()
	visible = true

func show_review(mission: Mission) -> void:
	_in_review = true
	_current_mission = mission

	var result_text: String
	if mission.expired:
		result_text = mission.missed_text
	elif mission.resolved_success:
		result_text = mission.success_text
	else:
		result_text = mission.fail_text
	mission_label.text = result_text if result_text != "" else mission.mission_text
	unit_selector.visible = false
	send_button.text = "OK"
	send_button.visible = true

	for child in player_scores.get_children():
		child.queue_free()
	for attr in ATTR_LABELS:
		var container := AttContainerScene.instantiate()
		player_scores.add_child(container)
		container.setup(ATTR_LABELS[attr], ATTR_MAX)
		container.set_score(mission.player_totals.get(attr, 0))
	player_scores.visible = true

	for child in target_scores.get_children():
		child.queue_free()
	for attr in ATTR_LABELS:
		var threshold: int = mission.attribute_thresholds.get(attr, 0)
		if threshold > 0:
			var container := AttContainerScene.instantiate()
			target_scores.add_child(container)
			container.setup(ATTR_LABELS[attr], ATTR_MAX)
			container.set_score(threshold)
	target_scores.visible = true

	visible = true

func hide_mission() -> void:
	visible = false


# --- Scores ---

func _update_scores() -> void:
	if _in_review:
		return
	var totals := {}
	for attr in ATTR_LABELS:
		totals[attr] = 0
	var game: Node = get_tree().get_root().get_node("Game")
	var children := unit_selector.get_children()
	for i in children.size():
		if (children[i] as CheckButton).button_pressed:
			for attr in ATTR_LABELS:
				totals[attr] += game.members[i]["scores"][attr]
	for attr in ATTR_LABELS:
		_att_containers[attr].set_score(totals[attr])

func _refresh_checkboxes() -> void:
	var game: Node = get_tree().get_root().get_node("Game")
	var children := unit_selector.get_children()
	for i in children.size():
		(children[i] as CheckButton).disabled = !game.members[i]["available"]
		if !game.members[i]["available"]:
			(children[i] as CheckButton).button_pressed = false
	_update_scores()


# --- Buttons ---

func _on_send_button_pressed() -> void:
	if _in_review:
		ok_pressed.emit(_current_mission)
		return

	var selected: Array[Dictionary] = []
	var game: Node = get_tree().get_root().get_node("Game")
	var children := unit_selector.get_children()

	for i in children.size():
		if (children[i] as CheckButton).button_pressed:
			selected.append(game.members[i])

	send_pressed.emit(selected)
