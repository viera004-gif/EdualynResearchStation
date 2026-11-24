extends SceneTree

const Sector := preload("res://scenes/main/competing_signals_phase1.tscn")
var world: Node3D
var failed := false
var profile: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(3))
	world = Sector.instantiate()
	root.add_child(world)
	await pause(.4)
	check(world.player.is_on_floor(), "first-person floor collision")
	check(await walk_to(Vector3(-2.65, 0, 1.95)), "walk from entry toward router")
	await capture("entry")
	await sample("idle_sector", .65)
	await press("TEST_LEVER")
	await sample("pulse_in_transit", .45)
	await pause(1.5)
	check(world.retained.launch.pulse_id == 1 and world.retained.reports.B.pulse_id == 0 and
		world.retained.conflict_nodes == ["B"] and not world.service_confirmed, "first test retains the disagreement")
	check("OUT   BACKBONE" in world.views.B.text and "SAMPLE #00   NO SIGNAL" in world.views.B.text and
		"RECEIVER   BACKBONE" in world.views.C.text, "B out, B sample, and C arrival are distinct")
	for witness in ["A", "B_IN", "B_OUT", "C"]:
		check(world.contacts[witness].visible and world.contacts[witness].position.y >
			world.contact_rest[witness], "latched physical witness " + witness)

	await press("TEST_LEVER")
	await press("ROUTE_SELECTOR")
	await pause(1.5)
	check(world.retained.launch.mode == "NORMAL" and world.network.mode == "ISOLATED" and
		"PREVIOUS TEST #02" in world.views.router.text, "in-flight switch applies only to next test")
	await press("TEST_LEVER")
	await pause(1.5)
	check(world.retained.launch.mode == "ISOLATED" and world.retained.arrivals.size() == 4 and
		world.retained.reports.B.pulse_id == 0, "isolating the branch leaves physical transfer and mismatch intact")

	check(await walk_to(Vector3(-.74, 0, .48)), "walk to compare junction")
	await press("B")
	await sample("retained_receipts", .65)
	await capture("conflict")
	check(await walk_to(Vector3(1.38, 0, 1.65)), "reach the corner")
	check(await walk_to(Vector3(1.38, 0, -2.67)), "walk around divider")
	check(await walk_to(Vector3(2.85, 0, -2.67)), "walk to downstream receiver")
	await press("C")
	check(world.events.back().metadata.receipt.sample.pulse_id == 3, "current receiver receipt remains available")
	await capture("receiver")

	check(await walk_to(Vector3(1.38, 0, -2.67)), "leave receiver")
	check(await walk_to(Vector3(1.38, 0, .45)), "return to junction aisle")
	await press("MEASUREMENT_TAP")
	await sample("configuration_change", .4)
	check(world.network.tap == "LIVE" and "PREVIOUS #03" in world.views.B.text, "reseating tap leaves prior evidence unchanged")
	check(await walk_to(Vector3(-2.65, 0, 1.95)), "carry revised test setup back to router")
	await press("TEST_LEVER")
	await pause(1.5)
	check(world.retained.conflict_nodes.is_empty() and not world.service_confirmed, "corrected sampling in isolation cannot confirm service")
	await press("ROUTE_SELECTOR")
	await press("TEST_LEVER")
	await pause(1.5)
	check(world.service_confirmed and world.retained.reports.B.pulse_id == 5 and
		"SERVICE CONFIRMED" in world.views.router.text, "fresh coherent normal-service test succeeds")
	await sample("normal_service_confirmation", .65)
	await capture("confirmed")
	check(await walk_to(Vector3(.48, 0, .46)), "return to the sampling coupling")
	await press("MEASUREMENT_TAP")
	check(world.network.tap == "HOLD" and not world.service_confirmed and
		"PREVIOUS TEST #05" in world.views.router.text, "repair is reversible and invalidates current confirmation")
	check(await walk_to(Vector3(-2.65, 0, 1.95)), "return to test reversed coupling")
	await press("TEST_LEVER")
	await pause(1.5)
	check(world.retained.launch.pulse_id == 6 and world.retained.conflict_nodes == ["B"] and
		world.retained.reports.B.sample_state == "STALE" and not world.service_confirmed, "reversal restores the physical/sample conflict")
	check(await walk_to(Vector3(.48, 0, .46)), "return to correct the coupling again")
	await press("MEASUREMENT_TAP")
	check(not world.service_confirmed and "PREVIOUS #06" in world.views.B.text, "re-repair cannot reuse the previous receipt")
	check(await walk_to(Vector3(-2.65, 0, 1.95)), "return for fresh confirmation")
	await press("TEST_LEVER")
	await pause(1.5)
	check(world.service_confirmed and world.retained.launch.pulse_id == 7 and
		world.retained.reports.B.pulse_id == 7 and world.retained.conflict_nodes.is_empty(), "re-repair is deterministic on a fresh pulse")
	check(traces_link(), "one outcome per accepted test with ordered witnesses")
	check(world.export_trace("res://.cache/mb04_phase1_trace.json") == OK, "local raw trace exported")
	if not profile.is_empty():
		check(profile.size() == 5, "all five rendered performance states sampled")
		var file := FileAccess.open("res://.cache/mb04_phase1_profile.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(profile, "\t"))
	quit(2 if failed else 0)

func traces_link() -> bool:
	var starts: Array = world.events.filter(func(event): return event.event_type == "signal_test_started")
	var results: Array = world.events.filter(func(event): return event.event_type == "signal_test_result")
	var progress: Array = world.events.filter(func(event): return event.event_type == "signal_pulse_progress")
	if starts.size() != 7 or results.size() != 7 or progress.size() != 28:
		return false
	var previous := ""
	for index in range(7):
		var attempt: String = starts[index].metadata.attempt_uuid
		if results[index].metadata.attempt_uuid != attempt or starts[index].metadata.previous_test_uuid != previous:
			return false
		previous = attempt
		var witnesses := progress.filter(func(event): return event.metadata.attempt_uuid == attempt)
		if witnesses.map(func(event): return event.metadata.arrival.witness) != ["A", "B_IN", "B_OUT", "C"]:
			return false
	var successful: Array = world.events.filter(func(event): return event.event_type == "standalone_success")
	var changes: Array = world.events.filter(func(event): return event.event_type in ["route_changed", "measurement_connection_changed"])
	return (results[1].metadata.previous_setup and starts[1].metadata.same_setup_as_previous and
		successful.map(func(event): return event.metadata.pulse_id) == [5, 7] and
		changes[0].metadata.last_test_uuid == starts[0].metadata.attempt_uuid and
		changes[0].metadata.in_flight_test_uuid == starts[1].metadata.attempt_uuid)

func press(id: String) -> void:
	var fixture: Area3D = world.fixtures[id]
	await aim_at(fixture.global_position)
	var targeted: bool = world.player.target() == fixture
	check(targeted, "ray reaches " + id)
	if not targeted:
		return
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = "interact"
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func aim_at(at: Vector3) -> void:
	var delta: Vector3 = at - world.player.camera.global_position
	world.player.rotation.y = atan2(-delta.x, -delta.z)
	world.player.pitch = atan2(delta.y, Vector2(delta.x, delta.z).length())
	await physics_frame
	await process_frame

func walk_to(at: Vector3) -> bool:
	await aim_at(Vector3(at.x, world.player.camera.global_position.y, at.z))
	var deadline := Time.get_ticks_msec() + 3400
	Input.action_press("move_forward")
	var reached := false
	while Time.get_ticks_msec() < deadline:
		var delta: Vector3 = at - world.player.position
		if Vector2(delta.x, delta.z).length() < .17:
			reached = true
			break
		await physics_frame
	Input.action_release("move_forward")
	await pause(.16)
	return reached

func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.cache/mb04_phase1_%s.png" % id) == OK, "capture " + id)

func sample(id: String, seconds: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var draws := 0
	var peak := 0
	var frames := 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < seconds * 1000000.0:
		await RenderingServer.frame_post_draw
		var count := root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		draws += count
		peak = maxi(peak, count)
		frames += 1
	var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
	profile[id] = {"frames": frames, "sample_seconds": elapsed, "mean_fps": frames / elapsed,
		"mean_visible_draw_calls": float(draws) / frames, "peak_visible_draw_calls": peak}

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

func check(condition: bool, detail: String) -> void:
	print("MB04 SECTOR ", detail, " = ", condition)
	failed = failed or not condition
