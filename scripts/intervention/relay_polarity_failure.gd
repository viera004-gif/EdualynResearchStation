extends "res://scripts/program/module_bay_mission.gd"
var relay_a
var relay_b
var route_tester
var route_ready := false
var route_state := "BOTH_RELAYS_MISMATCHED"
var first_alignment: Dictionary = {}
func definition_path() -> String:
	return "res://config/missions/mb02.json"
func socket_script() -> String:
	return "res://scripts/intervention/interactables/polarity_socket.gd"
func setup_mission() -> void:
	setup_tools()
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
		"route_ready": route_ready, "route_state": route_state}
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
func update_route(record: bool) -> void:
	route_state = configuration()
	var blue := Color(.08, .65, .8)
	var amber := Color(.9, .25, .025)
	var dark := Color(.018, .026, .035)
	pulse_route("SourceFeed", blue if relay_a.aligned() else amber, .5)
	pulse_route("RelayFeed", (blue if relay_b.aligned() else amber) if relay_a.aligned() else dark, .5)
	pulse_route("CouplerFeed", blue if route_state == "ROUTE_ALIGNED" else dark, .5)
	pulse_route("CouplerRiser", blue if route_state == "ROUTE_ALIGNED" else dark, .5)
	for unit in [relay_a, relay_b]:
		tint_indicator(unit, "PolarityIndicator", blue if unit.aligned() else amber)
		unit.refresh()
	correct_socket.set_indicator(blue if route_ready else amber, .45)
	if record:
		telemetry.record("power_route_changed", {"configuration": route_state, "flow_reaches": "COUPLER" if route_state == "ROUTE_ALIGNED" else ("RELAY_B" if relay_a.aligned() else "RELAY_A")}, null, "POWER_ROUTE")
func test_route() -> void:
	if route_ready or route_tester.moving or relay_a.moving or relay_b.moving:
		return
	begin_action("route_test", "ROUTE_TEST", "POWER_ROUTE", relay_a.orientation_step * 4 + relay_b.orientation_step, "POWER_ROUTE")
	route_state = configuration()
	if route_state != "ROUTE_ALIGNED":
		telemetry.record("relay_configuration_invalid", {"failure_state": route_state}, "ROUTE_TEST", "POWER_ROUTE")
		register_failure()
		set_stage(route_state)
		route_tester.reject(route_state)
		update_route(true)
		var marker := "RelayFeedFlow" if route_state == "PHASE_COLLAPSE_AT_B" else "SourceFeedFlow"
		for material in tint_indicator(routes, marker, Color(.9, .25, .025)):
			var pulse := create_tween()
			pulse.tween_property(material, "emission_energy_multiplier", 4.0, .12)
			pulse.tween_property(material, "emission_energy_multiplier", .3, .18)
			pulse.tween_property(material, "emission_energy_multiplier", 1.7, .25)
	else:
		route_ready = true
		telemetry.record("relay_configuration_valid", {}, "ROUTE_TEST", "POWER_ROUTE")
		progress("ROUTE_READY")
		update_route(true)
		route_tester.engage()
		for unit in [relay_a, relay_b]:
			unit.latch()
		phase = Phase.MACHINE_STARTUP
		machine.startup()
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
