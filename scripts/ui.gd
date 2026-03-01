extends CanvasLayer
class_name UIOverlay

signal closed
signal send_pressed(members: Array)

@onready var mission_menu: MissionMenu = $MarginContainer/VBoxContainer/MissionMenu
\
func _ready() -> void:
	hide_overlay_silent()
	mission_menu.send_pressed.connect(func(members): send_pressed.emit(members))

func show_mission(text: String) -> void:
	visible = true
	mission_menu.show_mission(text)

func hide_overlay_silent() -> void:
	visible = false
	mission_menu.hide_mission()

func _on_back_button_pressed() -> void:
	hide_overlay_silent()
	closed.emit()
