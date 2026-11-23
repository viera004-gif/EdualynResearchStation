extends Node
# Prototype task-action bookkeeping, NOT construct inference or behavioral scoring.
var parameters: Dictionary
var last_signature: Dictionary = {}
var last_invalid_signature: Dictionary = {}
var last_failure_uuid := ""
var changed_since_failure: bool = false
var exact_repeats: int = 0
var invalid_attempts: int = 0
var exploration_actions: int = 0
var help_requests: int = 0
var last_progress_ms: int = 0
var last_change_candidate := ""
var running: bool = false
func configure(config: Dictionary) -> void:
	parameters = config
func start() -> void:
	running = true
	last_progress_ms = Time.get_ticks_msec()
func signature(family: String, object_id: String, target_id: String, orientation: int = -1, subsystem: String = "", tool: String = "") -> Dictionary:
	return {"action_family": family, "object_id": object_id, "target_id": target_id,
		"orientation_bucket": orientation, "subsystem_id": subsystem, "tool_id": tool}
func observe(value: Dictionary) -> void:
	last_signature = value.duplicate(true)
	last_change_candidate = "ACTION_CHANGED"
	if not last_invalid_signature.is_empty() and value != last_invalid_signature:
		changed_since_failure = true
	if value == last_invalid_signature:
		last_change_candidate = "EXACT_REPEAT"
	elif value.action_family == "help":
		last_change_candidate = "HELP_REQUEST"
	elif value.tool_id == "DIAGNOSTIC_SCANNER":
		last_change_candidate = "TOOL_USE"
	elif value.action_family == "inspect":
		last_change_candidate = "INFORMATION_SEEK"
	elif not last_invalid_signature.is_empty() and value.subsystem_id != last_invalid_signature.subsystem_id:
		last_change_candidate = "SUBSYSTEM_SWITCH"
	elif not last_invalid_signature.is_empty() and value.target_id != last_invalid_signature.target_id:
		last_change_candidate = "TARGET_CHANGE"
	elif not last_invalid_signature.is_empty() and value.orientation_bucket != last_invalid_signature.orientation_bucket:
		last_change_candidate = "PARAMETER_ADJUSTMENT"
func invalid(value: Dictionary, uuid: String) -> void:
	invalid_attempts += 1
	if value == last_invalid_signature and not changed_since_failure:
		exact_repeats += 1
	else:
		exact_repeats = 0
	last_invalid_signature = value.duplicate(true)
	last_failure_uuid = uuid
	changed_since_failure = false
func progress() -> void:
	last_progress_ms = Time.get_ticks_msec()
	exact_repeats = 0
	last_invalid_signature.clear()
	changed_since_failure = false
func repetition_nudge_due() -> bool:
	return running and exact_repeats >= int(parameters.exact_repeat_nudge_count)
func no_progress_due() -> bool:
	return running and Time.get_ticks_msec() - last_progress_ms >= float(parameters.prolonged_no_progress_seconds) * 1000.0
func level_for_next_request() -> int:
	# Separate policy hook: future reviewed policies can replace this selection only.
	if help_requests >= int(parameters.level3_after_help_requests):
		return 3
	if help_requests >= int(parameters.level2_after_help_requests):
		return 2
	return 1
