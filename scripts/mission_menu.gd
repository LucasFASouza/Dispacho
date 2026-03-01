extends VBoxContainer
class_name MissionMenu

signal send_pressed(members: Array)

@onready var mission_label: Label = $HBoxContainer/Mission
@onready var unit_selector: VBoxContainer = $HBoxContainer/UnitSelector
@onready var send_button: Button = $SendButton
@onready var scores_bars: VBoxContainer = $HBoxContainer/ScoresBars

const ATTR_LABELS := {"STR": "Força", "DEX": "Destreza", "INT": "Intelecto", "CHA": "Carisma", "CON": "Constituição"}
const ATTR_MAX := 20
const AttContainerScene := preload("res://scenes/att_container.tscn")

var _att_containers: Dictionary = {}

func _ready() -> void:
	send_button.pressed.connect(_on_send_button_pressed)
	visible = false
	var game: Node = get_tree().get_root().get_node("Game")

	for member in game.members:
		var check := CheckButton.new()
		check.text = member["name"]
		check.toggled.connect(_update_scores.unbind(1))
		unit_selector.add_child(check)

	for attr in ATTR_LABELS:
		var container := AttContainerScene.instantiate()
		scores_bars.add_child(container)
		container.setup(ATTR_LABELS[attr], ATTR_MAX)
		_att_containers[attr] = container
	game.member_availability_changed.connect(_refresh_checkboxes)
	_update_scores()

func _update_scores() -> void:
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

func show_mission(text: String) -> void:
	mission_label.text = text
	for child in unit_selector.get_children():
		if child is CheckButton:
			child.button_pressed = false
	_update_scores()
	visible = true

func _refresh_checkboxes() -> void:
	var game: Node = get_tree().get_root().get_node("Game")
	var children := unit_selector.get_children()
	for i in children.size():
		(children[i] as CheckButton).disabled = !game.members[i]["available"]
		if !game.members[i]["available"]:
			(children[i] as CheckButton).button_pressed = false
	_update_scores()

func hide_mission() -> void:
	visible = false

func _on_send_button_pressed() -> void:
	var selected := []
	var game: Node = get_tree().get_root().get_node("Game")
	var children := unit_selector.get_children()
	for i in children.size():
		if (children[i] as CheckButton).button_pressed:
			selected.append(game.members[i])
	send_pressed.emit(selected)
