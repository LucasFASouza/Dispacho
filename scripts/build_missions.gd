## Run this script (File > Run) to regenerate data/missions/*.tres from missions_new.json.
## After running, assign the .tres files to MissionQueueResource and Game in the Inspector.
## NOTE: queue.tres must be hand-authored — assign the desired starter missions via the Inspector.
@tool
extends EditorScript

const MISSIONS_JSON := "res://data/missions_new.json"
const OUTPUT_DIR := "res://data/missions/"


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

	var count := 0
	for d: Dictionary in json.data:
		var data := MissionData.new()
		data.id            = d.get("id", "")
		data.starter       = d.get("starter", false)
		data.mission_gravity = d.get("mission_gravity", 1)
		data.location      = d.get("location", "")
		data.mission_text  = d.get("mission_text", "")
		data.success_text  = d.get("success_text", "")
		data.error_text    = d.get("error_text", "")
		data.missed_text   = d.get("missed_text", "")
		data.success_cases = d.get("success_cases", [])
		data.in_success    = d.get("in_success", "")
		data.in_failure    = d.get("in_failure", "")

		var data_path := OUTPUT_DIR + data.id + ".tres"
		var err := ResourceSaver.save(data, data_path)
		if err != OK:
			push_error("Failed to save " + data_path)
			continue
		print("Saved ", data_path)
		count += 1

	print("Done. %d mission resources exported." % count)
	print("Next: open data/missions/queue.tres and assign starter missions + min/max wait in the Inspector.")
