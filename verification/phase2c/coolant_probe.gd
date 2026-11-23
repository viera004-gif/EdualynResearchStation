extends "res://verification/localization/localization_probe.gd"
func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(bay.get_viewport().get_texture().get_image().save_png("res://verification/phase2c/" + bay.configuration_id + "_" + selected + "_" + name + ".png") == OK, "capture_" + name)
func face_control(unit: Node) -> void:
	await face(unit, Vector3(unit.position.x, 0, -2.0), Vector3(0, 1.35, .28))
func adjust(unit: Node, direction: int) -> void:
	await face_control(unit)
	var before: int = unit.value
	await action("rotate_right" if direction > 0 else "rotate_left")
	await pause(.55)
	check(unit.value == clampi(before + direction,0,3), "physical_adjust_" + unit.kind)
	if unit.kind == "regulator":
		check(absf(unit.mechanism.position.y - (unit.base_y + (unit.value - 1.5) * .06)) < .002, "linear_regulator_motion")
	else:
		check(absf(unit.mechanism.rotation.z - unit.value * (PI/4 if unit.kind == "primary" else PI/6)) < .002, "valve_motion_" + unit.kind)
func scan_component(unit: Node, key: String) -> void:
	if unit == bay.cooling_core:
		await face(unit, Vector3(2.9, 0, -.85), Vector3(0, 1.65, .35))
	elif unit == bay.core_gauge or unit == bay.source_gauge:
		await face(unit, Vector3(unit.position.x, 0, -2), Vector3(0, 0, .10))
	else:
		await face_control(unit)
	await action("place")
	await pause(.8)
	check(bay.scanner.screen.get_meta("localization_key") == key and bay.scanner.screen.text == bay.localization.text(key), "scan_" + key)
func run(world: Node) -> void:
	bay = world
	selected = bay.localization.locale
	var initial: Dictionary = bay.definition.data.start_configurations[bay.configuration_id]
	await pause(2)
	check(RenderingServer.get_rendering_device() != null, "real_gpu")
	check(not bay.network.evidence().safe and bay.temperature > 80, "initial_common_cooling_failure")
	check(bay.tutorial_label.text.is_empty() and bay.definition.data.scaffolding_level == "minimal", "less_automatic_guidance")
	check(bay.definition.data.help_policy.adaptive_help.prolonged_no_progress_seconds > 45, "delayed_help_policy")
	var start: Vector3 = bay.player.position
	Input.action_press("move_forward")
	await pause(.4)
	Input.action_release("move_forward")
	await pause(.1)
	check(start.distance_to(bay.player.position) > .3, "movement")
	await face(bay.source_gauge, Vector3(-2.1, 0, -2), Vector3(0,0,.1))
	await action("interact")
	await screenshot("gauges_initial")
	if "--verify-stall" in OS.get_cmdline_user_args():
		await pause(46)
		check(not bay.help_salient, "no_mb01_timed_nudge_at_46_seconds")
		await pause(30)
		check(bay.help_salient, "actual_75_second_salience")
	await help()
	check(guidance_key() == "help.level1.coolant_pressure", "help_l1")
	var old_pressure: float = bay.network.evidence().pressure
	var old_needle: float = bay.core_gauge.needle.rotation.z
	await adjust(bay.primary,-1)
	check(bay.network.evidence().pressure < old_pressure and absf(bay.core_gauge.needle.rotation.z - old_needle) > .01, "closing_primary_lowers_pressure_visible_needle")
	await adjust(bay.primary,1)
	var reversed := false
	for event in bay.telemetry.archive:
		if event.event_type == "coolant_valve_changed" and not event.metadata.get("reverses_action_uuid", "").is_empty():
			reversed = true
	check(reversed, "reversal_raw_link")
	var old_amplitude: float = bay.network.evidence().amplitude
	await adjust(bay.regulator,1)
	check(bay.network.evidence().amplitude != old_amplitude, "regulator_changes_pressure_oscillation")
	await adjust(bay.regulator,-1)
	if bay.configuration_id == "A":
		for index in range(4):
			await adjust(bay.primary,1)
		check(bay.history.exact_repeats == 3 and bay.help_salient, "repeat_policy_subtle_salience")
	# Observe a bounded diversion change and its reversal without solving yet.
	var direction := -1 if int(initial.bypass) == 3 else 1
	old_pressure = bay.network.evidence().pressure
	await adjust(bay.bypass,direction)
	check(bay.network.evidence().pressure > old_pressure if direction < 0 else bay.network.evidence().pressure < old_pressure, "bypass_consequence_is_directional")
	await adjust(bay.bypass,-direction)
	await face(bay.scanner, Vector3(-3.2,0,2.9), Vector3(0,.2,0))
	await action("interact")
	check(bay.player.held == bay.scanner, "physical_scanner")
	await scan_component(bay.source_gauge,"coolant.scan.source")
	await scan_component(bay.regulator,bay.diagnostic_for("regulator"))
	await scan_component(bay.bypass,bay.diagnostic_for("bypass"))
	await scan_component(bay.cooling_core,"coolant.scan.cooling_failure")
	await help()
	check(guidance_key() == "help.level2.coolant_pressure", "help_l2")
	await help()
	check(guidance_key().begins_with("help.level3.coolant_pressure."), "help_l3")
	check(not bay.network.evidence().safe, "help_never_changes_controls")
	await switch_and_restore()
	await screenshot("support")
	if bay.configuration_id == "A":
		await adjust(bay.bypass,-1)
		await adjust(bay.bypass,-1)
	elif bay.configuration_id == "B":
		await adjust(bay.regulator,1)
		await adjust(bay.regulator,1)
	else:
		await adjust(bay.bypass,-1)
		await adjust(bay.regulator,1)
	check(bay.network.evidence().safe, "physical_balance_restored")
	await scan_component(bay.core_gauge,"coolant.scan.pressure_stable")
	await pause(9)
	check(bay.phase == bay.Phase.COMPLETE and bay.stage == "SYSTEM_ACTIVE", "recovery_completion")
	check(bay.temperature <= 45 and "MB03" in bay.program.completed, "thermal_recovery_and_saved_completion")
	var reloaded = load("res://scripts/program/module_bay_program.gd").new()
	reloaded.configure()
	check("MB03" in reloaded.completed and not reloaded.available("MB04"), "completion_reload_no_mb04")
	reloaded.free()
	check(bay.flow_player.playing and bay.audio.nonzero_frames > 1000 and bay.audio.mixed_peak < .5, "flow_audio_nonzero_with_headroom")
	await face_control(bay.regulator)
	await wait_frames(2)
	check(bay.prompt_label.text==bay.localization.text("coolant.controls_locked"),"completed_controls_status")
	await switch_and_restore()
	await face(bay.core_gauge,Vector3(.15,0,-2),Vector3(0,0,.1))
	await screenshot("complete")
	for character in "çÇğĞıIiİöÖşŞüÜ":
		check(bay.localization.font.has_char(character.unicode_at(0)),"glyph_" + character)
	for key in bay.localization.messages[selected]:
		if key.begins_with("help.") and key.contains("coolant_pressure"):
			check(fits("support.response",28,.00125,Vector2(.75,.48),{"level":3,"guidance":bay.localization.text(key)}),"fits_"+key)
		elif key.begins_with("coolant.scan."):
			check(fits(key,28,.00078,Vector2(.245,.105)),"fits_"+key)
		elif key.begins_with("mission.coolant_pressure.terminal_"):
			check(fits(key,36,.0018,Vector2(.68,.43)),"fits_"+key)
	check(bay.localization.missing_keys.is_empty(),"no_missing_keys")
	var deadline := Time.get_ticks_msec() + 12000
	if not bay.telemetry.base_url.contains(":1/"):
		while not bay.telemetry.session_closed and Time.get_ticks_msec() < deadline:
			await wait_frames(1)
	check(bay.telemetry.pending.size() > 0 if bay.telemetry.base_url.contains(":1/") else bay.telemetry.session_closed,"telemetry_transport")
	report["profile"] = bay.metrics.report(bay)
	report["all_gameplay_checks_passed"] = not failed
	var suffix: String = bay.configuration_id + "_" + selected + ("_offline" if bay.telemetry.base_url.contains(":1/") else "_online")
	if "--verify-stall" in OS.get_cmdline_user_args():
		suffix += "_stall"
	bay.telemetry.export_trace("res://verification/phase2c/telemetry_" + suffix + ".json")
	var file := FileAccess.open("res://verification/phase2c/runtime_" + suffix + ".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	bay.get_tree().quit(2 if failed else 0)
