extends CanvasLayer
class_name UIOverlay

signal closed
signal send_pressed(members: Array)

@onready var menus: Control = $Menus
@onready var mission_menu: MissionMenu = $Menus/MarginContainer/VBoxContainer/MissionMenu

@onready var gui: MarginContainer = $GUI
@onready var members_container: VBoxContainer = $GUI/Members

var MemberUIScene: PackedScene = preload("res://scenes/member.tscn")

var _member_state_labels: Array = []

func _ready() -> void:
	hide_overlay_silent()
	
	mission_menu.send_pressed.connect(func(members): send_pressed.emit(members))
	var game: Node = get_tree().get_root().get_node("Game")
	for member in game.members:
		var node := MemberUIScene.instantiate()
		members_container.add_child(node)
		node.get_node("MemberLabel").text = member["name"]
		_member_state_labels.append(node.get_node("MemberState"))
	game.member_state_changed.connect(_refresh_member_states)
	_refresh_member_states()

func _refresh_member_states() -> void:
	var game: Node = get_tree().get_root().get_node("Game")
	for i in game.members.size():
		_member_state_labels[i].text = game.members[i]["state"]

func show_mission(text: String) -> void:
	menus.visible = true
	gui.visible = false
	mission_menu.show_mission(text)

func hide_overlay_silent() -> void:
	menus.visible = false
	gui.visible = true
	mission_menu.hide_mission()

func _on_back_button_pressed() -> void:
	hide_overlay_silent()
	closed.emit()
