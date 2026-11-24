extends "res://verification/phase2b/polarity_probe.gd"

func count_events(kind: String) -> int:
	return bay.telemetry.archive.filter(func(event): return event.event_type == kind).size()

func capture_state(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(bay.get_viewport().get_texture().get_image().save_png(
		"res://.cache/mb02_refinement_%s_%s.png" % [selected, label]) == OK, "capture_" + label)

func test_fault(state: String, location: String) -> void:
	await face(bay.route_tester, Vector3(-2.2, 0, -2.05), Vector3(0, 1.25, .3))
	check(bay.route_tester.prompt() == "polarity.test_prompt", "contactor_contextual_use")
	await action("interact")
	await pause(.53)
	check(bay.last_test.configuration == state and bay.last_test.failure_location == location and
		bay.route_tester.status_key == "polarity.failure." + state, "test_" + state)
	var unit: Node = bay.relay_a if location == "RELAY_A" else bay.relay_b
	var other: Node = bay.relay_b if unit == bay.relay_a else bay.relay_a
	check(unit.contact_faces.size() == 2 and unit.contact_faces[0].emission_energy_multiplier > .5 and
		other.contact_faces[0].emission_energy_multiplier == 0.0, "location_" + state)
	if location == "RELAY_B":
		check(bay.routes.find_child("SourceFeedFlow", true, false).material_override.emission_energy_multiplier > 1.0,
			"live_source_feed_reaches_b")
		await aim(Vector3(-.96, 0, -1.68), Vector3(-.96, 1.42, -3.60))
	await capture_state(state)
	await pause(.08)

func run(world: Node) -> void:
	bay = world
	selected = bay.localization.locale
	var use_support := (selected == "tr") != ("--mb02-swap-support" in OS.get_cmdline_user_args())
	if bay.language_selector.opened:
		await action("language")
	check(bay.program.available("MB02") and "MB01" in bay.program.completed, "unlocked_by_actual_mb01_completion")
	check(bay.module.state == bay.module.State.PLACED and bay.terminal.screen.text ==
		bay.localization.text("mission.relay_polarity.terminal_offline"), "seated_module_and_continuity_status")
	check(bay.route_tester.status_key == "polarity.source_ready" and bay.ai_station.screen.text ==
		bay.localization.text("polarity.support_standby"), "tester_ready_support_quiet")
	check(not bay.definition.data.show_controls_footer and bay.tutorial_label.text.is_empty(), "no_carryover_control_footer")
	# Measure from the same camera as the archived Phase 2B profile.
	await aim(Vector3(0, 0, 2.4), Vector3(0, 1.5, -3.5))
	await capture_state("entry")
	for unit in [bay.relay_a, bay.relay_b]:
		var signs := unit.find_children("*Positive*", "MeshInstance3D", true, false) as Array
		check(signs.size() >= 4 and signs[0].scale.length() > 1.9, "enlarged_polarity_" + unit.interaction_id)
	await test_fault("BOTH_RELAYS_MISMATCHED", "RELAY_A")
	await test_fault("BOTH_RELAYS_MISMATCHED", "RELAY_A")
	if use_support:
		await help()
		check(bay.delivered_tier == 1, "initial_help_l1")
		await help()
		await help()
		check(bay.delivered_tier == 1, "repeat_requests_hold_l1")
		await face(bay.scanner, Vector3(-3.2, 0, 2.9), Vector3(0, .2, 0))
		await action("interact")
		await scan(bay.relay_a, "polarity.scan_a_mismatch")
		await scan(bay.relay_a, "polarity.scan_unchanged")
		await help()
		check(bay.delivered_tier == 2, "new_observation_allows_l2")
		await scan(bay.relay_a, "polarity.scan_unchanged")
		await help()
		check(bay.delivered_tier == 2, "unchanged_scan_cannot_escalate")
	await turn(bay.relay_b, 1)
	check(bay.test_stale and bay.route_tester.status_key == "polarity.test_stale" and
		bay.last_test.configuration == "BOTH_RELAYS_MISMATCHED", "last_result_retained_current_marked_untested")
	await face(bay.route_tester, Vector3(-2.2, 0, -2.05), Vector3(0, 1.25, .3))
	await action("inspect")
	check(bay.route_tester.status_key == "polarity.test_stale", "inspect_does_not_overwrite_tester")
	await turn(bay.relay_b, 1)
	await test_fault("INPUT_BLOCKED_AT_A", "RELAY_A")
	await turn(bay.relay_b, -1)
	await turn(bay.relay_a, 1)
	await turn(bay.relay_a, 1)
	await test_fault("PHASE_COLLAPSE_AT_B", "RELAY_B")
	if use_support:
		await scan(bay.relay_a, "polarity.scan_a_stable")
		await scan(bay.relay_a, "polarity.scan_unchanged")
		await help()
		check(bay.delivered_tier == 3 and guidance_key() == "help.level3.relay_polarity.b", "changed_evidence_allows_l3")
	else:
		check(count_events("help_requested") == 0 and count_events("scanner_picked_up") == 0, "no_support_used")
	await turn(bay.relay_b, 1)
	var riser := bay.routes.find_child("CouplerRiserFlow", true, false) as MeshInstance3D
	check(bay.route_transfer == "STANDBY_READY" and not bay.route_ready and riser.material_override.emission_energy_multiplier == 0,
		"aligned_is_standby_not_load")
	await capture_state("standby")
	await face(bay.route_tester, Vector3(-2.2, 0, -2.05), Vector3(0, 1.25, .3))
	await action("interact")
	await pause(.35)
	check(bay.route_transfer == "ENGAGING" and bay.charge.visible, "manual_engagement_starts_visible_transfer")
	await pause(4.6)
	check(bay.phase == bay.Phase.COMPLETE and bay.route_transfer == "ENERGIZED" and
		riser.material_override.emission_energy_multiplier > 1.0 and bay.audio.hum_started, "engaged_route_and_core_live")
	check(bay.bus_status.text == bay.localization.text("polarity.bus_online") and
		bay.bus_lamps.emission_energy_multiplier > 1.0, "secondary_bus_online")
	await aim(Vector3(0, 0, 2.4), Vector3(.7, 1.5, -3.5))
	await capture_state("engaged")
	var attempts: Array = bay.telemetry.archive.filter(func(event): return event.event_type == "route_test_attempt")
	var outcomes: Array = bay.telemetry.archive.filter(func(event):
		return event.event_type in ["relay_configuration_invalid", "relay_configuration_valid"])
	check(attempts.size() == 5 and outcomes.map(func(event): return event.metadata.test_attempt_uuid) ==
		attempts.map(func(event): return event.event_uuid) and attempts[1].metadata.repeated_configuration,
		"each_test_has_one_linked_outcome")
	var bookkeeping: Array = bay.telemetry.archive.filter(func(event): return event.event_type == "invalid_action_observed")
	check(bookkeeping.map(func(event): return event.metadata.invalid_event_uuid) ==
		outcomes.slice(0, 4).map(func(event): return event.event_uuid), "one_raw_failure_per_failed_test")
	check(bay.localization.missing_keys.is_empty(), "no_missing_localization")
	if bay.telemetry.base_url.contains(":1/"):
		check(bay.telemetry.pending.size() == bay.telemetry.archive.size(), "offline_queue")
	else:
		var limit := Time.get_ticks_msec() + 6000
		while not bay.telemetry.session_closed and Time.get_ticks_msec() < limit:
			await pause(.15)
		check(bay.telemetry.session_closed and bay.telemetry.quarantined.is_empty() and
			bay.telemetry.acknowledged == bay.telemetry.archive.size(), "isolated_api_closed")
	bay.telemetry.export_trace("res://.cache/mb02_refinement_%s_trace.json" % selected)
	check(bay.program.available("MB03"), "mb03_unlocked")
	var tree: SceneTree = bay.get_tree()
	await face(bay.operations_console, Vector3(-3.5, 0, 1.2), Vector3(0, 1.5, .16))
	await action("interact")
	await tree.create_timer(1.5).timeout
	check(tree.current_scene.definition.data.slot == "MB03" and tree.current_scene.localization.locale == selected, "mb03_launch_regression")
	var file := FileAccess.open("res://.cache/mb02_refinement_%s_report.json" % selected, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
