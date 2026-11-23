extends "res://scripts/program/module_bay_mission.gd"
var configuration_id := ""
var network: RefCounted
var primary
var regulator
var bypass
var source_gauge
var core_gauge
var cooling_core
var active_control: Node
var pressure := 0.0
var flow := 0.0
var temperature := 86.0
var network_time := 0.0
var stable_seconds := 0.0
var last_system_consequence_uuid := ""
var last_negative_signature: Dictionary = {}
var last_control_action: Dictionary = {}
var progress_seen: Dictionary = {}
var material_pool: Dictionary = {}
var flow_materials: Dictionary = {}
var core_warning: Array = []
var flow_player: AudioStreamPlayer3D
var machine_model: Node3D
var vibration_until := 0.0
func definition_path() -> String:
	return "res://config/missions/mb03.json"
func socket_script() -> String:
	return "res://scripts/intervention/interactables/coolant_socket.gd"
func machine_script() -> String:
	return "res://scripts/intervention/interactables/coolant_machine.gd"
func add_coolant_model(asset: String, at: Vector3) -> Node3D:
	var model = load("res://assets/models/mb03/" + asset + ".glb").instantiate()
	model.position = at
	share_materials(model)
	add_child(model)
	return model
func share_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(surface)
			if material != null and material.resource_name.begins_with("MAT_"):
				if not material_pool.has(material.resource_name):
					material_pool[material.resource_name] = material
				node.mesh.surface_set_material(surface, material_pool[material.resource_name])
	for child in node.get_children():
		share_materials(child)
func control(asset: String, kind: String, at: Vector3):
	var node = load("res://scripts/intervention/interactables/coolant_control.gd").new()
	node.kind = kind
	node.value = int(network.get(kind))
	node.bay = self
	node.interaction_id = "COOLANT_" + kind.to_upper()
	node.position = at
	var model = load("res://assets/models/mb03/" + asset + ".glb").instantiate()
	share_materials(model)
	node.add_child(model)
	add_child(node)
	return node
func instrument(asset: String, kind: String, at: Vector3):
	var node = load("res://scripts/intervention/interactables/coolant_instrument.gd").new()
	node.kind = kind
	node.bay = self
	node.interaction_id = "COOLANT_" + kind.to_upper()
	node.position = at
	var model = load("res://assets/models/mb03/" + asset + ".glb").instantiate()
	share_materials(model)
	node.add_child(model)
	add_child(node)
	return node
func setup_mission() -> void:
	configuration_id = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--coolant-config=") and definition.data.start_configurations.has(arg.trim_prefix("--coolant-config=")):
			configuration_id = arg.trim_prefix("--coolant-config=")
	if configuration_id.is_empty():
		configuration_id = program.next_configuration("MB03", definition.data.configuration_order)
	network = load("res://scripts/intervention/coolant_network.gd").new()
	network.configure(definition.data.start_configurations[configuration_id])
	setup_tools()
	add_coolant_model("coolant_manifold", Vector3(-1, 0, -3.9))
	primary = control("primary_valve", "primary", Vector3(-2.1, 0, -3.9))
	regulator = control("pressure_regulator", "regulator", Vector3(-1.0, 0, -3.9))
	bypass = control("bypass_valve", "bypass", Vector3(.15, 0, -3.9))
	source_gauge = instrument("pressure_gauge", "source", Vector3(-2.1, 2.35, -3.72))
	core_gauge = instrument("pressure_gauge", "output", Vector3(.15, 2.35, -3.72))
	cooling_core = instrument("cooling_core", "core", Vector3(2.9, 0, -2.5))
	add_static("CoolingCoreCollision", Vector3(2.9, .95, -2.5), Vector3(.85, 1.9, .6))
	routes = add_coolant_model("coolant_routes", Vector3.ZERO)
	for marker in ["FeedPipe", "CorePipe", "BypassPipe"]:
		flow_materials[marker] = tint_indicator(routes, marker + "Flow", Color(.08, .5, .7))
	core_warning = tint_indicator(cooling_core, "CoreWarningIndicator", Color(.9, .25, .025))
	module.lock_to(correct_socket)
	correct_socket.locked = true
	machine_model = machine.get_child(0)
	tint_indicator(machine, "CoreIndicator", Color(.9, .25, .025))
	pressure = network.evidence().pressure
	flow = network.evidence().flow
	flow_player = AudioStreamPlayer3D.new()
	var stream := load("res://assets/audio/intervention_v02/flow.wav").duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	flow_player.stream = stream
	flow_player.bus = "StationSFX"
	flow_player.position = Vector3(-1, 1, -3.2)
	flow_player.unit_size = 2
	flow_player.max_distance = 9
	add_child(flow_player)
	flow_player.play()
func mission_context() -> Dictionary:
	var evidence: Dictionary = network.evidence() if network != null else {}
	return {"configuration_id": configuration_id, "primary_setting": network.primary if network != null else -1,
		"regulator_setting": network.regulator if network != null else -1, "bypass_setting": network.bypass if network != null else -1,
		"system_targets": evidence, "last_system_consequence_uuid": last_system_consequence_uuid,
		"action_differs_from_last_negative": not last_negative_signature.is_empty() and history.last_signature != last_negative_signature}
func begin_action(family: String, object_id: String, target_id: String, orientation: int = -1, subsystem: String = "", tool: String = "") -> void:
	super.begin_action(family, object_id, target_id, orientation, subsystem, tool)
	if family in ["primary_adjust", "regulator_adjust", "bypass_adjust"]:
		history.exploration_actions += 1
func begin_adjustment(unit: Node, next: int, direction: int) -> Dictionary:
	var subsystem := "PRESSURE_CONTROL" if unit.kind == "regulator" else "COOLANT_PATH"
	begin_action(unit.kind + "_adjust", unit.interaction_id, unit.interaction_id, next, subsystem)
	var reversal := ""
	if not last_control_action.is_empty() and last_control_action.target == unit.interaction_id and next == last_control_action.before and unit.value == last_control_action.after:
		reversal = last_control_action.uuid
	var prefix: String = {"primary": "coolant_valve", "regulator": "regulator", "bypass": "bypass"}[unit.kind]
	telemetry.record(prefix + "_interaction", {"requested_direction": direction, "before": unit.value, "requested_setting": next, "reverses_action_uuid": reversal}, unit.interaction_id, unit.interaction_id)
	return {"interaction_uuid": telemetry.archive.back().event_uuid, "signature": history.last_signature.duplicate(true), "before": unit.value, "direction": direction, "reversal": reversal}
func finish_adjustment(unit: Node, next: int, action: Dictionary) -> void:
	if next == action.before:
		telemetry.record("control_limit_reached", {"cause_event_uuid": action.interaction_uuid, "setting": next, "action_signature": action.signature}, unit.interaction_id, unit.interaction_id)
		last_system_consequence_uuid = telemetry.archive.back().event_uuid
		history.invalid(action.signature, last_system_consequence_uuid)
		last_negative_signature = action.signature.duplicate(true)
		return
	var before: Dictionary = network.evidence()
	network.set(unit.kind, next)
	var after: Dictionary = network.evidence()
	var prefix: String = {"primary": "coolant_valve", "regulator": "regulator", "bypass": "bypass"}[unit.kind]
	telemetry.record(prefix + "_changed", {"before": action.before, "after": next, "cause_event_uuid": action.interaction_uuid, "reverses_action_uuid": action.reversal, "action_signature": action.signature}, unit.interaction_id, unit.interaction_id)
	var changed_id: String = telemetry.archive.back().event_uuid
	last_control_action = {"target": unit.interaction_id, "before": action.before, "after": next, "uuid": changed_id}
	var observations: Array[String] = []
	if after.flow < before.flow:
		observations.append("FLOW_DECREASED")
	elif after.flow > before.flow:
		observations.append("FLOW_INCREASED")
	if after.amplitude > before.amplitude:
		observations.append("OSCILLATION_INCREASED")
	elif after.amplitude < before.amplitude:
		observations.append("OSCILLATION_DECREASED")
	telemetry.record("pressure_changed", {"cause_event_uuid": changed_id, "before_target_bar": before.pressure * 4, "target_bar": after.pressure * 4, "oscillation_amplitude_bar": after.amplitude * 4, "observations": observations}, null, "COOLANT_NETWORK")
	var pressure_id: String = telemetry.archive.back().event_uuid
	telemetry.record("coolant_flow_changed", {"cause_event_uuid": changed_id, "before_target": before.flow, "target": after.flow, "bypass_flow": after.bypass_flow}, null, "COOLANT_NETWORK")
	last_system_consequence_uuid = telemetry.archive.back().event_uuid
	var adverse: bool = (after.flow < .55 and after.flow < before.flow) or (after.amplitude > .06 and after.amplitude > before.amplitude) or (after.pressure > 1.05 and after.pressure > before.pressure)
	if adverse:
		vibration_until = network_time + .6
		history.invalid(action.signature, pressure_id)
		last_negative_signature = action.signature.duplicate(true)
	for milestone in ["FLOW_RESTORED", "PRESSURE_STEADIED", "COOLING_BALANCED"]:
		var reached: bool = (after.flow >= .55 if milestone == "FLOW_RESTORED" else (after.amplitude <= .06 and after.pressure >= .58 if milestone == "PRESSURE_STEADIED" else after.safe))
		if reached and not progress_seen.has(milestone):
			progress_seen[milestone] = true
			progress(milestone)
func _process(delta: float) -> void:
	super._process(delta)
	if network == null or cooling_core == null:
		return
	network_time += delta
	var evidence: Dictionary = network.evidence()
	var oscillation := float(evidence.amplitude) * sin(network_time * 7.5)
	pressure = lerpf(pressure, maxf(0, evidence.pressure + oscillation), 1.0 - exp(-delta * 7))
	flow = lerpf(flow, evidence.flow, 1.0 - exp(-delta * 3))
	temperature = move_toward(temperature, 34.0 if evidence.safe else 89.0, delta * (13.0 if evidence.safe else 4.0))
	source_gauge.update_reading(4.0, temperature)
	core_gauge.update_reading(pressure * 4, temperature)
	cooling_core.update_reading(pressure * 4, temperature)
	for marker in flow_materials:
		var amount: float = evidence.inlet_flow if marker == "FeedPipe" else (evidence.bypass_flow if marker == "BypassPipe" else flow)
		for material in flow_materials[marker]:
			material.emission_energy_multiplier = .15 + clampf(amount, 0, 1) * 1.8
	for material in core_warning:
		var color := Color(.08, .65, .8) if evidence.safe else Color(.9, .25, .025)
		material.emission = color
		material.albedo_color = color
		material.emission_energy_multiplier = 1.7 if evidence.safe else 1.0 + .6 * sin(network_time * 5)
	if machine_model != null:
		machine_model.position.x = .003 * sin(network_time * 35) if network_time < vibration_until and phase < Phase.MACHINE_STARTUP else 0.0
	flow_player.volume_db = -34 + clampf(flow, 0, 1) * 13
	flow_player.pitch_scale = .8 + clampf(flow, 0, 1) * .2 + oscillation * .2
	if phase == Phase.MISSION_ACTIVE:
		stable_seconds = stable_seconds + delta if evidence.safe and active_control == null else 0.0
		if stable_seconds >= 4.0 and temperature <= 45:
			progress("THERMAL_RECOVERY")
			phase = Phase.MACHINE_STARTUP
			machine.startup()
func upstream_ready() -> bool:
	return network != null and network.evidence().safe
func diagnostic_for(kind: String) -> String:
	var state: Dictionary = network.evidence()
	match kind:
		"source": return "coolant.scan.source"
		"primary": return "coolant.scan.flow_low" if state.inlet_flow < .55 else "coolant.scan.inlet_flow"
		"bypass": return "coolant.scan.bypass_high" if state.bypass_flow > .15 else "coolant.scan.bypass_low"
		"regulator", "output":
			if state.amplitude > .06:
				return "coolant.scan.pressure_unstable"
			return "coolant.scan.pressure_low" if state.pressure < .58 else ("coolant.scan.pressure_high" if state.pressure > 1.05 else "coolant.scan.pressure_stable")
	return "coolant.scan.cooling_stable" if phase == Phase.COMPLETE else ("coolant.scan.cooling_recovering" if state.safe else "coolant.scan.cooling_failure")
func select_guidance(level: int, _early: bool) -> String:
	if phase == Phase.COMPLETE:
		return "help.coolant_pressure.complete"
	if level < 3:
		return "help.level%d.coolant_pressure" % level
	var state: Dictionary = network.evidence()
	var focus := "observe"
	if state.inlet_flow < .55:
		focus = "inlet"
	elif state.bypass_flow > .15 and not state.safe:
		focus = "bypass"
	elif state.amplitude > .06:
		focus = "regulator"
	return "help.level3.coolant_pressure." + focus
func start_verifier() -> void:
	if "--verify-mb03-independent" in OS.get_cmdline_user_args():
		verifier = load("res://verification/phase2c/independent_probe.gd").new()
		verifier.run.call_deferred(self)
	elif "--verify-mb03" in OS.get_cmdline_user_args():
		verifier = load("res://verification/phase2c/coolant_probe.gd").new()
		verifier.run.call_deferred(self)
	else:
		super.start_verifier()
