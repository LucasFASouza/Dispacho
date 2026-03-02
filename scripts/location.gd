extends Node2D
class_name Location

@export var location_id: String = ""

var current_mission: Mission = null


func is_available() -> bool:
	return current_mission == null


func try_spawn(entry: MissionQueueEntry, mission_scene: PackedScene) -> Mission:
	if not is_available():
		return null
	var mission := mission_scene.instantiate() as Mission
	mission.init_from_resource(entry)
	add_child(mission)
	current_mission = mission
	mission.tree_exiting.connect(func(): current_mission = null)
	return mission
