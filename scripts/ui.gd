extends CanvasLayer
class_name UIOverlay

signal closed
signal send_pressed

@onready var bg: ColorRect = $BG
@onready var mission_container: VBoxContainer = $MarginContainer/VBoxContainer/MissionContainer
@onready var mission_label: Label = $MarginContainer/VBoxContainer/MissionContainer/Mission
@onready var send_button: Button = $MarginContainer/VBoxContainer/MissionContainer/SendButton

func _ready():
	hide_overlay_silent()
	send_button.pressed.connect(_on_send_button_pressed)

func show_mission(text: String) -> void:
	visible = true
	bg.visible = true
	mission_container.visible = true
	mission_label.text = text

func hide_overlay_silent() -> void:
	visible = false
	bg.visible = false
	mission_container.visible = false

func _on_back_button_pressed() -> void:
	hide_overlay_silent()
	closed.emit()

func _on_send_button_pressed() -> void:
	send_pressed.emit()
