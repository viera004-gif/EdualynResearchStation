extends RefCounted
## Small declarative contract, not a generic behavior engine.
var data: Dictionary
func read(path: String) -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(path))
	for key in ["slot", "mission_id", "version", "scene", "title_key", "objective_key", "completion_key", "dependency_graph", "available_tools", "failure_states", "valid_solution_states", "tutorial_level", "scaffolding_level"]:
		assert(data.has(key), "Mission definition missing: " + key)
func help_policy() -> Dictionary:
	if data.has("help_policy_path"):
		return JSON.parse_string(FileAccess.get_file_as_string(data.help_policy_path))
	return data.help_policy.duplicate(true)
