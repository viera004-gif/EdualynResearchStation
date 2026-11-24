extends RefCounted
## Phase 1 deterministic evidence model. The renderer consumes a frozen result.

const CHANNEL := "BACKBONE"
const WITNESSES := ["A", "B_IN", "B_OUT", "C"]
const NODE_WITNESSES := {"A": "A", "B": "B_OUT", "C": "C"}

var mode := "NORMAL"
var tap := "HOLD"
var revision := 0
var next_pulse := 1

func set_mode(value: String) -> void:
	assert(value in ["NORMAL", "ISOLATED"])
	if mode != value:
		mode = value
		revision += 1

func set_tap(value: String) -> void:
	assert(value in ["HOLD", "LIVE"])
	if tap != value:
		tap = value
		revision += 1

func setup() -> Dictionary:
	return {"family_id": "A", "mode": mode, "tap": tap, "channel": CHANNEL, "revision": revision}

func launch() -> Dictionary:
	var snapshot := setup()
	snapshot["pulse_id"] = next_pulse
	next_pulse += 1
	return snapshot

func resolve(snapshot: Dictionary) -> Dictionary:
	var pulse_id: int = snapshot.pulse_id
	var channel: String = snapshot.channel
	var arrivals: Array[Dictionary] = []
	for witness in WITNESSES:
		arrivals.append({"witness": witness, "pulse_id": pulse_id, "channel": channel, "kind": "EXPECTED"})
	var reports := {}
	for node in NODE_WITNESSES:
		var held_sample: bool = node == "B" and snapshot.tap == "HOLD"
		reports[node] = {"pulse_id": 0 if held_sample else pulse_id, "channel": channel,
			"detected": not held_sample, "sample_state": "STALE" if held_sample else "CURRENT"}
	var result := {"launch": snapshot.duplicate(true), "arrivals": arrivals, "reports": reports}
	result["conflict_nodes"] = conflicts(result)
	result["normal_service_confirmed"] = confirms_service(result)
	return result

func conflicts(result: Dictionary) -> Array[String]:
	var differences: Array[String] = []
	for node in NODE_WITNESSES:
		var report: Dictionary = result.reports[node]
		var current := has_arrival(result, NODE_WITNESSES[node])
		if report.pulse_id != result.launch.pulse_id or report.channel != result.launch.channel or report.detected != current:
			differences.append(node)
	return differences

func has_arrival(result: Dictionary, witness: String) -> bool:
	for arrival in result.arrivals:
		if arrival.kind == "EXPECTED" and arrival.witness == witness and arrival.pulse_id == result.launch.pulse_id and arrival.channel == result.launch.channel:
			return true
	return false

func confirms_service(result: Dictionary) -> bool:
	if result.launch.mode != "NORMAL" or result.launch.tap != "LIVE" or not conflicts(result).is_empty():
		return false
	for witness in WITNESSES:
		if not has_arrival(result, witness):
			return false
	for arrival in result.arrivals:
		if arrival.kind == "UNEXPECTED" or arrival.channel != result.launch.channel:
			return false
	return true

func is_previous(result: Dictionary) -> bool:
	return result.launch.revision != revision

func confirms_current_service(result: Dictionary) -> bool:
	return not is_previous(result) and confirms_service(result)
