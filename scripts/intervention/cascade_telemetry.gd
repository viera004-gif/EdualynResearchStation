extends "res://scripts/telemetry/telemetry.gd"
var context_provider: Callable
const CONTENT_ID := "MODULE_BAY_01_POWER_COUPLING_CASCADE_V02"
var content_id := CONTENT_ID
var app_version := "research_station_v0_2"
var game_version := "power_coupling_cascade_v0_2"
var detached := false
func record(kind: String, metadata: Dictionary = {}, object_id = null, target_id = null) -> void:
	# mission_completed is the evidence boundary; do not orphan post-completion
	# events in an already closing/closed API session during free room exploration.
	if finished:
		return
	var context: Dictionary = context_provider.call() if context_provider.is_valid() else {}
	context.merge(metadata, true)
	var entry := {"event_uuid": uuid(), "event_index": next_index, "event_type": kind,
		"client_monotonic_ms": float(Time.get_ticks_msec()), "mission_id": content_id,
		"object_id": object_id, "target_id": target_id, "metadata": context.duplicate(true)}
	next_index += 1
	pending.append(entry)
	archive.append(entry.duplicate(true))
	print("RAW_EVENT ", kind, " index=", entry.event_index)
func send_request(path: String, payload: Dictionary, kind: String) -> void:
	var body := payload.duplicate(true)
	if kind == "session":
		body.session_purpose = "intervention"
		body.app_version = app_version
		body.game_version = game_version
	super.send_request(path, body, kind)
func detach_for_transition() -> void:
	context_provider = Callable()
	detached = true
	reparent(get_tree().root)
func _process(delta: float) -> void:
	super._process(delta)
	if detached and session_closed:
		queue_free()
