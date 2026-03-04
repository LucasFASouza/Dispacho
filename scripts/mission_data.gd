extends Resource
class_name MissionData

@export var id: String = ""
@export var starter: bool = false
@export var mission_gravity: int = 1
@export var location: String = ""
@export_multiline var mission_text: String = ""
@export_multiline var success_text: String = ""
@export_multiline var error_text: String = ""
@export_multiline var missed_text: String = ""
## Each element is one AND-condition; resolution succeeds if ANY passes (OR logic)
@export var success_cases: Array = []
@export var in_success: String = ""
@export var in_failure: String = ""
