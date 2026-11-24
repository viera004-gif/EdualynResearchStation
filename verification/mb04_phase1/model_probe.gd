extends SceneTree

const Network := preload("res://scripts/intervention/mb04/signal_network.gd")
const Program := preload("res://scripts/program/module_bay_program.gd")

func _initialize() -> void:
	quit(0 if verify() and verify_legacy_save() else 1)

func verify_legacy_save() -> bool:
	var program := Program.new()
	program.save_path = "res://verification/phase2b/progress_independent_mb02.json"
	program.configure()
	var compatible := (program.completed == ["MB01", "MB02"] and program.configuration_cursors.is_empty() and
		program.available("MB03") and not program.available("MB04") and not program.available("MB05"))
	program.free()
	return check(compatible, "legacy schema-1 save without cursors remains compatible")

func verify() -> bool:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://verification/mb04_phase1/family_a_truth_table.json"))
	for row in table.rows:
		var model := Network.new()
		model.set_mode(row.mode)
		model.set_tap(row.tap)
		var result := model.resolve(model.launch())
		var arrivals: Array = result.arrivals.map(func(item): return item.witness)
		var unexpected: Array = result.arrivals.filter(func(item): return item.kind == "UNEXPECTED")
		var sample_ids: Array = ["A", "B", "C"].map(func(node): return result.reports[node].pulse_id)
		var detections: Array = ["A", "B", "C"].map(func(node): return result.reports[node].detected)
		if not check(arrivals == table.physical_witnesses and unexpected == table.unexpected_branch and
			result.launch.family_id == table.family_id and result.launch.channel == table.expected_channel and
			sample_ids == row.sample_ids.map(func(id): return int(id)) and detections == row.sample_detected and
			result.conflict_nodes == row.conflict_at and result.normal_service_confirmed == row.normal_service_confirmed,
			"%s %s" % [row.mode, row.tap]):
			return false
		var repeat := model.resolve(model.launch())
		if not check(repeat.launch.pulse_id == result.launch.pulse_id + 1 and
			repeat.conflict_nodes == result.conflict_nodes and repeat.normal_service_confirmed == result.normal_service_confirmed and
			repeat.arrivals.map(func(item): return item.witness) == arrivals and
			["A", "B", "C"].map(func(node): return repeat.reports[node].sample_state) ==
			["A", "B", "C"].map(func(node): return result.reports[node].sample_state),
			"identical setup produces the same evidence with a fresh identity"):
			return false
	var model := Network.new()
	var launch := model.launch()
	model.set_tap("LIVE")
	var old := model.resolve(launch)
	if not check(old.reports.B.pulse_id == 0 and old.launch.tap == "HOLD" and model.is_previous(old), "snapshot survives in-flight switch"):
		return false
	model.set_tap("HOLD")
	if not check(model.is_previous(old), "restoring old settings does not relabel an old test"):
		return false
	model.set_tap("LIVE")
	var current := model.resolve(model.launch())
	if not check(current.launch.pulse_id == 2 and current.normal_service_confirmed, "fresh corrected normal pulse"):
		return false
	var missing := current.duplicate(true)
	missing.arrivals.pop_back()
	missing.reports.C.detected = false
	var unexpected := current.duplicate(true)
	unexpected.arrivals.append({"witness": "C", "pulse_id": 2, "channel": "AUX", "kind": "UNEXPECTED"})
	if not check(not model.confirms_service(missing) and not model.confirms_service(unexpected), "missing or cross-channel arrival cannot confirm service"):
		return false
	var bypassed := current.duplicate(true)
	bypassed.launch.tap = "HOLD"
	if not check(not model.confirms_service(bypassed), "coherent sample cannot override a bypassed measurement tap"):
		return false
	model.set_tap("HOLD")
	var reverted := model.resolve(model.launch())
	if not check(not model.confirms_current_service(current) and current.reports.B.pulse_id == 2 and
		reverted.conflict_nodes == ["B"] and reverted.reports.B.sample_state == "STALE",
		"reversal restores conflict without rewriting the earlier receipt"):
		return false
	model.set_tap("LIVE")
	return check(not model.confirms_current_service(current) and model.confirms_current_service(model.resolve(model.launch())),
		"restoring the coupling still requires a new confirming test")

func check(condition: bool, label: String) -> bool:
	print("MB04 MODEL ", label, " = ", condition)
	return condition
