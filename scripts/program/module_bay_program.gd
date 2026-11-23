extends Node
## Local development completion flags only. No student model, scores or cloud save.
signal progression_changed
var catalog: Dictionary
var completed: Array[String] = []
var save_path := "user://module_bay_program_v01.json"
var save_error: int = OK
var locale := ""
var configuration_cursors: Dictionary = {}
func configure() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://config/module_bay_program.json"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--progress-file="):
			save_path = arg.trim_prefix("--progress-file=")
	if FileAccess.file_exists(save_path):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if saved is Dictionary and saved.get("schema_version") == 1:
			var cursors = saved.get("configuration_cursors", {})
			if cursors is Dictionary:
				configuration_cursors = cursors
			for slot in saved.get("completed", []):
				if entry(slot).get("implemented", false) and not slot in completed:
					completed.append(slot)
func entry(slot: String) -> Dictionary:
	for item in catalog.missions:
		if item.slot == slot:
			return item
	return {}
func available(slot: String) -> bool:
	var item := entry(slot)
	if not item.get("implemented", false):
		return false
	for required in item.requires:
		if not required in completed:
			return false
	return true
func complete(slot: String) -> void:
	if not available(slot) or slot in completed:
		return
	completed.append(slot)
	save_development_state()
	progression_changed.emit()
func next_configuration(slot: String, ids: Array) -> String:
	var cursor := maxi(0, int(configuration_cursors.get(slot, 0)))
	var id: String = ids[cursor % ids.size()]
	configuration_cursors[slot] = cursor + 1
	save_development_state()
	return id
func save_development_state() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	save_error = FileAccess.get_open_error()
	if file != null:
		file.store_string(JSON.stringify({"schema_version": 1, "program_id": catalog.program_id, "completed": completed, "configuration_cursors": configuration_cursors}, "\t"))
func enter(slot: String, current: Node) -> void:
	if not available(slot):
		return
	var definition = load("res://scripts/program/mission_definition.gd").new()
	definition.read(entry(slot).definition)
	# Keep unacknowledged evidence alive across scene changes, including API-down play.
	current.telemetry.record("mission_left", {"destination_slot": slot, "completed": current.phase == current.Phase.COMPLETE})
	current.telemetry.finished = true
	current.telemetry.detach_for_transition()
	get_tree().change_scene_to_file.call_deferred(definition.data.scene)
