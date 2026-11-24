extends "res://scripts/program/module_bay_mission.gd"
const STRIPS := ["SourceFeed", "RelayFeed", "CouplerFeed", "CouplerRiser"]
const LIVE := Color(.08, .65, .8)
const STANDBY := Color(.09, .22, .27)
const DARK := Color(.018, .026, .035)
const FAULT := Color(.94, .30, .055)
var relay_a
var relay_b
var route_tester
var route_ready := false
var route_state := "BOTH_RELAYS_MISMATCHED"
var first_alignment: Dictionary = {}
var last_test: Dictionary = {}
var test_stale := false
var last_route_test_uuid := ""
var route_transfer := "UNENGAGED"
var transfer: Tween
var charge: MeshInstance3D
var charge_surface: StandardMaterial3D
var bus_status: Label3D
var bus_lamps: StandardMaterial3D
var scan_readings: Dictionary = {}
var delivered_tier := 0
var help_cursor := 0
var help_evidence: Dictionary = {}
func definition_path() -> String:
	return "res://config/missions/mb02.json"
func socket_script() -> String:
	return "res://scripts/intervention/interactables/polarity_socket.gd"
func setup_mission() -> void:
	setup_tools()
	scanner.resolve_scan_readout = scan_readout
	ai_station.show_message("polarity.support_standby")
	ai_station.screen.modulate = Color(.36, .51, .55)
	for marker in ["DiagnosticOptic", "AIRequestButton"]:
		tint_indicator(ai_station, marker, Color(.07, .14, .17))
	var dock := find_child("DockIndicator", true, false)
	if dock != null:
		tint_indicator(dock, "DockIndicator", Color(.07, .15, .18))
	relay_a = relay_unit("a", "RELAY_A", Vector3(-1.35, 0, -3.9))
	relay_b = relay_unit("b", "RELAY_B", Vector3(0, 0, -3.9))
	route_tester = make_interactable("mb02/relay_coupling_assembly", "res://scripts/intervention/interactables/route_tester.gd", "ROUTE_TEST", Vector3(-2.2, 0, -3.9))
	routes = load("res://assets/models/mb02/polarity_routes.glb").instantiate()
	add_child(routes)
	var connectors = load("res://assets/models/mb02/polarity_connectors.glb").instantiate()
	connectors.position.z = -3.9
	add_child(connectors)
	# The functional module starts seated. No cooling repair or module-key puzzle here.
	module.lock_to(correct_socket)
	correct_socket.locked = true
	charge_surface = panel_material(LIVE, 2.0)
	charge = panel_box(Vector3.ZERO, Vector3(.13, .032, .028), charge_surface)
	charge.hide()
	build_secondary_bus()
	update_route(false)
func relay_unit(asset: String, id: String, at: Vector3):
	var node = load("res://scripts/intervention/interactables/polarity_relay.gd").new()
	node.bay = self
	node.interaction_id = id
	node.name = id
	node.position = at
	node.orientation_step = int(definition.data.relay_units[id].initial_orientation)
	node.required_orientation = int(definition.data.relay_units[id].required_orientation)
	node.add_child(load("res://assets/models/mb02/polarity_relay_" + asset + ".glb").instantiate())
	add_child(node)
	return node
func mission_context() -> Dictionary:
	return {"relay_a_orientation": relay_a.orientation_step if is_instance_valid(relay_a) else -1,
		"relay_b_orientation": relay_b.orientation_step if is_instance_valid(relay_b) else -1,
		"route_ready": route_ready, "route_state": route_state, "route_transfer": route_transfer,
		"last_test_configuration": last_test.get("configuration", ""), "last_test_stale": test_stale}
func upstream_ready() -> bool:
	return route_ready
func configuration() -> String:
	if relay_a.aligned() and relay_b.aligned():
		return "ROUTE_ALIGNED"
	if relay_a.aligned():
		return "PHASE_COLLAPSE_AT_B"
	return "INPUT_BLOCKED_AT_A" if relay_b.aligned() else "BOTH_RELAYS_MISMATCHED"
func relay_changed(unit: Node) -> void:
	if unit.aligned() and not first_alignment.has(unit.interaction_id):
		first_alignment[unit.interaction_id] = true
		progress(unit.interaction_id + "_ALIGNED")
	update_route(true)
	if route_state == "ROUTE_ALIGNED":
		route_tester.set_status("polarity.test_standby")
	elif last_test.is_empty():
		route_tester.set_status("polarity.source_ready")

func configuration_moving() -> void:
	if not last_test.is_empty():
		test_stale = true
		route_tester.set_status("polarity.test_stale")
	if transfer != null and transfer.is_running() and not route_ready:
		transfer.kill()
		charge.hide()
		relay_a.fault_strength(0.0)
		relay_b.fault_strength(0.0)
		paint_preview()

func update_route(record: bool) -> void:
	route_state = configuration()
	if not route_ready:
		route_transfer = "STANDBY_READY" if route_state == "ROUTE_ALIGNED" else "UNENGAGED"
		paint_preview()
	for unit in [relay_a, relay_b]:
		tint_indicator(unit, "PolarityIndicator", LIVE if route_ready else (STANDBY if unit.aligned() else FAULT.darkened(.55)))
		unit.refresh()
	correct_socket.set_indicator(LIVE if route_transfer == "ENERGIZED" else STANDBY, .45 if route_transfer == "ENERGIZED" else 0.0)
	if record:
		record_route(route_transfer, "CORE" if route_transfer == "ENERGIZED" else "NONE")

func paint_preview() -> void:
	set_strip(0, STANDBY, .5)
	set_strip(1, STANDBY if relay_a.aligned() else DARK, .5)
	set_strip(2, STANDBY if route_state == "ROUTE_ALIGNED" else DARK, .3)
	set_strip(3, DARK, 0.0)

func set_strip(index: int, color: Color, intensity: float) -> void:
	for surface in tint_indicator(routes, STRIPS[index] + "Flow", color):
		surface.emission_energy_multiplier = intensity

func record_route(state: String, reached: String) -> void:
	telemetry.record("power_route_changed", {"configuration": route_state,
		"transfer_state": state, "flow_reaches": reached, "test_attempt_uuid": last_route_test_uuid}, null, "POWER_ROUTE")

func test_route() -> void:
	if route_ready or route_tester.moving or relay_a.moving or relay_b.moving:
		return
	begin_action("route_test", "ROUTE_TEST", "POWER_ROUTE", relay_a.orientation_step * 4 + relay_b.orientation_step, "POWER_ROUTE")
	route_state = configuration()
	var tested := Vector2i(relay_a.orientation_step, relay_b.orientation_step)
	var failure_location := "" if route_state == "ROUTE_ALIGNED" else ("RELAY_B" if relay_a.aligned() else "RELAY_A")
	var repeated: bool = last_test.get("pair") == tested
	last_test = {"pair": tested, "configuration": route_state, "failure_location": failure_location}
	test_stale = false
	telemetry.record("route_test_attempt", {"tested_configuration": route_state, "repeated_configuration": repeated,
		"failure_location": failure_location}, "ROUTE_TEST", "POWER_ROUTE")
	last_route_test_uuid = telemetry.archive.back().event_uuid
	if route_state != "ROUTE_ALIGNED":
		telemetry.record("relay_configuration_invalid", {"failure_state": route_state, "failure_location": failure_location,
			"test_attempt_uuid": last_route_test_uuid}, "ROUTE_TEST", "POWER_ROUTE")
		register_failure()
		set_stage(route_state)
		route_tester.reject(route_state)
		var dock := find_child("DockIndicator", true, false)
		if dock != null:
			tint_indicator(dock, "DockIndicator", Color(.12, .27, .31))
		show_transfer(failure_location)
	else:
		route_ready = true
		route_transfer = "ENGAGING"
		telemetry.record("relay_configuration_valid", {"test_attempt_uuid": last_route_test_uuid}, "ROUTE_TEST", "POWER_ROUTE")
		progress("ROUTE_READY")
		route_tester.engage()
		for unit in [relay_a, relay_b]:
			unit.latch()
		phase = Phase.MACHINE_STARTUP
		show_transfer("")

func show_transfer(failure_location: String) -> void:
	if transfer != null:
		transfer.kill()
	relay_a.fault_strength(0.0)
	relay_b.fault_strength(0.0)
	paint_preview()
	var both := route_state == "BOTH_RELAYS_MISMATCHED"
	var last_segment := 0 if failure_location == "RELAY_A" else (1 if failure_location == "RELAY_B" else 3)
	var end_points := [Vector3(-1.35, .74, -3.61), Vector3(0, .74, -3.61),
		Vector3(1.15, .74, -3.61), Vector3(1.15, 1.38, -3.61)]
	charge.position = Vector3(-2.35, .74, -3.61)
	charge_surface.emission = LIVE
	charge.show()
	transfer = create_tween()
	for segment in range(last_segment + 1):
		transfer.tween_property(charge, "position", end_points[segment], .24)
		var blocked := not failure_location.is_empty() and segment == last_segment
		transfer.tween_callback(set_strip.bind(segment, FAULT if blocked else LIVE, 2.0))
	if failure_location.is_empty():
		transfer.tween_callback(transfer_online)
		return
	var stopped_unit: Node = relay_a if failure_location == "RELAY_A" else relay_b
	transfer.tween_callback(func():
		stopped_unit.fault_strength(1.6)
		charge_surface.emission = FAULT
		audio.play_cue("trace" if stopped_unit == relay_b else "invalid", stopped_unit.global_position)
		record_route("TEST_BLOCKED", failure_location))
	if both:
		transfer.tween_property(charge, "position", Vector3(-1.95, .74, -3.61), .22)
	transfer.tween_callback(charge.hide)
	transfer.tween_method(stopped_unit.fault_strength, 1.6, 0.0, 1.15)
	transfer.tween_callback(paint_preview)

func transfer_online() -> void:
	charge.hide()
	route_transfer = "ENERGIZED"
	update_route(true)
	machine.startup()

func machine_online() -> void:
	bus_lamps.emission = LIVE
	bus_lamps.emission_energy_multiplier = 1.65
	localization.bind_label(bus_status, "polarity.bus_online")
	audio.play_cue("flow", bus_status.global_position)
	super.machine_online()

func panel_material(color: Color, energy: float) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.emission_enabled = energy > 0
	surface.emission = color
	surface.emission_energy_multiplier = energy
	return surface

func panel_box(at: Vector3, dimensions: Vector3, surface: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	part.mesh = shape
	part.material_override = surface
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	return part

func build_secondary_bus() -> void:
	var at := Vector3(3.28, 2.03, -4.19)
	panel_box(at, Vector3(1.05, .42, .09), panel_material(Color(.08, .12, .15), 0.0))
	bus_lamps = panel_material(Color(.35, .22, .08), .32)
	for x in [-.25, 0.0, .25]:
		panel_box(at + Vector3(x, -.12, .06), Vector3(.16, .024, .02), bus_lamps)
	bus_status = Label3D.new()
	bus_status.position = at + Vector3(0, .025, .054)
	bus_status.font_size = 30
	bus_status.pixel_size = .00135
	bus_status.modulate = Color(.67, .85, .92)
	add_child(bus_status)
	localization.bind_label(bus_status, "polarity.bus_standby")

func scan_readout(target_id: String, diagnostic: String) -> Dictionary:
	var signature := [diagnostic, route_state, route_transfer, last_test.get("configuration", ""), test_stale]
	match target_id:
		"RELAY_A": signature.append(relay_a.orientation_step)
		"RELAY_B": signature.append(relay_b.orientation_step)
		"ROUTE_TEST": signature.append(Vector2i(relay_a.orientation_step, relay_b.orientation_step))
	var unchanged: bool = scan_readings.get(target_id) == signature
	if diagnostic != "polarity.scanner_settling":
		scan_readings[target_id] = signature
	return {"readout": "polarity.scan_unchanged" if unchanged else diagnostic, "unchanged": unchanged}

func request_help() -> void:
	ai_station.screen.modulate = Color(.48, .8, .9)
	super.request_help()

func guidance_level(_requested: int, _early: bool) -> int:
	var new_evidence := false
	for index in range(help_cursor, telemetry.archive.size()):
		var event: Dictionary = telemetry.archive[index]
		var data: Dictionary = event.metadata
		var evidence := ""
		match event.event_type:
			"relay_unit_rotated":
				evidence = str(["turn", event.object_id, data.orientation_step])
			"subsystem_inspected", "scanner_scan_completed":
				if not data.get("unchanged", false) and data.diagnostic not in ["diagnostic.available", "polarity.scanner_settling"]:
					evidence = str(["read", event.target_id, data.diagnostic, data.relay_a_orientation,
						data.relay_b_orientation, data.last_test_configuration, data.last_test_stale])
			"relay_configuration_invalid":
				evidence = str(["test", data.relay_a_orientation, data.relay_b_orientation, data.failure_state])
		if not evidence.is_empty() and not help_evidence.has(evidence):
			help_evidence[evidence] = true
			new_evidence = true
	help_cursor = telemetry.archive.size()
	if delivered_tier == 0 or new_evidence:
		delivered_tier = mini(delivered_tier + 1, 3)
	return delivered_tier
func select_guidance(level: int, early: bool) -> String:
	if phase == Phase.COMPLETE:
		return "help.relay_polarity.complete"
	if level == 1:
		return "help.level1.relay_polarity.early" if early else "help.level1.relay_polarity"
	var target := "a" if not relay_a.aligned() else ("b" if not relay_b.aligned() else "test")
	return "help.level%d.relay_polarity.%s" % [level, target]
func start_verifier() -> void:
	if "--verify-mb03-progression" in OS.get_cmdline_user_args():
		verifier = load("res://verification/phase2c/progression_probe.gd").new()
		verifier.run.call_deferred(self)
	elif "--verify-mb02-independent" in OS.get_cmdline_user_args():
		verifier = load("res://verification/phase2b/independent_polarity_probe.gd").new()
		verifier.run.call_deferred(self)
	elif "--verify-mb02" in OS.get_cmdline_user_args():
		verifier = load("res://verification/phase2b/polarity_probe.gd").new()
		verifier.run.call_deferred(self)
	else:
		super.start_verifier()
