extends "res://verification/v02/cascade_probe.gd"

func count_events(kind: String) -> int:
	return bay.telemetry.archive.filter(func(event): return event.event_type == kind).size()

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(bay.get_viewport().get_texture().get_image().save_png(
		"res://.cache/mb01_%s_%s.png" % [bay.localization.locale, name]) == OK, name + "_captured")

func echoed_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	event.echo = true
	Input.parse_input_event(event)
	await wait_frames(2)

func run(world: Node) -> void:
	bay = world
	var locale: String = bay.localization.locale
	check(RenderingServer.get_rendering_device() != null, "real_mobile_gpu")
	check(not bay.intro_complete and bay.presentation.blackout.visible and not bay.player.is_physics_processing(), "black_boot_before_control")
	await capture("boot")
	await pause(3)
	check(bay.intro_complete and bay.presentation.notice.visible and bay.player.is_on_floor(), "controls_and_corridor_floor")
	check(bay.presentation.radio.get_meta("localization_key") == "mb01.radio.station", "station_ai_intro")
	await capture("corridor")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(22, -4)
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await wait_frames(3)
	check(abs(bay.player.rotation.y) > .02, "mouse_look")
	motion = InputEventMouseMotion.new()
	motion.relative = Vector2(-22, 4)
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await wait_frames(3)
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
	report["walk_seconds"] = walk
	check(bay.entered_bay and bay.surroundings.door_barrier.disabled and walk >= 20 and walk <= 40, "walked_through_sliding_door")
	check(not bay.presentation.notice.visible and count_events("control_prompt_shown") == 1, "controls_fade_once")
	check(bay.presentation.objective.visible and bay.presentation.radio.get_meta("localization_key") == "mb01.radio.engineer", "chief_assignment_and_objective")
	var door := bay.surroundings.find_children("*", "Label3D", true, false)[0] as Label3D
	check(door.text == bay.localization.text("mb01.door"), "localized_world_door")
	if locale == "tr":
		check(door.text.contains("SİSTEM BAKIM BİRİMİ") and door.font.has_char("İ".unicode_at(0)), "turkish_world_glyph")
	await capture("assignment")
	await aim(Vector3(0, 0, 2.4), Vector3(0, 1.5, -3.5))
	bay.metrics.reset_samples()
	await pause(7)
	report["room_metrics"] = bay.metrics.report(bay)
	check(not bay.presentation.objective.visible, "objective_fades")
	if locale == "tr":
		await face(bay.terminal, Vector3(-2.9, 0, -.3), Vector3(0, 1.56, 0))
		await action("interact")
		for index in range(10):
			await echoed_key(KEY_F)
		await pause(.15)
		check(count_events("terminal_interaction") == 1, "terminal_held_key_single_event")
		await action("interact")
		check(count_events("terminal_interaction") == 2, "terminal_deliberate_repeat")
	await face(bay.module, Vector3(-1.7, 0, 1.45), Vector3(0, .18, 0))
	await action("interact")
	check(bay.player.held == bay.module and bay.presentation.notice.get_meta("localization_key") == "mb01.rotate", "pickup_rotation_prompt")
	await face(bay.correct_socket, Vector3(2.05, 0, .1), Vector3(0, .11, 0))
	await action("place")
	await pause(.12)
	check(not bay.correct_socket.locked and bay.module.position.z > .05 and not bay.relay_ready, "physical_rejection")
	check(bay.correct_socket.feedback_light.light_energy > 0 and count_events("placement_invalid") == 1, "amber_feedback_and_evidence")
	await pause(5.6)
	check(not bay.presentation.notice.visible and not bay.presentation.radio.visible and not bay.dock_awake, "recovery_silence")
	if locale == "tr":
		await face(bay.wrong_socket, Vector3(.95, 0, .1), Vector3(0, .11, 0))
		await action("place")
		check(not bay.wrong_socket.locked and bay.player.held == bay.module and count_events("placement_invalid") == 2, "service_socket_rejects_module")
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
	if locale == "tr":
		await face(bay.scanner, Vector3(-3.2, 0, 2.9), Vector3(0, .2, 0))
		await action("interact")
		await pause(.08)
		check(bay.player.held == bay.scanner and count_events("scanner_tutorial_shown") == 1 and
			bay.presentation.notice.text == bay.localization.text("mb01.scanner.intro"), "first_pickup_scanner_explanation")
		await face(bay.cooling, Vector3(-1.35, 0, -2.1), Vector3(0, 1.45, .3))
		await action("place")
		await pause(.8)
		check(bay.scanner.screen.text == bay.localization.text(bay.cooling.scan_status()), "scanner_state_only")
		await aim(Vector3(-3.2, 0, 2.9), Vector3(-3.2, 1.05, 1.5))
		await action("put_down")
		await help()
		check(guidance_key() in ["help.level1.power_coupling.early", "help.level1.power_coupling"], "optional_station_level1")
	await face(bay.relay, Vector3(0, 0, -2.1), Vector3(0, 1.45, .3))
	await action("interact")
	await pause(.5)
	check(not bay.relay_ready and count_events("relay_rejected") == 1, "relay_requires_cooling")
	await face(bay.cooling, Vector3(-1.35, 0, -2.1), Vector3(0, 1.45, .3))
	await action("interact")
	await pause(1)
	check(bay.cooling_ready, "regulator_actuates")
	if locale == "tr":
		await help()
		check(guidance_key() == "help.level2.power_coupling.relay", "optional_station_level2")
		await help()
		check(guidance_key() == "help.level3.power_coupling.relay", "optional_station_level3")
	await face(bay.relay, Vector3(0, 0, -2.1), Vector3(0, 1.45, .3))
	await action("interact")
	await pause(.7)
	check(bay.relay_ready, "relay_actuates")
	await face(bay.module, Vector3(0, 0, 1.5), Vector3(0, .18, 0))
	await action("interact")
	check(count_events("control_prompt_shown") == 2, "rotation_prompt_once")
	await face(bay.correct_socket, Vector3(2.05, 0, .1), Vector3(0, .11, 0))
	await action("place")
	check(not bay.correct_socket.locked, "orientation_rejection")
	await pause(.4)
	await action("rotate_left")
	await action("rotate_right")
	await action("rotate_right")
	await pause(.25)
	var core_y: float = bay.machine.core.position.y
	await action("place")
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
	check(bay.surroundings.machine_status.text == bay.localization.text("mb01.status.operational"), "physical_status")
	check(bay.presentation.radio.get_meta("localization_key") == "mb01.radio.complete" and bay.presentation.radio.visible, "completion_radio")
	check(count_events("machine_activated") == 1 and count_events("mission_completed") == 1, "activation_and_completion_telemetry_once")
	if locale == "en":
		check(count_events("scanner_picked_up") == 0 and count_events("help_requested") == 0 and count_events("terminal_interaction") == 0, "scanner_help_and_terminal_optional")
	await capture("online")
	var post_repair_position: Vector3 = bay.player.position
	Input.action_press("move_right")
	await pause(.45)
	Input.action_release("move_right")
	check(post_repair_position.distance_to(bay.player.position) > .35, "can_walk_after_completion")
	await face(bay.operations_console, Vector3(-3.5, 0, 1.2), Vector3(0, 1.5, .16))
	await action("interact")
	check(not bay.exit_ready and bay.get_tree().current_scene == bay, "exit_held_for_free_exploration")
	if locale == "tr":
		await aim(Vector3(-3.2, 0, 2.9), Vector3(-3.2, 1.24, 1.5))
		await action("interact")
		check(bay.player.held == bay.scanner and count_events("scanner_tutorial_shown") == 1, "scanner_remains_usable_and_tutorial_stays_once")
		await face(bay.correct_socket, Vector3(2.05, 0, .1), Vector3(0, .11, 0))
		await action("place")
		await pause(.8)
		check(bay.scanner.screen.get_meta("localization_key") == "diagnostic.coupling_active", "post_completion_scan")
	var tree: SceneTree = bay.get_tree()
	while not bay.exit_ready:
		await pause(.25)
	check(bay.operations_console.prompt() == "program.enter_mb02", "exit_enables_after_free_time")
	check(bay.localization.missing_keys.is_empty(), "localization_complete")
	if bay.telemetry.base_url.contains(":1/"):
		check(bay.telemetry.pending.size() == bay.telemetry.archive.size(), "offline_queue_preserved")
	else:
		check(bay.telemetry.session_closed and bay.telemetry.quarantined.is_empty() and
			bay.telemetry.acknowledged == bay.telemetry.archive.size(), "api_acknowledged_and_closed")
	bay.telemetry.export_trace("res://.cache/mb01_%s_trace.json" % locale)
	check(bay.program.save_error == OK, "isolated_progress_saved")
	await face(bay.operations_console, Vector3(-3.5, 0, 1.2), Vector3(0, 1.5, .16))
	await action("interact")
	await tree.create_timer(2).timeout
	bay = tree.current_scene
	check(bay.definition.data.slot == "MB02" and bay.localization.locale == locale, "mb02_physical_launch")
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
	var file := FileAccess.open("res://.cache/mb01_%s_report.json" % locale, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
