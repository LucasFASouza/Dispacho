extends VBoxContainer
class_name MissionMenu

signal send_pressed(members: Array)

@onready var mission_label: Label = $HBoxContainer/Mission
@onready var unit_selector: VBoxContainer = $HBoxContainer/UnitSelector
@onready var send_button: Button = $SendButton

func _ready() -> void:
	send_button.pressed.connect(_on_send_button_pressed)
	visible = false
	var game: Node = get_tree().get_root().get_node("Game")
	for member in game.members:
		var check := CheckButton.new()
		check.text = member["name"]
		unit_selector.add_child(check)
	game.member_availability_changed.connect(_refresh_checkboxes)

func show_mission(text: String) -> void:
	mission_label.text = text

	for child in unit_selector.get_children():
		if child is CheckButton:
			child.button_pressed = false

	visible = true

func _refresh_checkboxes() -> void:
	var game: Node = get_tree().get_root().get_node("Game")
	var children := unit_selector.get_children()
	for i in children.size():
		(children[i] as CheckButton).disabled = !game.members[i]["available"]
		if !game.members[i]["available"]:
			(children[i] as CheckButton).button_pressed = false

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
