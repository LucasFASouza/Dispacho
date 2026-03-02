@tool
extends EditorScript

## Run this script from the Script editor (File > Run, or Ctrl+Shift+X) whenever
## missions.json changes. It reads the JSON and (re)generates all .tres files
## under res://data/missions/, then rebuilds queue.tres.

const MISSIONS_JSON := "res://data/missions.json"
const OUTPUT_DIR := "res://data/missions/"
const QUEUE_PATH := "res://data/missions/queue.tres"


func _run() -> void:
	var file := FileAccess.open(MISSIONS_JSON, FileAccess.READ)
	if file == null:
		push_error("Could not open " + MISSIONS_JSON)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Failed to parse " + MISSIONS_JSON)
		return
	file.close()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var queue := MissionQueueResource.new()

	for d: Dictionary in json.data:
		var data := MissionData.new()
		data.id             = d.get("id", "")
		data.mission_text   = d.get("mission_text", "")
		data.success_text   = d.get("success_text", "")
		data.error_text     = d.get("error_text", "")
		data.missed_text    = d.get("missed_text", "")
		data.attr_thresholds = d.get("attr_thresholds", {})

		var data_path := OUTPUT_DIR + data.id + ".tres"
		var err := ResourceSaver.save(data, data_path)
		if err != OK:
			push_error("Failed to save " + data_path)
			continue
		print("Saved ", data_path)

		var entry := MissionQueueEntry.new()
		entry.data       = load(data_path)
		entry.spawn_time = d.get("spawn_time", 2.0)
		entry.deadline   = d.get("deadline", 30.0)
		entry.location_id = d.get("location", "")
		queue.entries.append(entry)

	var queue_err := ResourceSaver.save(queue, QUEUE_PATH)
	if queue_err != OK:
		push_error("Failed to save " + QUEUE_PATH)
	else:
		print("Saved ", QUEUE_PATH)

	print("Done. %d missions exported." % queue.entries.size())
