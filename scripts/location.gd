extends Node2D
class_name Location

@export var location_id: String = ""

var current_mission: Mission = null


func is_available() -> bool:
	return current_mission == null


func try_spawn(data: MissionData, mission_scene: PackedScene, deadline: float) -> Mission:
	if not is_available():
		return null
	var mission := mission_scene.instantiate() as Mission
	mission.init_from_data(data, deadline)
	add_child(mission)
	current_mission = mission
	mission.tree_exiting.connect(func(): current_mission = null)
	return mission
