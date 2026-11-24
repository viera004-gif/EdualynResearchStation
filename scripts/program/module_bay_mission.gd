extends "res://scripts/mission/module_bay.gd"
# Intervention orchestration only. No assessment, trait inference or scoring.
var localization: Node
var language_selector: CanvasLayer
var title_label: Label
var tutorial_label: Label
var definition: RefCounted
var program: Node
var operations_console
var config: Dictionary
var history: Node
var stage := "SYSTEM_OFFLINE"
var stage_history: Array[String] = ["SYSTEM_OFFLINE"]
var last_placement_target := ""
var scanner
var ai_station
var routes: Node3D
var help_salient := false
var help_opened := false
var beacon: OmniLight3D
var help_busy := false
func definition_path() -> String:
	return "res://config/missions/mb01.json"
func socket_script() -> String:
	return "res://scripts/intervention/interactables/cascade_socket.gd"
func machine_script() -> String:
	return "res://scripts/intervention/interactables/cascade_machine.gd"
func _ready() -> void:
	definition = load("res://scripts/program/mission_definition.gd").new()
	definition.read(definition_path())
	program = get_node_or_null("/root/ModuleBayProgram")
	if program == null:
		program = load("res://scripts/program/module_bay_program.gd").new()
		program.name = "ModuleBayProgram"
		program.configure()
		add_child(program)
		program.reparent.call_deferred(get_tree().root)
	if not program.available(definition.data.slot):
		get_tree().change_scene_to_file.call_deferred("res://scenes/main/power_coupling_cascade.tscn")
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--verify":
			verified = true
	localization = load("res://scripts/localization/station_localization.gd").new()
	add_child(localization)
	if not program.locale.is_empty():
		localization.set_locale(program.locale)
	program.locale = localization.locale
	localization.locale_changed.connect(func(code: String): program.locale = code)
	config = definition.help_policy()
	history = load("res://scripts/intervention/action_history.gd").new()
	history.configure(config.adaptive_help)
	add_child(history)
	configure_inputs()
	telemetry = load("res://scripts/intervention/cascade_telemetry.gd").new()
	telemetry.content_id = definition.data.mission_id
	telemetry.app_version = definition.data.app_version
	telemetry.game_version = definition.data.version
	telemetry.name = "SerializedTelemetry"
	telemetry.context_provider = context
	add_child(telemetry)
	audio = load("res://scripts/intervention/cascade_audio.gd").new()
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
	terminal = make_interactable("mission_terminal", "res://scripts/intervention/interactables/cascade_terminal.gd", "TERMINAL_01", Vector3(-2.9, 0, -2.35))
	machine = make_interactable("repair_machine", machine_script(), "REPAIR_MACHINE_01", Vector3(1.5, 0, -2.6))
	wrong_socket = make_interactable("socket_wrong", socket_script(), "SOCKET_WRONG_01", Vector3(.95, 1.05, -1.99))
	correct_socket = make_interactable("socket_correct", socket_script(), "SOCKET_CORRECT_01", Vector3(2.05, 1.05, -1.99), true)
	module = make_interactable("energy_module", "res://scripts/intervention/interactables/cascade_module.gd", "ENERGY_MODULE_A", Vector3(-1.7, 1.08, .15))
	setup_mission()
	player = load("res://scenes/intervention/cascade_player.tscn").instantiate()
	player.bay = self
	player.position = Vector3(0, .04, 3.1)
	add_child(player)
	make_hud()
	operations_console = make_interactable("mission_terminal", "res://scripts/program/operations_console.gd", "MODULE_BAY_OPERATIONS", Vector3(-3.5, 0, -.4))
	add_static("OperationsCollision", Vector3(-3.5, .9, -.4), Vector3(.8, 1.8, .3))
	setup_localized_engravings()
	language_selector = load("res://scripts/localization/language_selector.gd").new()
	language_selector.localization = localization
	add_child(language_selector)
	if not "--skip-language-selector" in OS.get_cmdline_user_args():
		language_selector.open()
	telemetry.record("game_started", {"module_bay": "01"})
	if "--verify" in OS.get_cmdline_user_args():
		metrics = load("res://scripts/verification/build_metrics.gd").new()
		add_child(metrics)
	start_verifier()
func start_verifier() -> void:
	if "--verify-resources" in OS.get_cmdline_user_args() and definition.data.slot == "MB01":
		verifier = load("res://verification/phase2c/resource_probe.gd").new()
		verifier.run.call_deferred(self)
	elif "--verify-profile" in OS.get_cmdline_user_args():
		verifier = load("res://verification/phase2b/profile_probe.gd").new()
		verifier.run.call_deferred(self)
	elif "--verify-progression" in OS.get_cmdline_user_args() and definition.data.slot == "MB01":
		verifier = load("res://verification/phase2b/progression_probe.gd").new()
		verifier.run.call_deferred(self)
	elif "--verify-v02" in OS.get_cmdline_user_args():
		verified = true
		verifier = load("res://verification/v02/cascade_probe.gd").new()
		verifier.run.call_deferred(self)
	elif "--verify-localization" in OS.get_cmdline_user_args():
		verifier = load("res://verification/localization/localization_probe.gd").new()
		verifier.run.call_deferred(self)
	elif "--verify-free-v02" in OS.get_cmdline_user_args():
		verifier = load("res://verification/v02/free_interaction_probe.gd").new()
		verifier.run.call_deferred(self)


func configure_inputs() -> void:
	super.configure_inputs()
	for action in {"inspect": KEY_E, "put_down": KEY_Q, "language": KEY_L}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = {"inspect": KEY_E, "put_down": KEY_Q, "language": KEY_L}[action]
		InputMap.action_add_event(action, key)
func device(asset: String, kind: String, id: String, at: Vector3):
	var node = load("res://scripts/intervention/interactables/cascade_device.gd").new()
	node.kind = kind
	node.bay = self
	node.interaction_id = id
	node.name = id
	node.position = at
	node.add_child(load("res://assets/models/intervention_v02/" + asset + ".glb").instantiate())
	add_child(node)
	return node
func setup_mission() -> void:
	pass
func setup_tools() -> void:
	ai_station = device("diagnostic_ai_station", "ai", "DIAGNOSTIC_AI", Vector3(3.25, 0, .65))
	add_static("AIStationCollision", Vector3(3.25, .9, .65), Vector3(.95, 1.8, .45))
	var dock = load("res://assets/models/intervention_v02/scanner_dock.glb").instantiate()
	dock.position = Vector3(-3.2, 0, 1.5)
	add_child(dock)
	add_static("ScannerDockCollision", Vector3(-3.2, .55, 1.5), Vector3(.65, 1.1, .54))
	scanner = device("diagnostic_scanner", "scanner", "DIAGNOSTIC_SCANNER", Vector3(-3.2, 1.12, 1.5))
	beacon = OmniLight3D.new()
	beacon.position = Vector3(0, 1.95, .35)
	beacon.light_color = Color(.15, .6, .8)
	beacon.omni_range = 1.3
	beacon.light_energy = .12
	ai_station.add_child(beacon)

func localized_hud(key: String, at: Vector2, size: int, color: Color) -> Label:
	var label := hud_label("", at, size, color)
	localization.bind_label(label, key)
	return label
func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.add_child(localized_hud("station.identity", Vector2(30, 24), 15, Color(.57, .71, .77)))
	title_label = localized_hud(definition.data.title_key, Vector2(30, 49), 23, Color(.86, .91, .93))
	ui.add_child(title_label)
	objective = localized_hud(definition.data.objective_key, Vector2(30, 84), 15, Color(.65, .76, .81))
	ui.add_child(objective)
	prompt_label = localized_hud("", Vector2(0, 0), 17, Color(.8, .9, .94))
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-500, -88)
	prompt_label.size = Vector2(1000, 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(prompt_label)
	tutorial_label = localized_hud("tutorial.explore" if definition.data.tutorial_level == "introductory" else "", Vector2(30, 115), 14, Color(.65, .76, .81))
	ui.add_child(tutorial_label)
	var reticle := hud_label("·", Vector2.ZERO, 25, Color(.8, .9, .95, .8))
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-5, -18)
	ui.add_child(reticle)
	ui.add_child(localized_hud("ui.controls" if definition.data.get("show_controls_footer", true) else "language.shortcut", Vector2(30, 680), 13, Color(.46, .58, .64)))
	system_label = localized_hud("ui.performance", Vector2(1050, 26), 13, Color(.45, .59, .66))
	ui.add_child(system_label)
func _process(delta: float) -> void:
	frame_count += 1
	if frame_count > 90:
		measured_seconds += delta
	if objective == null:
		return
	localization.bind_label(objective, definition.data.completion_key if phase == Phase.COMPLETE else definition.data.objective_key)
	var tutorial: String = "tutorial.explore" if definition.data.tutorial_level == "introductory" else ""
	if player.held != null and definition.data.tutorial_level == "introductory":
		tutorial = "tutorial.scan" if player.held.has_method("scan") else "tutorial.pickup"
		if player.held == module and player.target() in [correct_socket, wrong_socket]:
			tutorial = "tutorial.rotate"
	localization.bind_label(tutorial_label, "" if phase == Phase.COMPLETE else tutorial)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		localization.bind_label(prompt_label, "ui.paused")
	else:
		var target = player.target()
		localization.bind_label(prompt_label, target.prompt() if target != null else "")
	localization.bind_label(system_label, "ui.performance", {"fps": int(Engine.get_frames_per_second())})
	if definition.data.get("automatic_help_salience", true) and history != null and history.running and (history.repetition_nudge_due() or history.no_progress_due()):
		if not help_salient:
			help_salient = true
			telemetry.record("help_salience_changed", {"reason": "exact_repeat" if history.repetition_nudge_due() else "no_progress"})
			ai_station.show_message("support.available")
	if beacon != null:
		beacon.light_energy = .45 + .15 * sin(Time.get_ticks_msec() / 650.0) if help_salient else .12
func setup_localized_engravings() -> void:
	# Replace text meshes only in this live scene; frozen GLB files remain intact.
	var markings := {
		"StationIdentity": ["station.identity", .15], "ModuleBayTitle": ["world.module_bay", .27],
		"SafetyLabel": ["world.safety", .065], "BenchID": ["world.assembly", .055],
		"TerminalChassisMark": ["world.control", .045], "RepairUnitID": ["world.coupling", .07],
		"ValveIdentity": ["world.cooling", .055], "ValveGaugeLabel": ["world.flow", .038],
		"RelayIdentity": ["world.relay", .052], "DockIdentity": ["world.scanner_dock", .04],
		"AIIdentity": ["world.support", .055]}
	for marker in markings:
		for mesh in find_children(marker, "MeshInstance3D", true, false):
			var label := Label3D.new()
			label.font_size = 36
			label.outline_size = 0
			label.pixel_size = float(markings[marker][1]) / 36.0
			label.modulate = Color(.65, .72, .75)
			add_child(label)
			label.global_position = mesh.to_global(mesh.get_aabb().get_center()) + Vector3(0, 0, .004)
			mesh.hide()
			localization.bind_label(label, markings[marker][0])
func context() -> Dictionary:
	var value := {"content_version": definition.data.version, "session_purpose": "intervention",
		"program_slot": definition.data.slot, "tutorial_level": definition.data.tutorial_level,
		"scaffolding_level": definition.data.scaffolding_level,
		"policy_version": config.get("policy_version", ""), "locale": localization.locale, "mission_state": stage,
		"orientation": module.orientation_step if is_instance_valid(module) else -1,
		"action_signature": history.last_signature.duplicate(true), "action_change": history.last_change_candidate,
		"preceding_invalid_attempts": history.invalid_attempts, "exact_repeats": history.exact_repeats,
		"preceding_failure_uuid": history.last_failure_uuid}
	value.merge(mission_context())
	return value
func mission_context() -> Dictionary:
	return {}

func begin_action(family: String, object_id: String, target_id: String, orientation: int = -1, subsystem: String = "", tool: String = "") -> void:
	# Free exploration can begin at any physical device, including before terminal use.
	if phase == Phase.PRE_MISSION:
		phase = Phase.MISSION_ACTIVE
		history.start()
		set_stage(definition.data.initial_state)
		telemetry.record("mission_started", {"trigger": "physical_interaction"})
		terminal.refresh()
	history.observe(history.signature(family, object_id, target_id, orientation, subsystem, tool))
	if family in ["inspect", "scan", "regulator", "relay", "rotation", "relay_rotation"]:
		history.exploration_actions += 1
func set_stage(value: String) -> void:
	stage = value
	stage_history.append(value)
	telemetry.record("system_state_changed", {"state": value})
func progress(value: String) -> void:
	history.progress()
	help_salient = false
	set_stage(value)
func activate_terminal() -> void:
	telemetry.record("terminal_interaction", {}, null, "TERMINAL_01")
	if phase != Phase.PRE_MISSION:
		return
	audio.play_cue("terminal", terminal.global_position + Vector3(0, 1.5, 0))
	phase = Phase.MISSION_ACTIVE
	telemetry.record("mission_started")
	history.start()
	set_stage(definition.data.initial_state)
	terminal.refresh()
func placement_attempt(target_id: String) -> void:
	last_placement_target = target_id
	begin_action("placement", "ENERGY_MODULE_A", target_id, module.orientation_step, "POWER_COUPLER")
	super.placement_attempt(target_id)
func register_failure() -> void:
	var event: Dictionary = telemetry.archive.back()
	history.invalid(history.last_signature, event.event_uuid)
	telemetry.record("invalid_action_observed", {"invalid_event_uuid": event.event_uuid})
func upstream_ready() -> bool:
	return false
func placement_valid(target_id: String) -> void:
	progress("MODULE_LOCKED")
	super.placement_valid(target_id)
func machine_online() -> void:
	progress("SYSTEM_ACTIVE")
	history.running = false
	audio.start_hum(machine.global_position + Vector3(0, 1.6, 0))
	telemetry.record("machine_activated", {}, null, "REPAIR_MACHINE_01")
	phase = Phase.COMPLETE
	terminal.refresh()
	telemetry.record("mission_completed")
	telemetry.finished = true
	program.complete(definition.data.slot)
func inspect_subsystem(node: Node) -> void:
	begin_action("inspect", "PLAYER", node.interaction_id, -1, node.interaction_id)
	telemetry.record("subsystem_inspected", {"diagnostic": node.scan_status()}, null, node.interaction_id)
	if node.get("screen") != null:
		node.show_message(node.scan_status())
func pulse_route(marker: String, color: Color, _duration: float) -> void:
	tint_indicator(routes, marker + "Flow", color)
func request_help() -> void:
	if help_busy:
		return
	help_busy = true
	begin_action("help", "PLAYER", "DIAGNOSTIC_AI", -1, "DIAGNOSTICS")
	if not help_opened:
		help_opened = true
		telemetry.record("help_station_opened", {}, null, "DIAGNOSTIC_AI")
		audio.play_cue("station_wake", ai_station.global_position)
	var level: int = history.level_for_next_request()
	var early: bool = history.exploration_actions < int(definition.data.early_help_exploration_count) and early_help_condition()
	level = guidance_level(level, early)
	history.help_requests += 1
	telemetry.record("help_requested", {"requested_level": level, "early_little_exploration": early}, null, "DIAGNOSTIC_AI")
	var guidance_key: String = select_guidance(level, early)
	ai_station.show_message("support.response", {"level": level, "guidance": {"key": guidance_key}})
	telemetry.record("help_delivered", {"help_level": level, "guidance_key": guidance_key, "early_little_exploration": early}, null, "DIAGNOSTIC_AI")
	audio.play_cue("trace", ai_station.global_position)
	await get_tree().create_timer(.6).timeout
	help_busy = false

func select_guidance(_level: int, _early: bool) -> String:
	return ""
func guidance_level(requested: int, early: bool) -> int:
	return 1 if early else requested
func early_help_condition() -> bool:
	return not upstream_ready()
