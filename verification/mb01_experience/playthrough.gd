extends "res://verification/v02/cascade_probe.gd"

var artifact_id: String

func count_events(kind: String) -> int:
	return bay.telemetry.archive.filter(func(event): return event.event_type == kind).size()

func last_rejection() -> Dictionary:
	return bay.telemetry.archive.filter(func(event): return event.event_type == "placement_invalid").back().metadata

func power_fault(readout: String, reason: String) -> void:
	await face(bay.module, Vector3(0, 0, 1.5), Vector3(0, .18, 0))
	await action("interact")
	await face(bay.correct_socket, Vector3(2.05, 0, .1), Vector3(0, .11, 0))
	await action("place")
	check(bay.player.held == bay.module and last_rejection().reason == reason and
		bay.correct_socket.fault_display.text == bay.localization.text(readout) and
		bay.correct_socket.fault_surfaces.size() == 1, reason + "_physical_signature")
	await capture(reason)
	await aim(Vector3(0, 0, 1.2), Vector3(0, 0, .3))
	await action("put_down")

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(bay.get_viewport().get_texture().get_image().save_png(
		"res://.cache/mb01_%s_%s.png" % [artifact_id, name]) == OK, name + "_captured")

func echoed_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	event.echo = true
	Input.parse_input_event(event)
	await wait_frames(2)

func walk_to(destination: Vector3) -> bool:
	var origin: Vector3 = bay.player.position
	await aim(origin, destination + Vector3.UP * 1.61)
	var deadline := Time.get_ticks_msec() + 3500
	Input.action_press("move_forward")
	var reached := false
	while Time.get_ticks_msec() < deadline:
		var offset: Vector3 = destination - bay.player.position
		if Vector2(offset.x, offset.z).length() < .18:
			reached = true
			break
		await wait_frames(1)
	Input.action_release("move_forward")
	return reached

func seat_service_block() -> void:
	var block: Node3D = bay.hardware.get_node("SERVICE_MODULE_01")
	var socket: Node3D = bay.hardware.get_node("SERVICE_CRADLE_01")
	await face(block, Vector3(.48, 0, 3.25), Vector3(0, .18, 0))
	await wait_frames(2)
	check(bay.prompt_label.text == bay.localization.text("mb01.block.lift_entry"), "service_block_has_pickup_affordance")
	await action("interact")
	check(bay.player.held == block, "service_block_picked_up")
	check(await walk_to(Vector3(.48, 0, 1.16)), "service_block_physically_carried")
	await face(socket, bay.player.position, Vector3(0, .16, .15))
	check(socket.approach_active, "service_socket_recognizes_carried_block")
	await capture("service_cradle")
	await action("interact")
	await pause(.55)
	check(socket.locked and block.get_parent() == socket and bay.service_seated and not bay.cooling_ready,
		"service_block_seats_before_cooling")
	check(bay.hardware.entry_latch.position.y < .18 and bay.hardware.entry_lamp.emission_enabled, "service_latch_moves")

func seat_contact_block() -> void:
	var block: Node3D = bay.hardware.get_node("CONTACT_MODULE_02")
	var socket: Node3D = bay.hardware.get_node("CONTACT_CARRIER_02")
	await face(block, Vector3(-2.19, 0, 1.30), Vector3(0, .18, 0))
	await wait_frames(2)
	check(bay.prompt_label.text == bay.localization.text("mb01.block.lift_keyed"), "contact_block_has_pickup_affordance")
	await action("interact")
	check(bay.player.held == block, "contact_block_picked_up")
	check(await walk_to(Vector3(1.40, 0, 1.30)), "contact_block_carried_across_room")
	check(await walk_to(Vector3(1.40, 0, -1.30)), "contact_block_carried_past_service_cradle")
	check(await walk_to(Vector3(3.49, 0, -1.30)), "contact_block_reaches_receiver")
	await face(socket, bay.player.position, Vector3(0, .16, .15))
	check(socket.approach_active, "contact_socket_recognizes_block_before_alignment")
	await action("place")
	await pause(.14)
	check(bay.player.held == block and not socket.locked and socket.fault_display.text ==
		bay.localization.text("mb01.coupling.misaligned"), "contact_misalignment_is_recoverable")
	check(bay.audio.cue_counts["alignment_refusal"] == 1, "distinct_mechanical_refusal_sound")
	check(socket.fault_surfaces.is_empty() and last_rejection().same_cause_streak == 1, "first_contact_rejection_is_subtle")
	await capture("contact_refusal")
	await action("place")
	check(socket.fault_surfaces.size() == 3 and last_rejection().same_cause_streak == 2, "second_repeat_emphasizes_actual_key_surfaces")
	await capture("contact_refusal_repeated")
	await action("place")
	check(socket.fault_surfaces.size() == 3 and last_rejection().same_cause_streak == 3, "third_repeat_reuses_same_features")
	await action("rotate_left")
	await pause(.18)
	await action("place")
	check(socket.fault_surfaces.is_empty() and last_rejection().same_cause_streak == 1 and last_rejection().orientation_changed,
		"new_wrong_orientation_resets_repeat_feedback")
	await action("rotate_right")
	await action("rotate_right")
	await pause(.18)
	await action("place")
	await pause(1.4)
	check(socket.locked and block.get_parent() == socket and bay.contact_seated, "contact_block_rotates_and_seats")
	check(bay.hardware.wheel_speed > 4.0 and bay.hardware.key_lamp.emission_enabled, "contact_carrier_drives_flywheel")

func run(world: Node) -> void:
	bay = world
	var locale: String = bay.localization.locale
	var swap_support := "--mb01-swap-support" in OS.get_cmdline_user_args()
	var use_support := (locale == "tr") != swap_support
	artifact_id = locale + "_swapped" if swap_support else locale
	check(RenderingServer.get_rendering_device() != null, "real_mobile_gpu")
	check(not bay.intro_complete and bay.presentation.blackout.visible and not bay.player.is_physics_processing(), "black_boot_before_control")
	await capture("boot")
	await pause(3)
	check(bay.intro_complete and bay.presentation.notice.visible and bay.player.is_on_floor(), "controls_and_corridor_floor")
	check(not bay.presentation.notice.text.contains("F —") and bay.prompt_label.text.is_empty(), "no_premature_interaction_prompt")
	check(bay.presentation.radio.get_meta("localization_key") == "mb01.radio.station", "station_ai_intro")
	await capture("corridor")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(22, -4)
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await wait_frames(3)
	check(abs(bay.player.rotation.y) > .02, "mouse_look")
	var fixture: Area3D = bay.surroundings.ventilation
	await aim(bay.player.position, fixture.global_position)
	check(bay.player.target() == null, "fixture_requires_approach")
	await aim(bay.player.position, Vector3(0, 1.61, 0))
	Input.action_press("move_forward")
	await pause(1.25)
	Input.action_release("move_forward")
	var at: Vector3 = bay.player.position
	await face(fixture, at, Vector3.ZERO)
	check(bay.player.target() == fixture and bay.prompt_label.text == bay.localization.text("mb01.vent.check"), "first_f_prompt_on_world_fixture")
	check(bay.get_viewport().get_visible_rect().has_point(bay.prompt_label.get_global_rect().get_center()), "interaction_prompt_inside_viewport")
	check(bay.surroundings.vent_screen.text == bay.localization.text("mb01.vent.reserve"), "degraded_ventilation_visible")
	await capture("fixture_prompt")
	await action("interact")
	check(bay.surroundings.vent_screen.text == bay.localization.text("mb01.vent.limited") and count_events("mission_started") == 0,
		"optional_fixture_reacts_without_starting_repair")
	await capture("ventilation")
	await aim(bay.player.position, Vector3(0, 1.61, 0))
	var door_captured := false
	var start_ms := Time.get_ticks_msec()
	Input.action_press("move_forward")
	while not bay.entered_bay and Time.get_ticks_msec() - start_ms < 38000:
		await wait_frames(1)
		if bay.player.position.z < 8.2 and not door_captured:
			door_captured = true
			await capture("door")
	Input.action_release("move_forward")
	var walk: float = (Time.get_ticks_msec() - start_ms) / 1000.0
	report["walk_seconds_excluding_fixture_stop"] = walk + 1.25
	check(bay.entered_bay and bay.surroundings.door_barrier.disabled and walk >= 6 and walk < 12, "shorter_walk_through_sliding_door")
	check(not bay.presentation.notice.visible and count_events("control_prompt_shown") == 1, "controls_fade_once")
	check(bay.presentation.objective.visible and bay.presentation.radio.get_meta("localization_key") == "mb01.radio.engineer", "chief_assignment_and_objective")
	var door := bay.surroundings.find_children("*", "Label3D", true, false)[0] as Label3D
	check(door.text == bay.localization.text("mb01.door"), "localized_world_door")
	if locale == "tr":
		check(door.text.contains("SİSTEM BAKIM BİRİMİ") and door.font.has_char("İ".unicode_at(0)), "turkish_world_glyph")
	await capture("assignment")
	check(bay.module.position.x > -1.3 and bay.ai_station.screen.text == bay.localization.text("mb01.support.idle"), "module_forward_and_ai_quiet_on_entry")
	for id in [bay.ENTRY_BLOCK, bay.KEY_BLOCK]:
		var module: Node3D = bay.hardware.get_node(id)
		check(bay.player.camera.is_position_in_frustum(module.global_position + Vector3.UP * .15),
			"block_visible_from_doorway_" + id)
	await aim(Vector3(0, 0, 2.4), Vector3(0, 1.5, -3.5))
	bay.metrics.reset_samples()
	await pause(7)
	report["room_metrics"] = bay.metrics.report(bay)
	check(not bay.presentation.objective.visible, "objective_fades")
	await face(bay.terminal, Vector3(-2.9, 0, -.3), Vector3(0, 1.56, 0))
	await action("interact")
	for index in range(10):
		await echoed_key(KEY_F)
	await pause(.15)
	check(count_events("terminal_interaction") == 1, "terminal_held_key_single_event")
	await action("interact")
	check(count_events("terminal_interaction") == 2, "terminal_deliberate_repeat")
	check(bay.terminal.screen.text == bay.localization.text("mb01.terminal.no_data"), "terminal_repeat_has_status_only")
	await wait_frames(2)
	check(bay.prompt_label.text.is_empty() and bay.delivered_tier == 0, "repeat_terminal_prompt_quiet_without_help_progress")
	await seat_service_block()
	await face(bay.module, Vector3(-1.17, 0, 1.45), Vector3(0, .18, 0))
	await action("interact")
	check(bay.player.held == bay.module and bay.presentation.notice.get_meta("localization_key") == "mb01.rotate", "pickup_rotation_prompt")
	await face(bay.correct_socket, Vector3(2.05, 0, .1), Vector3(0, .11, 0))
	check(bay.correct_socket.approach_active and bay.correct_socket.approach_color == bay.hardware.PRIMARY_TINT,
		"primary_receiver_recognizes_module_before_power")
	await action("place")
	await pause(.12)
	check(not bay.correct_socket.locked and bay.player.held == bay.module and not bay.relay_ready, "physical_rejection")
	check(bay.correct_socket.fault_display.text == bay.localization.text("mb01.coupling.no_input") and
		bay.correct_socket.feedback_light.light_color.r > .9 and count_events("placement_invalid") == 1, "upstream_feedback_and_evidence")
	await capture("upstream")
	await action("place")
	check(bay.correct_socket.fault_surfaces.size() == 1 and last_rejection().same_cause_streak == 2,
		"repeated_upstream_attempt_emphasizes_local_input")
	await pause(5.6)
	check(not bay.presentation.notice.visible and not bay.presentation.radio.visible and not bay.dock_awake, "recovery_silence")
	await face(bay.wrong_socket, Vector3(.95, 0, .1), Vector3(0, .11, 0))
	await action("place")
	check(not bay.wrong_socket.locked and bay.player.held == bay.module and count_events("placement_invalid") == 3 and
		bay.wrong_socket.fault_display.text == bay.localization.text("mb01.coupling.service"), "service_socket_rejects_module")
	check(last_rejection().socket_changed and last_rejection().previous_rejection_cause == "upstream_system_not_ready",
		"socket_change_and_previous_cause_available")
	await capture("service")
	await action("place")
	check(bay.wrong_socket.fault_surfaces.size() == 1 and last_rejection().same_cause_streak == 2,
		"incompatible_retry_emphasizes_socket_only")
	await aim(Vector3(0, 0, 1.2), Vector3(0, 0, .3))
	await action("put_down")
	check(bay.player.held == null, "module_releases_to_world")
	await face(bay.cooling, Vector3(-1.35, 0, -2.1), Vector3(0, 1.45, .3))
	await action("inspect")
	for index in range(10):
		await echoed_key(KEY_E)
	await pause(.15)
	check(count_events("subsystem_inspected") == 1, "inspect_held_key_single_event")
	await action("inspect")
	check(count_events("subsystem_inspected") == 2, "inspect_deliberate_repeat")
	await pause(21)
	check(not bay.dock_awake, "inspection_keeps_recovery_window_open")
	await pause(5)
	check(bay.dock_awake and count_events("scanner_dock_woke") == 1, "dock_ambient_onboarding_after_idle")
	if use_support:
		await face(bay.scanner, Vector3(-3.2, 0, 2.9), Vector3(0, .2, 0))
		await action("interact")
		await pause(.08)
		check(bay.player.held == bay.scanner and count_events("scanner_tutorial_shown") == 1 and
			bay.presentation.notice.text == bay.localization.text("mb01.scanner.intro"), "first_pickup_scanner_explanation")
		await face(bay.cooling, Vector3(-1.35, 0, -2.1), Vector3(0, 1.45, .3))
		await action("place")
		await pause(.8)
		check(bay.scanner.screen.text == bay.localization.text(bay.cooling.scan_status()) and
			count_events("scanner_scan_completed") == 1, "scanner_state_only")
		await action("place")
		await pause(.8)
		check(bay.scanner.screen.text == bay.localization.text("mb01.scanner.unchanged") and
			bay.telemetry.archive.back().metadata.unchanged, "repeated_scan_reports_no_state_change")
		await aim(Vector3(-3.2, 0, 2.9), Vector3(-3.2, 1.05, 1.5))
		await action("put_down")
		await help()
		check(guidance_key() in ["help.level1.power_coupling.early", "help.level1.power_coupling"], "optional_station_level1")
		await help()
		await help()
		check(bay.delivered_tier == 1, "repeated_requests_stay_at_level1")
		await face(bay.cooling, Vector3(-1.35, 0, -2.1), Vector3(0, 1.45, .3))
		await action("inspect")
		await help()
		check(bay.delivered_tier == 1, "duplicate_observation_stays_at_level1")
	await face(bay.relay, Vector3(0, 0, -2.1), Vector3(0, 1.45, .3))
	await action("interact")
	await pause(.5)
	check(not bay.relay_ready and count_events("relay_rejected") == 1, "relay_requires_cooling")
	await face(bay.cooling, Vector3(-1.35, 0, -2.1), Vector3(0, 1.45, .3))
	await action("interact")
	await pause(1)
	check(bay.cooling_ready, "regulator_actuates")
	await pause(.95)
	check(bay.hardware.pump_speed > 5.0, "cooling_pump_spins_up")
	if use_support:
		await face(bay.scanner, Vector3(-3.2, 0, 2.9), Vector3(0, .2, 0))
		await action("interact")
		await face(bay.cooling, Vector3(-1.35, 0, -2.1), Vector3(0, 1.45, .3))
		await action("place")
		await pause(.8)
		check(bay.scanner.screen.text == bay.localization.text("diagnostic.flow_stable") and
			not bay.telemetry.archive.back().metadata.unchanged, "changed_cooling_state_gives_new_reading")
		await aim(Vector3(-3.2, 0, 2.9), Vector3(-3.2, 1.05, 1.5))
		await action("put_down")
		await help()
		check(guidance_key() == "help.level2.power_coupling.relay", "optional_station_level2")
		await help()
		check(bay.delivered_tier == 2, "repeated_requests_stay_at_level2")
		await face(bay.relay, Vector3(0, 0, -2.1), Vector3(0, 1.45, .3))
		await action("inspect")
		await help()
		check(guidance_key() == "help.level3.power_coupling.relay", "optional_station_level3")
	if locale == "tr":
		await seat_contact_block()
	await power_fault("mb01.coupling.relay_open", "relay_not_ready")
	await face(bay.relay, Vector3(0, 0, -2.1), Vector3(0, 1.45, .3))
	await action("interact")
	await pause(.85)
	check(bay.relay_ready, "relay_actuates")
	check(bay.hardware.contactor.position.y < .50, "relay_closes_visible_contactor")
	if locale == "en":
		check(not bay.upstream_ready() and bay.correct_socket.scan_status() == "mb01.coupling.contacts_open",
			"powered_relay_with_unseated_contact_is_legible")
		await power_fault("mb01.coupling.contacts_open", "open_auxiliary_contacts")
		check(last_rejection().system_state_changed, "raw_rejection_records_system_change")
		await seat_contact_block()
	await face(bay.module, Vector3(0, 0, 1.5), Vector3(0, .18, 0))
	await action("interact")
	check(count_events("control_prompt_shown") == 2, "rotation_prompt_once")
	await face(bay.correct_socket, Vector3(2.05, 0, .1), Vector3(0, .11, 0))
	await action("place")
	await pause(.15)
	check(not bay.correct_socket.locked and bay.correct_socket.fault_display.text == bay.localization.text("mb01.coupling.misaligned") and
		bay.correct_socket.feedback_light.light_color.b > .9, "alignment_feedback_and_evidence")
	for rail in bay.correct_socket.rail_rest:
		check(absf(rail.position.x - bay.correct_socket.rail_rest[rail]) > .02, "alignment_rails_react")
	await capture("alignment")
	await pause(.4)
	await action("rotate_left")
	await action("rotate_right")
	await action("rotate_right")
	await pause(.25)
	var core_y: float = bay.machine.core.position.y
	await action("place")
	await pause(.22)
	check(bay.correct_socket.locked and bay.module.get_parent() == bay.correct_socket, "seated_and_locked")
	var coupler := bay.routes.find_child("CouplerRouteFlow", true, false) as MeshInstance3D
	var core_route := bay.routes.find_child("CoreRouteFlow", true, false) as MeshInstance3D
	await pause(.36)
	check(coupler.material_override.emission_energy_multiplier > 0 and core_route.material_override.emission_energy_multiplier < .1, "route_illuminates_in_order")
	await aim(Vector3(0, 0, 2.4), Vector3(0, 1.5, -3.5))
	await pause(4.2)
	check(core_route.material_override.emission_energy_multiplier > 2, "core_route_energized")
	check(bay.phase == bay.Phase.COMPLETE and bay.machine.core.position.y > core_y + .2 and bay.machine.spin_speed > 1.4, "core_rise_and_rotation")
	check(bay.audio.hum_started and bay.surroundings.fan_speed > 1, "hum_and_vent_reaction")
	check(bay.hardware.wheel_speed > 6.0, "sector_drive_spins_up_with_final_activation")
	check(bay.surroundings.machine_status.text == bay.localization.text("mb01.status.operational"), "physical_status")
	check(bay.presentation.radio.get_meta("localization_key") == "mb01.radio.complete" and bay.presentation.radio.visible, "completion_radio")
	check(count_events("machine_activated") == 1 and count_events("mission_completed") == 1, "activation_and_completion_telemetry_once")
	check(bay.surroundings.vent_online and bay.surroundings.bay_vent_status.text == bay.localization.text("mb01.vent.online") and
		bay.surroundings.vent_screen.text == bay.localization.text("mb01.vent.online"), "downstream_ventilation_restored")
	var failed_attempts: Array = bay.telemetry.archive.filter(func(event):
		return event.event_type in ["placement_invalid", "relay_rejected"])
	report["raw_failure_causes"] = failed_attempts.map(func(event): return event.metadata.reason)
	var expected := ["upstream_system_not_ready", "upstream_system_not_ready", "incompatible_interface", "incompatible_interface", "cooling_not_ready"]
	if locale == "en":
		expected.append_array(["relay_not_ready", "open_auxiliary_contacts"])
	for index in range(4):
		expected.append("key_orientation")
	if locale == "tr":
		expected.append("relay_not_ready")
	expected.append("key_orientation")
	check(report.raw_failure_causes == expected,
		"raw_failure_causes_counted_once")
	report["same_cause_repeat_count"] = failed_attempts.filter(func(event): return event.metadata.get("same_cause_streak", 0) > 1).size()
	var linked_failures: Array = bay.telemetry.archive.filter(func(event): return event.event_type == "invalid_action_observed")
	check(linked_failures.map(func(event): return event.metadata.invalid_event_uuid) == failed_attempts.map(func(event): return event.event_uuid),
		"failure_bookkeeping_links_to_raw_attempts")
	var placements: Array = bay.telemetry.archive.filter(func(event): return event.event_type == "placement_valid")
	check(placements.map(func(event): return event.object_id) == [bay.ENTRY_BLOCK, bay.KEY_BLOCK, bay.PRIMARY_BLOCK],
		"three_distinct_block_placements_in_telemetry")
	var attempt_ids := {}
	for event in bay.telemetry.archive:
		if event.event_type == "placement_attempt":
			attempt_ids[event.event_uuid] = event
	var outcomes := bay.telemetry.archive.filter(func(event): return event.event_type in ["placement_invalid", "placement_valid"]) as Array
	for outcome in outcomes:
		var attempt: Dictionary = attempt_ids.get(outcome.metadata.attempt_uuid, {})
		check(not attempt.is_empty() and attempt.object_id == outcome.object_id and attempt.target_id == outcome.target_id and
			attempt.metadata.orientation == outcome.metadata.orientation, "block_attempt_links_to_its_outcome")
		attempt_ids.erase(outcome.metadata.attempt_uuid)
	check(attempt_ids.is_empty(), "one_outcome_per_placement_attempt")
	if not use_support:
		check(count_events("scanner_picked_up") == 0 and count_events("help_requested") == 0, "scanner_and_help_optional")
	await capture("online")
	var post_repair_position: Vector3 = bay.player.position
	Input.action_press("move_right")
	await pause(.45)
	Input.action_release("move_right")
	check(post_repair_position.distance_to(bay.player.position) > .35, "can_walk_after_completion")
	await face(bay.operations_console, Vector3(-3.5, 0, 1.2), Vector3(0, 1.5, .16))
	await action("interact")
	check(not bay.exit_ready and bay.get_tree().current_scene == bay, "exit_held_during_completion_beat")
	if use_support:
		await aim(Vector3(-3.2, 0, 2.9), Vector3(-3.2, 1.24, 1.5))
		await action("interact")
		check(bay.player.held == bay.scanner and count_events("scanner_tutorial_shown") == 1, "scanner_remains_usable_and_tutorial_stays_once")
		await face(bay.correct_socket, Vector3(2.05, 0, .1), Vector3(0, .11, 0))
		await action("place")
		await pause(.8)
		check(bay.scanner.screen.get_meta("localization_key") == "diagnostic.coupling_active", "post_completion_scan")
	var tree: SceneTree = bay.get_tree()
	var exit_deadline := Time.get_ticks_msec() + 8000
	while not bay.exit_ready and Time.get_ticks_msec() < exit_deadline:
		await pause(.25)
	check(bay.exit_ready and not bay.presentation.radio.visible and bay.operations_console.prompt() == "program.enter_mb02", "exit_enables_after_completion_beat")
	await pause(1.0)
	check(tree.current_scene == bay and bay.exit_ready, "may_stay_after_departure_enabled")
	check(bay.localization.missing_keys.is_empty(), "localization_complete")
	if bay.telemetry.base_url.contains(":1/"):
		check(bay.telemetry.pending.size() == bay.telemetry.archive.size(), "offline_queue_preserved")
	else:
		check(bay.telemetry.session_closed and bay.telemetry.quarantined.is_empty() and
			bay.telemetry.acknowledged == bay.telemetry.archive.size(), "api_acknowledged_and_closed")
	bay.telemetry.export_trace("res://.cache/mb01_%s_trace.json" % artifact_id)
	check(bay.program.save_error == OK, "isolated_progress_saved")
	await face(bay.operations_console, Vector3(-3.5, 0, 1.2), Vector3(0, 1.5, .16))
	await action("interact")
	await tree.create_timer(2).timeout
	bay = tree.current_scene
	check(bay.definition.data.slot == "MB02" and bay.localization.locale == locale, "mb02_physical_launch")
	if "--verify-mb02-refinement" in OS.get_cmdline_user_args():
		var probe: RefCounted = load("res://verification/phase2b/refinement_probe.gd").new()
		await probe.run(bay)
		failed = failed or probe.failed
		return
	if bay.language_selector.opened:
		await action("language")
	for unit in [bay.relay_b, bay.relay_a]:
		await face(unit, Vector3(unit.position.x, 0, -2.05), Vector3(0, 1.35, .3))
		for index in range(2):
			await action("rotate_right")
			await pause(.4)
	await face(bay.route_tester, Vector3(-2.2, 0, -2.05), Vector3(0, 1.25, .3))
	await action("interact")
	await pause(4.5)
	check(bay.phase == bay.Phase.COMPLETE and bay.program.available("MB03"), "mb02_repair_unlocks_mb03")
	await face(bay.operations_console, Vector3(-3.5, 0, 1.2), Vector3(0, 1.5, .16))
	await action("interact")
	await tree.create_timer(2).timeout
	bay = tree.current_scene
	check(bay.definition.data.slot == "MB03" and bay.localization.locale == locale, "mb03_physical_launch")
	var file := FileAccess.open("res://.cache/mb01_%s_report.json" % artifact_id, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
