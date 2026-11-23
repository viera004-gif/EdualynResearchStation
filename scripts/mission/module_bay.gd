extends Node3D
enum Phase { PRE_MISSION, TERMINAL_ACTIVATED, MISSION_ACTIVE, MODULE_ACQUIRED, PLACEMENT_ATTEMPT, MACHINE_STARTUP, COMPLETE }
var phase: Phase = Phase.PRE_MISSION
var player
var terminal
var module
var wrong_socket
var correct_socket
var machine
var telemetry
var audio: Node3D
var objective: Label
var prompt_label: Label
var system_label: Label
var verified: bool = false
var verifier: RefCounted
var metrics: Node
var frame_count: int = 0
var measured_seconds: float = 0.0
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--verify":
			verified = true
	configure_inputs()
	telemetry = load("res://scripts/telemetry/telemetry.gd").new()
	telemetry.name = "SerializedTelemetry"
	add_child(telemetry)
	audio = load("res://scripts/audio/bay_audio.gd").new()
	audio.name = "StationAudio"
	add_child(audio)
	add_child(load("res://scenes/environment/module_room.tscn").instantiate())
	place_model("workbench", Vector3(-1.7, 0, .15))
	setup_lighting()
	add_static("DeckCollision", Vector3(0, -.1, 0), Vector3(9, .2, 9))
	for x in [-4.46, 4.46]:
		add_static("SideWallCollision", Vector3(x, 1.9, 0), Vector3(.18, 3.8, 9))
	for z in [-4.46, 4.46]:
		add_static("EndWallCollision", Vector3(0, 1.9, z), Vector3(9, 3.8, .18))
	add_static("WorkbenchCollision", Vector3(-1.7, .52, .15), Vector3(1.9, 1.04, .86))
	add_static("TerminalCollision", Vector3(-2.9, .90, -2.35), Vector3(.8, 1.8, .30))
	add_static("MachineCollision", Vector3(1.5, .5, -2.6), Vector3(2.0, 1, 1.1))
	terminal = make_interactable("mission_terminal", "res://scripts/interaction/mission_terminal.gd", "TERMINAL_01", Vector3(-2.9, 0, -2.35))
	machine = make_interactable("repair_machine", "res://scripts/machine/repair_machine.gd", "REPAIR_MACHINE_01", Vector3(1.5, 0, -2.6))
	wrong_socket = make_interactable("socket_wrong", "res://scripts/interaction/module_socket.gd", "SOCKET_WRONG_01", Vector3(.95, 1.05, -1.99))
	correct_socket = make_interactable("socket_correct", "res://scripts/interaction/module_socket.gd", "SOCKET_CORRECT_01", Vector3(2.05, 1.05, -1.99), true)
	module = make_interactable("energy_module", "res://scripts/interaction/energy_module.gd", "ENERGY_MODULE_A", Vector3(-1.7, 1.08, .15))
	player = load("res://scenes/player/player.tscn").instantiate()
	player.bay = self
	player.position = Vector3(0, .04, 3.1)
	add_child(player)
	make_hud()
	telemetry.record("game_started", {"module_bay": "01"})
	if verified:
		metrics = load("res://scripts/verification/build_metrics.gd").new()
		add_child(metrics)
		verifier = load("res://scripts/verification/run_probe.gd").new()
		verifier.run.call_deferred(self)
func configure_inputs() -> void:
	var keys := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"interact": KEY_F, "rotate_left": KEY_R, "rotate_right": KEY_T, "release_mouse": KEY_ESCAPE}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var input := InputEventKey.new()
		input.physical_keycode = keys[action]
		InputMap.action_add_event(action, input)
	if not InputMap.has_action("place"):
		InputMap.add_action("place")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("place", click)
func place_model(asset: String, at: Vector3) -> Node3D:
	var model = load("res://assets/models/" + asset + ".glb").instantiate()
	model.position = at
	add_child(model)
	return model
func make_interactable(asset: String, script_path: String, id: String, at: Vector3, correct: bool = false):
	var node = load(script_path).new()
	node.name = id
	node.interaction_id = id
	node.bay = self
	node.position = at
	if asset.begins_with("socket"):
		node.accepts_module = correct
	node.add_child(load("res://assets/models/" + asset + ".glb").instantiate())
	add_child(node)
	return node
func add_static(id: String, at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = id
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
func setup_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color(.14, .19, .24)
	material.sky_horizon_color = Color(.42, .48, .54)
	material.ground_bottom_color = Color(.035, .045, .055)
	material.ground_horizon_color = Color(.25, .31, .37)
	sky.sky_material = material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.43, .51, .61)
	env.ambient_light_energy = .65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.2
	environment.environment = env
	add_child(environment)
	for z in [-3.1, 0, 3.1]:
		var light := OmniLight3D.new()
		light.position = Vector3(0, 3.3, z)
		light.light_color = Color(.82, .91, 1)
		light.light_energy = 2.2
		light.omni_range = 6.7
		light.omni_attenuation = 1.45
		add_child(light)
	var task := SpotLight3D.new()
	task.position = Vector3(1.5, 3.5, -.4)
	task.light_energy = 3.1
	task.light_color = Color(.8, .91, 1)
	task.spot_range = 6
	task.spot_angle = 57
	task.shadow_enabled = true
	add_child(task)
	task.look_at(Vector3(1.5, 1, -2.6))
	var probe := ReflectionProbe.new()
	probe.position = Vector3(0, 1.8, 0)
	probe.size = Vector3(8.8, 3.7, 8.8)
	probe.interior = true
	probe.box_projection = true
	probe.intensity = .7
	add_child(probe)
func hud_label(text: String, at: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.add_child(hud_label("EDUALYN   /   RESEARCH STATION", Vector2(30, 24), 15, Color(.57, .71, .77)))
	ui.add_child(hud_label("MODULE BAY 01", Vector2(30, 49), 23, Color(.86, .91, .93)))
	objective = hud_label("", Vector2(30, 84), 15, Color(.65, .76, .81))
	ui.add_child(objective)
	prompt_label = hud_label("", Vector2(0, 0), 17, Color(.80, .90, .94))
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-240, -88)
	prompt_label.size = Vector2(480, 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(prompt_label)
	var reticle := hud_label("·", Vector2.ZERO, 25, Color(.8, .9, .95, .8))
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-5, -18)
	ui.add_child(reticle)
	var controls := hud_label("WASD  move     F  interact     R / T  rotate     LMB  couple     ESC  pause", Vector2(30, 680), 13, Color(.46, .58, .64))
	ui.add_child(controls)
	system_label = hud_label("", Vector2(1050, 26), 13, Color(.45, .59, .66))
	ui.add_child(system_label)
func _process(delta: float) -> void:
	frame_count += 1
	if verified and frame_count in [1, 30, 120]:
		print("LIVE_FRAME ", frame_count)
	if frame_count > 90:
		measured_seconds += delta
	if objective == null:
		return
	var objectives := ["Access the mission terminal", "Terminal connected", "Restore the power coupling",
		"Align the keyed module with POWER A", "Coupling interface", "Coupling locked • system starting",
		"System restored • module bay operational"]
	objective.text = objectives[phase]
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		prompt_label.text = "PAUSED  /  click to resume"
		return
	var node = player.target()
	prompt_label.text = node.prompt() if node != null else ("Carry module • approach a socket" if player.held != null else "")
	system_label.text = "MOBILE / %d FPS" % Engine.get_frames_per_second()
func activate_terminal() -> void:
	telemetry.record("terminal_interaction", {}, null, "TERMINAL_01")
	if phase != Phase.PRE_MISSION:
		return
	audio.play_cue("terminal", terminal.global_position + Vector3(0, 1.5, 0))
	phase = Phase.TERMINAL_ACTIVATED
	terminal.screen.text = "MODULE BAY 01\n\nCOUPLING RESTORATION\n\nPOWER A / KEYED INTERFACE"
	phase = Phase.MISSION_ACTIVE
	telemetry.record("mission_started")
func module_acquired() -> void:
	phase = Phase.MODULE_ACQUIRED
	telemetry.record("object_grabbed", {}, "ENERGY_MODULE_A")
	audio.play_cue("pickup", module.global_position)
func placement_attempt(target_id: String) -> void:
	phase = Phase.PLACEMENT_ATTEMPT
	telemetry.record("placement_attempt", {}, "ENERGY_MODULE_A", target_id)
func placement_valid(target_id: String) -> void:
	telemetry.record("placement_valid", {"orientation_step": module.orientation_step}, "ENERGY_MODULE_A", target_id)
	phase = Phase.MACHINE_STARTUP
	machine.startup()
func machine_online() -> void:
	audio.start_hum(machine.global_position + Vector3(0, 1.6, 0))
	telemetry.record("machine_activated", {}, null, "REPAIR_MACHINE_01")
	phase = Phase.COMPLETE
	terminal.screen.text = "MODULE BAY 01\n\nPOWER COUPLING ACTIVE\n\nSYSTEM RESTORED"
	telemetry.record("mission_completed")
	telemetry.finished = true
func tint_indicator(root: Node, marker: String, color: Color) -> Array:
	var materials: Array = []
	if root is MeshInstance3D and marker in str(root.name):
		var material := root.material_override as StandardMaterial3D
		if material == null:
			material = StandardMaterial3D.new()
			material.emission_enabled = true
			material.emission_energy_multiplier = 1.7
			root.material_override = material
		material.albedo_color = color
		material.emission = color
		materials.append(material)
	for child in root.get_children():
		materials.append_array(tint_indicator(child, marker, color))
	return materials
