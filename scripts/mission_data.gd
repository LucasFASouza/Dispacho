extends Resource
class_name MissionData

@export var id: String = ""
@export_multiline var mission_text: String = ""
@export_multiline var success_text: String = ""
@export_multiline var error_text: String = ""
@export_multiline var missed_text: String = ""
@export var attr_thresholds: Dictionary = {}
