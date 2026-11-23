extends "res://verification/v02/cascade_probe.gd"
var selected := ""
func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(bay.get_viewport().get_texture().get_image().save_png("res://verification/localization/" + selected + "_" + name + ".png") == OK, "capture_" + name)
func select_language(code: String) -> void:
	var button: Button = bay.language_selector.buttons[code]
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		await wait_frames(2)
	check(bay.localization.locale == code and not bay.language_selector.opened, "select_" + code)
func switch_and_restore() -> void:
	var snapshot := JSON.stringify([bay.stage_history, bay.history.exact_repeats, bay.history.help_requests, bay.history.exploration_actions, bay.telemetry.archive.size()])
	var old_terminal: String = bay.terminal.screen.text
	var old_scanner: String = bay.scanner.screen.text
	var old_help: String = bay.ai_station.screen.text
	var prompt_key: String = bay.prompt_label.get_meta("localization_key")
	var tutorial_key: String = bay.tutorial_label.get_meta("localization_key")
	await action("language")
	await select_language("en" if selected == "tr" else "tr")
	await wait_frames(2)
	check(bay.terminal.screen.text != old_terminal, "terminal_switch")
	check(bay.scanner.screen.text != old_scanner, "scanner_switch")
	check(bay.ai_station.screen.text != old_help, "help_switch")
	check(bay.prompt_label.text == bay.localization.text(prompt_key), "context_prompt_switch")
	check(bay.tutorial_label.text == bay.localization.text(tutorial_key), "tutorial_switch")
	check(snapshot == JSON.stringify([bay.stage_history, bay.history.exact_repeats, bay.history.help_requests, bay.history.exploration_actions, bay.telemetry.archive.size()]), "switch_does_not_change_rules_or_events")
	await action("language")
	await select_language(selected)
	await wait_frames(2)
	check(bay.terminal.screen.text == old_terminal and bay.scanner.screen.text == old_scanner and bay.ai_station.screen.text == old_help, "switch_preserves_display_state")
func validate_displays() -> void:
	for binding in bay.localization.bindings:
		var label = binding.node.get_ref()
		if label == null:
			continue
		check(label.text != binding.key or binding.key.is_empty(), "resolved_" + binding.key)
		check(not label.text.contains("Ä±") and not label.text.contains("ÅŸ") and not label.text.contains("�"), "encoding_" + binding.key)
func fits(key: String, font_size: int, pixel_size: float, dimensions: Vector2, values: Dictionary = {}) -> bool:
	var text: String = bay.localization.text(key, values)
	var max_width := 0.0
	var lines := text.split("\n")
	for line in lines:
		max_width = maxf(max_width, bay.localization.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return max_width * pixel_size <= dimensions.x and lines.size() * bay.localization.font.get_height(font_size) * pixel_size <= dimensions.y
func run(world: Node) -> void:
	bay = world
	selected = bay.localization.locale
	await pause(1)
	check(RenderingServer.get_rendering_device() != null, "real_gpu")
	check(bay.language_selector.opened, "startup_selector")
	await screenshot("selector")
	await select_language(selected)
	await switch_and_restore()
	for character in "çÇğĞıIiİöÖşŞüÜ":
		check(bay.localization.font.has_char(character.unicode_at(0)), "glyph_" + character)
	# A test-only 3D plate permits visual inspection of every Turkish glyph.
	var glyphs := Label3D.new()
	glyphs.text = "ç Ç   ğ Ğ   ı I   i İ\nö Ö   ş Ş   ü Ü"
	glyphs.font = bay.localization.font
	glyphs.font_size = 36
	glyphs.pixel_size = .0018
	glyphs.position = Vector3(-3.55, 1.95, -1.8)
	bay.add_child(glyphs)
	await face(bay.terminal, Vector3(-2.9, 0, -.3), Vector3(0, 1.56, 0))
	await wait_frames(2)
	check(bay.prompt_label.text == bay.localization.text("interaction.terminal"), "context_prompt_localized")
	check(bay.tutorial_label.text == bay.localization.text("tutorial.explore"), "exploration_tutorial_localized")
	await screenshot("terminal_glyphs")
	glyphs.queue_free()
	await action("interact")
	check(bay.terminal.screen.text == bay.localization.text("mission.power_coupling.terminal_active"), "terminal_active_localized")
	await help()
	check(guidance_key() == "help.level1.power_coupling.early", "help_level1_equal_information")
	await face(bay.module, Vector3(-1.7, 0, 1.45), Vector3(0, .18, 0))
	await action("interact")
	await face(bay.correct_socket, Vector3(2.05, 0, .1), Vector3(0, .11, 0))
	await wait_frames(2)
	check(bay.tutorial_label.text == bay.localization.text("tutorial.rotate"), "rotation_tutorial_localized")
	await switch_and_restore()
	for i in 3:
		await action("place")
		await pause(.4)
	check(bay.history.exact_repeats == 2 and bay.help_salient, "same_repeat_policy")
	await aim(Vector3(0, 0, 1.2), Vector3(0, 0, .3))
	await action("put_down")
	await face(bay.relay, Vector3(0, 0, -2.1), Vector3(0, 1.45, .3))
	await action("interact")
	await pause(.5)
	check(not bay.relay_ready, "same_relay_rejection")
	await face(bay.cooling, Vector3(-1.35, 0, -2.1), Vector3(0, 1.45, .3))
	await action("inspect")
	await help()
	check(guidance_key() == "help.level2.power_coupling.cooling", "help_level2_equal_information")
	await help()
	check(guidance_key() == "help.level3.power_coupling.cooling", "help_level3_equal_information")
	await switch_and_restore()
	await screenshot("help3")
	await face(bay.scanner, Vector3(-3.2, 0, 2.9), Vector3(0, .2, 0))
	await action("interact")
	await wait_frames(2)
	check(bay.tutorial_label.text == bay.localization.text("tutorial.scan"), "scan_tutorial_localized")
	for node in [bay.cooling, bay.relay, bay.correct_socket]:
		var at: Vector3 = Vector3(node.global_position.x, 0, -2.1) if node != bay.correct_socket else Vector3(2.05, 0, .1)
		var offset := Vector3(0, 1.45, .3) if node != bay.correct_socket else Vector3(0, .11, 0)
		await face(node, at, offset)
		await action("place")
		await pause(.8)
		check(bay.scanner.screen.text == bay.localization.text(node.scan_status()), "scan_localized_" + node.name)
		await screenshot("scan_" + node.name)
	await switch_and_restore()
	await face(bay.cooling, Vector3(-1.35, 0, -2.1), Vector3(0, 1.45, .3))
	await action("interact")
	await pause(1)
	check(bay.cooling_ready, "same_cooling_dependency")
	await face(bay.relay, Vector3(0, 0, -2.1), Vector3(0, 1.45, .3))
	await action("interact")
	await pause(.7)
	check(bay.relay_ready, "same_relay_dependency")
	await aim(Vector3(-3.2, 0, 2.9), Vector3(-3.2, 1.05, 1.5))
	await action("put_down")
	await face(bay.module, Vector3(0, 0, 1.5), Vector3(0, .18, 0))
	await action("interact")
	await face(bay.correct_socket, Vector3(2.05, 0, .1), Vector3(0, .11, 0))
	await action("place")
	await pause(.4)
	check(not bay.correct_socket.locked, "same_orientation_rejection")
	await action("rotate_right")
	await pause(.25)
	await action("place")
	await pause(5)
	check(bay.stage == "SYSTEM_ACTIVE", "same_mission_completion")
	check(bay.terminal.screen.text == bay.localization.text("mission.power_coupling.terminal_complete"), "completion_terminal_localized")
	await switch_and_restore()
	await face(bay.terminal, Vector3(-2.9, 0, -.3), Vector3(0, 1.56, 0))
	await screenshot("complete")
	# Check every terminal/scanner/help variant at the unchanged production font sizes.
	for key in bay.localization.messages[selected]:
		if key.begins_with("mission.power_coupling.terminal_"):
			check(fits(key, 36, .0018, Vector2(.68, .43)), "fits_" + key)
		elif key.begins_with("diagnostic.") or key.begins_with("scanner."):
			check(fits(key, 28, .00078, Vector2(.245, .105)), "fits_" + key)
		elif key.begins_with("help."):
			check(fits("support.response", 28, .00125, Vector2(.75, .48), {"level": 3, "guidance": bay.localization.text(key)}), "fits_" + key)
	validate_displays()
	check(bay.localization.missing_keys.is_empty(), "no_missing_keys")
	report["locale"] = selected
	report["state_history"] = bay.stage_history
	report["all_gameplay_checks_passed"] = not failed
	bay.telemetry.export_trace("res://verification/localization/telemetry_" + selected + ".json")
	var file := FileAccess.open("res://verification/localization/runtime_" + selected + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	bay.get_tree().quit(2 if failed else 0)
