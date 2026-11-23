extends Node
var base_url := "http://127.0.0.1:8000/api/v2/research-station"
var session_uuid := ""
var pending: Array[Dictionary] = []
var quarantined: Dictionary = {}
var archive: Array[Dictionary] = []
var next_index: int = 0
var request_node: HTTPRequest
var busy: bool = false
var operation := ""
var retry_after: float = 0
var finished: bool = false
var session_closed: bool = false
var acknowledged: int = 0
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--api-base="):
			base_url = arg.trim_prefix("--api-base=")
	request_node = HTTPRequest.new()
	request_node.timeout = 3.0
	add_child(request_node)
	request_node.request_completed.connect(on_completed)
func uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
func record(kind: String, metadata: Dictionary = {}, object_id = null, target_id = null) -> void:
	var entry := {"event_uuid": uuid(), "event_index": next_index, "event_type": kind,
		"client_monotonic_ms": float(Time.get_ticks_msec()), "mission_id": "MODULE_BAY_01",
		"object_id": object_id, "target_id": target_id, "metadata": metadata.duplicate(true)}
	next_index += 1
	pending.append(entry)
	archive.append(entry.duplicate(true))
	print("RAW_EVENT ", kind, " index=", entry.event_index)
func send_request(path: String, payload: Dictionary, kind: String) -> void:
	busy = true
	operation = kind
	var error := request_node.request(base_url + path, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		busy = false
		retry_after = 2
func _process(delta: float) -> void:
	retry_after = maxf(0, retry_after - delta)
	if busy or retry_after > 0 or session_closed:
		return
	if session_uuid.is_empty():
		send_request("/sessions", {"student_id": 1, "session_purpose": "practice", "client_platform": "windows",
			"app_version": "research_station_v0_1", "game_version": "module_bay_01_v0_1"}, "session")
	elif not pending.is_empty():
		var batch: Array[Dictionary] = []
		for entry in pending:
			if not quarantined.has(entry.event_uuid):
				batch.append(entry)
			if batch.size() == 64:
				break
		if not batch.is_empty():
			send_request("/sessions/" + session_uuid + "/events:batch", {"events": batch}, "events")
	elif finished:
		send_request("/sessions/" + session_uuid + "/complete", {}, "complete")
func on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		retry_after = 2
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		retry_after = 2
		return
	if operation == "session":
		session_uuid = str(parsed.get("session_uuid", ""))
	elif operation == "events":
		var ids: Dictionary = {}
		for entry in parsed.get("results", []):
			if entry.get("status") in ["accepted", "already_accepted"]:
				ids[entry.event_uuid] = true
			else:
				quarantined[entry.get("event_uuid", "")] = entry
		var remaining: Array[Dictionary] = []
		for entry in pending:
			if ids.has(entry.event_uuid):
				acknowledged += 1
			else:
				remaining.append(entry)
		pending = remaining
	elif operation == "complete":
		session_closed = true
		print("TELEMETRY_SESSION_COMPLETE acknowledged=", acknowledged)
func export_trace(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"events": archive, "pending": pending, "quarantined": quarantined,
			"acknowledged": acknowledged, "session_uuid": session_uuid, "completed": session_closed}, "\t"))
