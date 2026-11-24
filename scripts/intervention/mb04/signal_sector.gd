extends Node3D
## Standalone Phase 1 graybox. The program catalog does not reference this scene.

const Network := preload("res://scripts/intervention/mb04/signal_network.gd")
const Player := preload("res://scripts/player/first_person.gd")
const CONTENT_ID := "MODULE_BAY_04_COMPETING_SIGNALS"
const SOURCE := Vector3(-2.72, .61, .85)
const A := Vector3(-2.72, .61, -1.65)
const B_IN := Vector3(-.89, .61, -1.65)
const B_OUT := Vector3(-.48, .61, -1.65)
const TURN := Vector3(2.85, .61, -1.65)
const C := Vector3(2.85, .61, -3.18)
const AUX := Vector3(-.48, .61, -.43)

class Fixture extends "res://scripts/interaction/interactable.gd":
	var prompt_text: String

	func prompt() -> String:
		return prompt_text

	func interact(_player: Node) -> void:
		bay.operate(interaction_id)

class LocalTrace extends "res://scripts/intervention/cascade_telemetry.gd":
	func _ready() -> void:
		# Reuse the event envelope without opening a transport or progression session.
		set_process(false)

var network := Network.new()
var player: CharacterBody3D
var retained: Dictionary = {}
var retained_attempt_uuid := ""
var in_flight_attempt_uuid := ""
var telemetry := LocalTrace.new()
var events: Array[Dictionary]:
	get:
		return telemetry.archive
var running := false
var service_confirmed := false
var views: Dictionary = {}
var contacts: Dictionary = {}
var contact_rest: Dictionary = {}
var contact_motion: Dictionary = {}
var control_motion: Dictionary = {}
var fixtures: Dictionary = {}
var pulse: MeshInstance3D
var router_lever: MeshInstance3D
var selector: MeshInstance3D
var sample_tap: MeshInstance3D
var auxiliary_contact: MeshInstance3D
var prompt_label: Label
var shell := material(Color(.22, .25, .28))
var dark := material(Color(.055, .073, .086))
var trim := material(Color(.49, .58, .60))
var mechanism := material(Color(.84, .62, .27))
var charge := material(Color(.63, .90, 1.0), 1.1)

func _ready() -> void:
	telemetry.content_id = CONTENT_ID
	add_child(telemetry)
	bind_inputs()
	build_room()
	build_router()
	build_node("A", "A   /   SOURCE WITNESS", A, ["A"])
	build_node("B", "B   /   JUNCTION", (B_IN + B_OUT) * .5, ["B_IN", "B_OUT"])
	build_node("C", "C   /   RECEIVER", C, ["C"])
	build_tap()
	for segment in [[SOURCE, A], [A, B_IN], [B_IN, B_OUT], [B_OUT, TURN], [TURN, C], [B_OUT, AUX]]:
		build_conduit(segment[0], segment[1])
	auxiliary_contact = box(self, AUX + Vector3.UP * .14, Vector3(.14, .12, .15), mechanism)
	contacts["AUX"] = auxiliary_contact
	label(AUX + Vector3.UP * .39).text = "AUX BRANCH"
	pulse = box(self, SOURCE, Vector3(.19, .095, .19), charge)
	pulse.hide()
	player = Player.new()
	player.bay = self
	player.position = Vector3(-2.65, .04, 3.12)
	add_child(player)
	for witness in contacts:
		contact_rest[witness] = contacts[witness].position.y
	build_hud()
	update_displays()
	record("game_started", {"content_version": "competing_signals_phase1", "setup": network.setup(),
		"retained_sample": {"node": "B", "pulse_id": 0, "detected": false, "sample_state": "STALE"}})

func _process(_delta: float) -> void:
	var target = player.target()
	prompt_label.text = target.prompt() if target != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else ""

func operate(id: String) -> void:
	match id:
		"TEST_LEVER":
			if not running:
				run_pulse()
		"ROUTE_SELECTOR":
			var before := network.setup()
			network.set_mode("ISOLATED" if network.mode == "NORMAL" else "NORMAL")
			move_control(selector, "rotation:z", -.42 if network.mode == "ISOLATED" else .42)
			auxiliary_contact.rotation.y = PI / 2 if network.mode == "ISOLATED" else 0.0
			configuration_changed("route_changed", id, before)
		"MEASUREMENT_TAP":
			var before := network.setup()
			network.set_tap("LIVE" if network.tap == "HOLD" else "HOLD")
			move_control(sample_tap, "position:x", .21 if network.tap == "LIVE" else -.21)
			configuration_changed("measurement_connection_changed", id, before)
		_:
			if views.has(id):
				record("node_inspected", {"node": id, "receipt": node_receipt(id),
					"last_test_uuid": retained_attempt_uuid}, id)

func configuration_changed(kind: String, id: String, before: Dictionary) -> void:
	service_confirmed = false
	record(kind, {"before": before, "after": network.setup(),
		"last_test_uuid": retained_attempt_uuid, "in_flight_test_uuid": in_flight_attempt_uuid}, id)
	update_displays()

func move_control(part: Node3D, property: String, value: float) -> void:
	if control_motion.has(part):
		control_motion[part].kill()
	var motion := create_tween().set_trans(Tween.TRANS_SINE)
	control_motion[part] = motion
	motion.tween_property(part, property, value, .18)

func run_pulse() -> void:
	running = true
	var snapshot := network.launch()
	var result := network.resolve(snapshot)
	var previous := retained.get("launch", {}) as Dictionary
	var repeated: bool = not previous.is_empty() and previous.mode == snapshot.mode and previous.tap == snapshot.tap
	var attempt := telemetry.uuid()
	var test_context := {"attempt_uuid": attempt, "previous_test_uuid": retained_attempt_uuid,
		"pulse_id": snapshot.pulse_id, "launch": snapshot}
	in_flight_attempt_uuid = attempt
	record("signal_test_started", test_context.merged({"same_setup_as_previous": repeated}), "TEST_LEVER")
	update_displays()
	var throw := create_tween()
	throw.tween_property(router_lever, "rotation:z", -.63, .13)
	throw.tween_property(router_lever, "rotation:z", 0.0, .19)
	pulse.position = SOURCE
	pulse.show()
	var travel := create_tween()
	for arrival in result.arrivals:
		if arrival.witness == "C":
			travel.tween_property(pulse, "position", TURN, .22)
		travel.tween_property(pulse, "position", witness_position(arrival.witness), .25)
		travel.tween_callback(on_arrival.bind(arrival, test_context))
	await travel.finished
	pulse.hide()
	running = false
	in_flight_attempt_uuid = ""
	retained = result
	retained_attempt_uuid = attempt
	update_contact_receipts()
	record("signal_test_result", test_context.merged({"result": result, "previous_setup": network.is_previous(result),
		"physical_witnesses": {"A": network.has_arrival(result, "A"), "B_IN": network.has_arrival(result, "B_IN"),
			"B_OUT": network.has_arrival(result, "B_OUT"), "C": network.has_arrival(result, "C")}}), "TEST_LEVER")
	if not result.conflict_nodes.is_empty():
		record("signal_conflict_exposed", {"attempt_uuid": attempt, "pulse_id": snapshot.pulse_id,
			"nodes": result.conflict_nodes}, "TEST_LEVER")
	var was_confirmed := service_confirmed
	service_confirmed = network.confirms_current_service(result)
	if service_confirmed and not was_confirmed:
		record("system_stabilized", test_context, "TEST_LEVER")
		record("standalone_success", test_context, "TEST_LEVER")
	update_displays()

func witness_position(id: String) -> Vector3:
	match id:
		"A": return A
		"B_IN": return B_IN
		"B_OUT": return B_OUT
		"C": return C
		"AUX": return AUX
	return SOURCE

func on_arrival(arrival: Dictionary, test_context: Dictionary) -> void:
	var was_latched := not retained.is_empty() and network.has_arrival(retained, arrival.witness)
	var contact: MeshInstance3D = contacts[arrival.witness]
	contact.material_override = charge
	var bounce := create_tween()
	contact_motion[arrival.witness] = bounce
	var rest := contact.position.y
	bounce.tween_property(contact, "position:y", rest + .08, .09)
	bounce.tween_property(contact, "position:y", rest, .10)
	bounce.tween_callback(func(): contact.material_override = charge if was_latched else mechanism)
	record("signal_pulse_progress", test_context.merged({"arrival": arrival}), arrival.witness)

func update_contact_receipts() -> void:
	for witness in contacts:
		if contact_motion.has(witness):
			contact_motion[witness].kill()
		var contact: MeshInstance3D = contacts[witness]
		var latched := network.has_arrival(retained, witness)
		contact.position.y = contact_rest[witness] + (.055 if latched else 0.0)
		contact.material_override = charge if latched else mechanism
	contact_motion.clear()

func node_receipt(node: String) -> Dictionary:
	if retained.is_empty():
		return {}
	var physical: Array = []
	for arrival in retained.arrivals:
		if arrival.witness == node or (node == "B" and arrival.witness.begins_with("B_")):
			physical.append(arrival)
	return {"pulse_id": retained.launch.pulse_id, "arrivals": physical,
		"sample": retained.reports[node], "launch_mode": retained.launch.mode, "previous_setup": network.is_previous(retained)}

func update_displays() -> void:
	var result_status := "NO TEST"
	if not retained.is_empty():
		result_status = "PREVIOUS TEST" if network.is_previous(retained) else "LAST TEST"
		result_status += " #%02d\nTESTED  %s / %s" % [retained.launch.pulse_id, retained.launch.mode, retained.launch.tap]
	if running:
		result_status += "\nPULSE IN TRANSIT"
	views["router"].text = "TRANSFER TEST\nBACKBONE  |  %s\n%s" % [
		network.mode, "SERVICE CONFIRMED  #%02d" % retained.launch.pulse_id if service_confirmed else result_status]
	views["tap"].text = "MEASUREMENT TAP\n%s" % ("LIVE PICKUP" if network.tap == "LIVE" else "HOLD PORT")
	for node in ["A", "B", "C"]:
		var receipt := node_receipt(node)
		if receipt.is_empty():
			views[node].text = "NO TEST RECEIPT\n" + ("SAMPLE #00   NO SIGNAL" if node == "B" else "NO SAMPLE")
			continue
		var header := "%s #%02d" % ["PREVIOUS" if receipt.previous_setup else "TEST", receipt.pulse_id]
		var lines: Array[String] = [header]
		match node:
			"A":
				lines.append("LAUNCH   " + arrival_summary(receipt, "A"))
				lines.append(receipt.launch_mode)
			"B":
				lines.append("IN   " + arrival_summary(receipt, "B_IN"))
				lines.append("OUT   " + arrival_summary(receipt, "B_OUT"))
			"C": lines.append("RECEIVER   " + arrival_summary(receipt, "C"))
		lines.append("SAMPLE #%02d   %s" % [receipt.sample.pulse_id, "SIGNAL" if receipt.sample.detected else "NO SIGNAL"])
		views[node].text = "\n".join(lines)

func arrival_summary(receipt: Dictionary, witness: String) -> String:
	var arrivals: Array[String] = []
	for item in receipt.arrivals:
		if item.witness == witness:
			arrivals.append(item.channel if item.kind == "EXPECTED" else "UNEXPECTED " + item.channel)
	return "NO ARRIVAL" if arrivals.is_empty() else " / ".join(arrivals)

func record(kind: String, metadata: Dictionary, target := "") -> void:
	telemetry.record(kind, metadata, null, target if not target.is_empty() else null)

func export_trace(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"events": events}, "\t"))
	return OK

func build_router() -> void:
	var position := Vector3(-3.65, 0, .28)
	pedestal(position, Vector3(1.42, 1.08, .53))
	views["router"] = label(position + Vector3(0, 1.53, .29))
	box(self, position + Vector3(0, 1.49, .15), Vector3(1.42, .72, .15), dark)
	router_lever = box(self, position + Vector3(-.35, 1.04, .32), Vector3(.12, .29, .16), mechanism)
	selector = box(self, position + Vector3(.35, 1.04, .32), Vector3(.28, .075, .13), trim)
	selector.rotation.z = .42
	fixture("TEST_LEVER", "F  Test pulse", position + Vector3(-.35, 1.09, .32), Vector3(.42, .44, .28))
	fixture("ROUTE_SELECTOR", "F  Change service mode", position + Vector3(.35, 1.09, .32), Vector3(.42, .44, .28))

func build_node(id: String, title: String, at: Vector3, witnesses: Array) -> void:
	var position := Vector3(at.x, 0, at.z - .36)
	pedestal(position, Vector3(1.17, 1.55, .38))
	var heading := label(position + Vector3(0, 1.73, .21))
	heading.text = title
	views[id] = label(position + Vector3(0, 1.28, .225))
	box(self, position + Vector3(0, 1.27, .193), Vector3(1.11, .58, .035), dark)
	for index in range(witnesses.size()):
		var offset := 0.0 if witnesses.size() == 1 else (-.21 if index == 0 else .21)
		var dimensions := Vector3(.29, .085, .15) if id == "C" else Vector3(.14, .14, .15)
		contacts[witnesses[index]] = box(self, position + Vector3(offset, .84, .25), dimensions, mechanism)
		if id == "B":
			var contact_label := label(position + Vector3(offset, .70, .34))
			contact_label.text = "IN" if index == 0 else "OUT"
	fixture(id, "F  Inspect " + id, position + Vector3(0, 1.29, .225), Vector3(1.08, .59, .15))

func build_tap() -> void:
	var at := Vector3(.55, 0, -1.65)
	pedestal(at, Vector3(.84, 1.05, .35))
	views["tap"] = label(at + Vector3(0, 1.34, .22))
	for x in [-.21, .21]:
		box(self, at + Vector3(x, .92, .19), Vector3(.22, .21, .08), dark)
	# The handle slides between two actual pickup faces.
	sample_tap = box(self, Vector3(0, .95, .27), Vector3(.16, .14, .13), mechanism)
	var rail := Node3D.new()
	rail.position = at
	add_child(rail)
	sample_tap.reparent(rail, false)
	sample_tap.position.x = -.21
	fixture("MEASUREMENT_TAP", "F  Move sampling connection", at + Vector3(0, .98, .25), Vector3(.78, .33, .22))

func build_conduit(from: Vector3, to: Vector3) -> void:
	var distance := from.distance_to(to)
	var size := Vector3(distance, .055, .09) if absf(to.x - from.x) > absf(to.z - from.z) else Vector3(.09, .055, distance)
	box(self, (from + to) * .5 - Vector3.UP * .055, size, trim)

func build_room() -> void:
	pedestal(Vector3(0, -.2, 0), Vector3(9, .2, 8))
	for x in [-4.5, 4.5]:
		pedestal(Vector3(x, 0, 0), Vector3(.18, 3, 8))
	for z in [-4, 4]:
		pedestal(Vector3(0, 0, z), Vector3(9, 3, .18))
	pedestal(Vector3(2.77, 0, -.55), Vector3(1.35, 2.1, .18))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.83, .90, 1)
	environment.environment.ambient_light_energy = .78
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -22, 0)
	light.light_energy = .75
	add_child(light)

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := Control.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reticle := Label.new()
	reticle.text = "+"
	panel.add_child(reticle)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.offset_left = -8
	reticle.offset_top = -12
	prompt_label = Label.new()
	panel.add_child(prompt_label)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_left = -240
	prompt_label.offset_right = 240
	prompt_label.offset_top = -55
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func bind_inputs() -> void:
	for item in [["move_left", KEY_A], ["move_right", KEY_D], ["move_forward", KEY_W], ["move_back", KEY_S],
		["interact", KEY_F], ["release_mouse", KEY_ESCAPE], ["rotate_left", KEY_R], ["rotate_right", KEY_T]]:
		if not InputMap.has_action(item[0]):
			InputMap.add_action(item[0])
		var input := InputEventKey.new()
		input.physical_keycode = item[1]
		InputMap.action_add_event(item[0], input)
	if not InputMap.has_action("place"):
		InputMap.add_action("place")

func fixture(id: String, prompt_text: String, at: Vector3, dimensions: Vector3) -> void:
	var target := Fixture.new()
	target.name = id
	target.interaction_id = id
	target.bay = self
	target.prompt_text = prompt_text
	target.position = at
	target.bounds = dimensions
	add_child(target)
	fixtures[id] = target

func pedestal(at: Vector3, dimensions: Vector3) -> void:
	var center := at + Vector3.UP * dimensions.y * .5
	box(self, center, dimensions, shell)
	var body := StaticBody3D.new()
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func label(at: Vector3) -> Label3D:
	var readout := Label3D.new()
	readout.position = at
	readout.pixel_size = .002
	readout.font_size = 32
	readout.outline_size = 4
	add_child(readout)
	return readout

func material(color: Color, energy := 0.0) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.emission_enabled = energy > 0
	surface.emission = color
	surface.emission_energy_multiplier = energy
	return surface

func box(parent: Node3D, at: Vector3, dimensions: Vector3, surface: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	part.mesh = shape
	part.material_override = surface
	part.position = at
	parent.add_child(part)
	return part
