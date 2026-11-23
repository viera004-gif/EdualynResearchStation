extends "res://scripts/verification/run_probe.gd"
func pause(seconds: float) -> void:
	await bay.get_tree().create_timer(seconds).timeout
func run(world: Node) -> void:
	bay = world
	await pause(1)
	check(bay.program.available("MB01") and not bay.program.available("MB02"), "initial_availability")
	await aim(Vector3(-3.5, 0, 1.2), bay.operations_console.global_position + Vector3(0, 1.5, .16))
	check(bay.player.target() == bay.operations_console, "physical_operations_console")
	await action("interact")
	check(bay.definition.data.slot == "MB01", "locked_mission_cannot_launch")
	await aim(Vector3(-1.35, 0, -2.1), bay.cooling.global_position + Vector3(0, 1.4, .3))
	await action("interact")
	await pause(1)
	await aim(Vector3(0, 0, -2.1), bay.relay.global_position + Vector3(0, 1.4, .3))
	await action("interact")
	await pause(.7)
	await aim(Vector3(-1.7, 0, 1.45), bay.module.global_position + Vector3(0, .18, 0))
	await action("interact")
	await action("rotate_right")
	await pause(.3)
	await aim(Vector3(2.05, 0, .1), bay.correct_socket.global_position + Vector3(0, .11, 0))
	await action("place")
	await pause(5)
	check(bay.phase == bay.Phase.COMPLETE and bay.program.available("MB02"), "completion_only_unlock")
	check(bay.history.help_requests == 0, "no_performance_or_help_gate")
	check(bay.program.save_error == OK, "progress_written")
	var restored = load("res://scripts/program/module_bay_program.gd").new()
	restored.configure()
	check(restored.available("MB02") and not restored.available("MB03"), "persisted_unlock_and_reserved_slots")
	restored.free()
	bay.localization.set_locale("en")
	var transport = bay.telemetry
	var tree: SceneTree = bay.get_tree()
	# RefCounted probes normally belong to the outgoing scene. Retain this one
	# under the root so its coroutine survives the physical scene transition.
	var anchor := Node.new()
	anchor.name = "ProgressionProbeAnchor"
	anchor.set_meta("probe", self)
	tree.root.add_child(anchor)
	await aim(Vector3(-3.5, 0, 1.2), bay.operations_console.global_position + Vector3(0, 1.5, .16))
	# Hold the SceneTree, not the outgoing scene, while deferred scene change runs.
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await tree.process_frame
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	await tree.create_timer(2).timeout
	bay = tree.current_scene
	check(bay.definition.data.slot == "MB02", "physical_transition_to_mb02")
	check(bay.localization.locale == "en", "locale_retained_between_missions")
	check(transport.get_parent() == tree.root and transport.pending.size() > 0, "offline_evidence_survives_transition")
	check(transport.archive.back().event_type == "mission_completed", "completed_trace_boundary_retained")
	transport.export_trace("res://verification/phase2b/telemetry_transition_mb01.json")
	report["all_gameplay_checks_passed"] = not failed
	var file := FileAccess.open("res://verification/phase2b/progression.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	tree.quit(2 if failed else 0)
