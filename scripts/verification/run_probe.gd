extends RefCounted
var report: Dictionary = {}
var bay
var failed: bool = false
func check(condition: bool, name: String) -> void:
	report[name] = condition
	print("PROBE ", name, "=", condition)
	if not condition:
		failed = true
func wait_frames(count: int) -> void:
	for i in count:
		await bay.get_tree().process_frame
func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://verification/captures/" + name + ".png"
	var error = bay.get_viewport().get_texture().get_image().save_png(path)
	check(error == OK, "capture_" + name)
func aim(at: Vector3, target: Vector3) -> void:
	bay.player.global_position = at
	bay.player.velocity = Vector3.ZERO
	var offset := target - (at + Vector3(0, 1.61, 0))
	bay.player.rotation.y = atan2(-offset.x, -offset.z)
	bay.player.pitch = atan2(offset.y, Vector2(offset.x, offset.z).length())
	bay.player.camera.rotation.x = bay.player.pitch
	await bay.get_tree().physics_frame
	await bay.get_tree().physics_frame
func action(name: String) -> void:
	var input := InputEventAction.new()
	input.action = name
	input.pressed = true
	Input.parse_input_event(input)
	await bay.get_tree().process_frame
	input = InputEventAction.new()
	input.action = name
	input.pressed = false
	Input.parse_input_event(input)
	await bay.get_tree().process_frame
func run(world: Node) -> void:
	bay = world
	print("PROBE_BEGIN")
	await wait_frames(120)
	check(RenderingServer.get_rendering_device() != null, "rendering_device")
	var collision_report: Dictionary = bay.metrics.report(bay)
	check(collision_report.collision_shapes == {"BoxShape3D": 13, "CapsuleShape3D": 1}, "simple_collision_only")
	check(bay.player.is_on_floor(), "floor_contact")
	await screenshot("01_entry")
	var start: Vector3 = bay.player.global_position
	Input.action_press("move_forward")
	await wait_frames(35)
	Input.action_release("move_forward")
	await wait_frames(12)
	check(start.distance_to(bay.player.global_position) > .25, "first_person_movement")
	await aim(Vector3(0, 0, 3.85), Vector3(0, 1.61, 4.4))
	Input.action_press("move_forward")
	await wait_frames(50)
	Input.action_release("move_forward")
	check(bay.player.global_position.z < 4.2, "wall_collision_blocks")
	await aim(Vector3(-1.7, 0, 1.2), Vector3(-1.7, 1.61, .15))
	Input.action_press("move_forward")
	await wait_frames(40)
	Input.action_release("move_forward")
	check(bay.player.global_position.z > .8, "bench_collision_blocks")
	var yaw: float = bay.player.rotation.y
	var look := InputEventMouseMotion.new()
	look.relative = Vector2(22, -4)
	Input.parse_input_event(look)
	await wait_frames(3)
	check(abs(bay.player.rotation.y - yaw) > .01, "mouse_look")
	await aim(Vector3(-2.9, 0, -.30), Vector3(-2.9, 1.56, -2.35))
	check(bay.player.target() == bay.terminal, "terminal_physics_raycast")
	await action("interact")
	check(bay.phase == bay.Phase.MISSION_ACTIVE, "mission_started")
	await screenshot("02_terminal")
	await aim(Vector3(-1.7, 0, 1.45), Vector3(-1.7, 1.26, .15))
	check(bay.player.target() == bay.module, "module_physics_raycast")
	await action("interact")
	check(bay.player.held == bay.module and bay.module.get_parent() == bay.player.carry_anchor, "pickup_3d")
	await screenshot("03_carried_module")
	await action("rotate_right")
	await wait_frames(16)
	check(bay.module.orientation_step == 1 and abs(bay.module.rotation.y - PI / 2) < .02, "rotation_3d")
	await aim(Vector3(.95, 0, .10), Vector3(.95, 1.16, -1.99))
	check(bay.player.target() == bay.wrong_socket, "wrong_socket_physics_raycast")
	await action("place")
	check(bay.player.held == bay.module and bay.wrong_socket.feedback_light.light_energy > .1, "wrong_socket_rejection")
	await screenshot("04_wrong_socket")
	# Correct interface with an incorrect key is separately rejected.
	await action("rotate_left")
	await wait_frames(16)
	await aim(Vector3(2.05, 0, .10), Vector3(2.05, 1.16, -1.99))
	check(bay.player.target() == bay.correct_socket, "correct_socket_physics_raycast")
	await action("place")
	check(bay.player.held == bay.module, "orientation_rejection")
	await action("rotate_right")
	await wait_frames(16)
	await action("place")
	check(bay.module.get_parent() == bay.correct_socket and bay.player.held == null, "correct_socket_snap")
	check(bay.phase == bay.Phase.MACHINE_STARTUP, "machine_startup")
	await wait_frames(20)
	await screenshot("05_machine_startup")
	var rotor_start: Basis = bay.machine.rotor.basis
	await bay.get_tree().create_timer(5).timeout
	check(bay.phase == bay.Phase.COMPLETE and bay.machine.state == bay.machine.State.ACTIVE, "mission_complete")
	check(not bay.machine.rotor.basis.is_equal_approx(rotor_start), "ring_realtime_rotation")
	check(bay.machine.indicator_light.light_energy > 1, "machine_live_lights")
	check(bay.correct_socket.locked and bay.correct_socket.feedback_light.light_energy > .9, "correct_socket_stable_light")
	check(bay.wrong_socket.feedback_light.light_energy < .001, "wrong_socket_pulse_ended")
	check(bay.audio.cue_counts == {"terminal": 1, "pickup": 1, "rotate": 3, "invalid": 2, "lock": 1, "startup": 1, "hum": 1}, "audio_cue_counts")
	check(bay.audio.nonzero_frames > 1000 and bay.audio.mixed_peak > .00001, "audio_bus_nonzero")
	check(bay.audio.mixed_peak < .5, "audio_bus_headroom")
	check(bay.audio.hum_started and bay.audio.voices["hum"].playing, "active_audio_loop")
	check(bay.audio.voices["hum"].stream.loop_end == 96000, "hum_full_two_second_loop")
	await aim(Vector3(0, 0, 1.95), Vector3(1.35, 1.5, -2.6))
	await screenshot("06_active_bay")
	await action("release_mouse")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "escape_releases_mouse")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await wait_frames(120)
	var deadline := Time.get_ticks_msec() + 12000
	if not bay.telemetry.base_url.contains(":1/"):
		while not bay.telemetry.session_closed and Time.get_ticks_msec() < deadline:
			await bay.get_tree().process_frame
	report["telemetry_session"] = bay.telemetry.session_uuid
	report["telemetry_acknowledged"] = bay.telemetry.acknowledged
	report["telemetry_pending"] = bay.telemetry.pending.size()
	report["telemetry_complete"] = bay.telemetry.session_closed
	report["fps_engine"] = Engine.get_frames_per_second()
	report["fps_measured_mean"] = float(bay.frame_count - 90) / maxf(.001, bay.measured_seconds)
	report["frames"] = bay.frame_count
	report["profile"] = bay.metrics.report(bay)
	report["audio"] = bay.audio.report()
	report["all_gameplay_checks_passed"] = not failed
	var suffix := "offline" if bay.telemetry.base_url.contains(":1/") else "online"
	bay.telemetry.export_trace("res://verification/telemetry_" + suffix + ".json")
	var file := FileAccess.open("res://verification/runtime_" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("VERIFY_REPORT ", JSON.stringify(report))
	bay.get_tree().quit(2 if failed else 0)
