extends VBoxContainer

@onready var att_label: Label = $AttText/AttLabel
@onready var att_value: Label = $AttText/AttValue
@onready var att_bar: ProgressBar = $AttBar

func setup(label: String, max_value: int) -> void:
	att_label.text = label
	att_bar.max_value = max_value
	set_score(0)

func set_score(value: int) -> void:
	att_value.text = str(value)
	att_bar.value = value
