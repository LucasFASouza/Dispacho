extends Resource
class_name MissionQueueResource

## Ordered list of starter missions to seed the queue at game start.
@export var entries: Array[MissionData] = []
@export var min_wait: float = 10.0
@export var max_wait: float = 30.0
