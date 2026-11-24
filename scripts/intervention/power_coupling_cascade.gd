extends "res://scripts/program/module_bay_mission.gd"
# Mission 01 repair rules and opening experience.
const RECOVERY_SECONDS := 25.0
const EnvironmentScene := preload("res://scripts/intervention/mb01_environment.gd")
const Presentation := preload("res://scripts/intervention/mb01_presentation.gd")
const Hardware := preload("res://scripts/intervention/mb01_hardware.gd")
const CarryBlock := preload("res://scripts/intervention/interactables/mb01_module.gd")
const ENTRY_BLOCK := "SERVICE_MODULE_01"
const KEY_BLOCK := "CONTACT_MODULE_02"
const PRIMARY_BLOCK := "ENERGY_MODULE_A"
var surroundings: Node3D
var presentation: CanvasLayer
var hardware: Node3D
var service_seated := false
var contact_seated := false
var terminal_seen := false
var terminal_status: Tween
var last_placement_rejection: Dictionary = {}
var rejection_streak := 0
var scanner_readings: Dictionary = {}
var intro_complete := false
var entered_bay := false
var exit_ready := false
var taught_rotation := false
var taught_scanner := false
var first_interaction := false
var dock_awake := false
var recovery_started := false
var recovery_time := 0.0
var rejection_pulse: Tween
var delivered_tier := 0
var help_evidence_cursor := 0
var seen_help_evidence: Dictionary = {}

var cooling_ready := false
var relay_ready := false
var cooling
var relay
func setup_mission() -> void:
	cooling = device("cooling_regulator", "cooling", "COOLING_C01", Vector3(-1.35, 0, -3.9))
	relay = device("auxiliary_relay", "relay", "RELAY_R02", Vector3(0, 0, -3.9))
	setup_tools()
	scanner.resolve_scan_readout = scan_readout
	routes = load("res://assets/models/intervention_v02/power_routes.glb").instantiate()
	add_child(routes)
func mission_context() -> Dictionary:
	return {"cooling_ready": cooling_ready, "relay_ready": relay_ready,
		"service_module_seated": service_seated, "contact_module_seated": contact_seated}
func upstream_ready() -> bool:
	return cooling_ready and relay_ready and service_seated and contact_seated
func early_help_condition() -> bool:
	return not cooling_ready
func guidance_level(_requested: int, _early: bool) -> int:
	var new_evidence := false
	for index in range(help_evidence_cursor, telemetry.archive.size()):
		var event: Dictionary = telemetry.archive[index]
		var metadata: Dictionary = event.metadata
		var evidence := ""
		match event.event_type:
			"subsystem_inspected", "scanner_scan_completed":
				if not metadata.get("unchanged", false) and metadata.diagnostic != "diagnostic.available":
					evidence = str(["reading", event.target_id, metadata.diagnostic])
			"placement_invalid", "relay_rejected":
				evidence = str([event.event_type, event.target_id, metadata.action_signature, metadata.reason])
			"cooling_ready", "relay_activated", "placement_valid":
				evidence = str([event.event_type, event.object_id])
		if not evidence.is_empty() and not seen_help_evidence.has(evidence):
			seen_help_evidence[evidence] = true
			new_evidence = true
	help_evidence_cursor = telemetry.archive.size()
	if delivered_tier == 0 or new_evidence:
		delivered_tier = mini(delivered_tier + 1, 3)
	return delivered_tier
func select_guidance(level: int, early: bool) -> String:
	var key := "help.level1.power_coupling.early" if early else "help.level1.power_coupling"
	var dependency := "cooling" if not cooling_ready else ("relay" if not relay_ready else "coupler")
	if level in [2, 3]:
		key = "help.level%d.power_coupling.%s" % [level, dependency]
		if dependency == "coupler" and not upstream_ready():
			key = "mb01.help.contacts"
	return "help.power_coupling.complete" if phase == Phase.COMPLETE else key

func _ready() -> void:
	super._ready()
	if language_selector.opened:
		language_selector.close()
	taught_rotation = program.has_meta("mb01_rotation_shown")
	taught_scanner = program.has_meta("mb01_scanner_shown")
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player.position = EnvironmentScene.SPAWN
	surroundings = EnvironmentScene.new()
	add_child(surroundings)
	surroundings.build(self)
	presentation = Presentation.new()
	add_child(presentation)
	presentation.build(self)
	hardware = Hardware.new()
	add_child(hardware)
	hardware.build(self)
	add_alignment_audio()
	stage_entry_view()
	telemetry.record("game_intro_started")
	await presentation.boot_sequence()
	intro_complete = true
	player.set_process_unhandled_input(true)
	player.set_physics_process(true)
	telemetry.record("game_intro_completed")
	if not program.has_meta("mb01_controls_shown"):
		program.set_meta("mb01_controls_shown", true)
		teach_control("mb01.controls", 5.0)
	await get_tree().create_timer(1.1).timeout
	if not entered_bay:
		presentation.speak("mb01.radio.station", 8.5)

func stage_entry_view() -> void:
	module.position = Vector3(-1.17, 1.08, .32)
	tint_indicator(module, "OrientationStripe", Color(.30, .67, .83))
	for marker in ["DiagnosticOptic", "AIRequestButton"]:
		tint_indicator(ai_station, marker, Color(.085, .18, .21))
	ai_station.show_message("mb01.support.idle")
	ai_station.screen.modulate = Color(.37, .52, .56)
	beacon.light_energy = .03
	for console in [terminal, operations_console]:
		console.screen.modulate = Color(.30, .46, .51)
		for marker in ["TerminalStatus", "ConfirmButton"]:
			tint_indicator(console, marker, Color(.07, .17, .20))
	var dock: Node = find_child("DockIndicator", true, false)
	if dock != null:
		tint_indicator(dock.get_parent(), "DockIndicator", Color(.06, .13, .16))

func add_alignment_audio() -> void:
	if audio.disabled_for_profile:
		return
	var voice := AudioStreamPlayer3D.new()
	voice.stream = preload("res://assets/audio/lock.wav")
	voice.bus = "StationSFX"
	voice.pitch_scale = .66
	voice.volume_db = -5.0
	voice.max_distance = 9.0
	audio.add_child(voice)
	audio.voices["alignment_refusal"] = voice
	audio.cue_counts["alignment_refusal"] = 0

func add_static(id: String, at: Vector3, dimensions: Vector3) -> void:
	if id != "EndWallCollision" or at.z < 0:
		super.add_static(id, at, dimensions)

func machine_script() -> String:
	return "res://scripts/intervention/interactables/mb01_machine.gd"

func socket_script() -> String:
	return "res://scripts/intervention/interactables/mb01_socket.gd"

func make_interactable(asset: String, script_path: String, id: String, at: Vector3, correct: bool = false):
	if id == "MODULE_BAY_OPERATIONS":
		script_path = "res://scripts/intervention/interactables/mb01_operations_console.gd"
	elif id == PRIMARY_BLOCK:
		script_path = "res://scripts/intervention/interactables/mb01_module.gd"
	return super.make_interactable(asset, script_path, id, at, correct)

func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_label = localized_hud("", Vector2.ZERO, 17, Color(.78, .88, .94))
	ui.add_child(prompt_label)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_left = -480
	prompt_label.offset_right = 480
	prompt_label.offset_top = -62
	prompt_label.offset_bottom = -32
	prompt_label.add_theme_constant_override("outline_size", 7)
	var reticle := hud_label("·", Vector2.ZERO, 25, Color(.79, .89, .94, .75))
	ui.add_child(reticle)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.offset_left = -15
	reticle.offset_right = 15
	reticle.offset_top = -17
	reticle.offset_bottom = 17

func _process(delta: float) -> void:
	frame_count += 1
	if frame_count > 90:
		measured_seconds += delta
	if not intro_complete:
		return
	if not entered_bay and player.position.z < EnvironmentScene.DOOR_Z + 2.35:
		surroundings.open_airlock()
	if not entered_bay and player.position.z < EnvironmentScene.THRESHOLD:
		entered_bay = true
		telemetry.record("module_bay_entered")
		presentation.assign()
		telemetry.record("mission_objective_shown")
	var key := ""
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		key = "mb01.pause" if not language_selector.opened else ""
	else:
		var target = player.target()
		if target != null:
			key = target.prompt()
			if target == terminal and terminal_status != null and terminal_status.is_running():
				key = ""
		if player.held == scanner:
			if target != null and target.has_method("scan_status"):
				key = "mb01.interaction.scan"
			elif key.is_empty():
				key = "mb01.interaction.release"
		elif player.held is CarryBlock and key.is_empty():
			key = "mb01.interaction.release"
	localization.bind_label(prompt_label, key)
	if recovery_started and not taught_scanner and history.running and phase != Phase.MACHINE_STARTUP:
		var to_dock: Vector3 = Vector3(scanner.home.x, 0, scanner.home.z) - player.position
		var approaching: bool = to_dock.normalized().dot(player.velocity) > .60
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and to_dock.length() > 2.5 and not approaching:
			recovery_time += delta
		if not dock_awake and recovery_time >= RECOVERY_SECONDS and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			dock_awake = true
			surroundings.wake_scanner_dock()
			telemetry.record("scanner_dock_woke", {"reason": "post_rejection_without_progress"})

func teach_control(key: String, seconds: float) -> void:
	presentation.teach(key, seconds)
	telemetry.record("control_prompt_shown", {"prompt_key": key})

func begin_action(family: String, object_id: String, target_id: String, orientation: int = -1, subsystem: String = "", tool: String = "") -> void:
	super.begin_action(family, object_id, target_id, orientation, subsystem, tool)
	record_first_interaction(family, object_id, target_id)
	if family != "placement":
		recovery_time = 0.0
	if family == "pickup" and object_id == "DIAGNOSTIC_SCANNER" and not taught_scanner:
		taught_scanner = true
		program.set_meta("mb01_scanner_shown", true)
		show_scanner_intro.call_deferred()

func show_scanner_intro() -> void:
	surroundings.settle_scanner_dock()
	presentation.teach("mb01.scanner.intro", 6.5)
	telemetry.record("scanner_tutorial_shown")

func request_help() -> void:
	ai_station.screen.modulate = Color(.48, .8, .9)
	super.request_help()

func record_first_interaction(family: String, object_id, target_id: String) -> void:
	if first_interaction:
		return
	first_interaction = true
	telemetry.record("first_object_interaction", {"action_family": family}, object_id, target_id)

func activate_terminal() -> void:
	super.activate_terminal()
	record_first_interaction("terminal", null, "TERMINAL_01")
	recovery_time = 0.0
	if terminal_seen:
		localization.bind_label(terminal.screen, "mb01.terminal.no_data")
		if terminal_status == null or not terminal_status.is_running():
			terminal_status = create_tween()
			terminal_status.tween_interval(2.1)
			terminal_status.tween_callback(terminal.refresh)
	terminal_seen = true

func scan_readout(target_id: String, diagnostic: String) -> Dictionary:
	var unchanged: bool = scanner_readings.get(target_id) == diagnostic
	scanner_readings[target_id] = diagnostic
	return {"readout": "mb01.scanner.unchanged" if unchanged else diagnostic, "unchanged": unchanged}

func placement_rejection_context(block: Node, socket_id: String, reason: String) -> Dictionary:
	var current := {"block_id": block.interaction_id, "socket_id": socket_id,
		"orientation": block.orientation_step, "cause": reason, "state": mission_context()}
	var previous := last_placement_rejection
	var comparable := not previous.is_empty()
	var repeated := comparable and current == previous
	rejection_streak = rejection_streak + 1 if repeated and rejection_streak > 0 else 1
	last_placement_rejection = current
	return {"reason": reason, "previous_rejection_cause": previous.get("cause", ""),
		"previous_rejection_block_id": previous.get("block_id", ""),
		"orientation_changed": comparable and current.block_id == previous.block_id and current.orientation != previous.orientation,
		"socket_changed": comparable and current.socket_id != previous.socket_id,
		"system_state_changed": comparable and current.state != previous.state,
		"same_cause_streak": rejection_streak, "fault_emphasis": rejection_streak >= 2}

func teach_rotation() -> void:
	if not taught_rotation:
		taught_rotation = true
		program.set_meta("mb01_rotation_shown", true)
		teach_control("mb01.rotate", 5.0)

func block_event(kind: String, block: Node, socket_id := "", details: Dictionary = {}) -> String:
	var metadata := {"block_id": block.interaction_id, "socket_id": socket_id,
		"orientation": block.orientation_step}
	metadata.merge(details, true)
	telemetry.record(kind, metadata, block.interaction_id, socket_id if not socket_id.is_empty() else null)
	return str(telemetry.archive.back().event_uuid)

func block_seated(block_id: String) -> void:
	rejection_streak = 0
	history.progress()
	recovery_time = 0.0
	match block_id:
		ENTRY_BLOCK:
			service_seated = true
			hardware.entry_engaged()
		KEY_BLOCK:
			contact_seated = true
			hardware.carrier_engaged()
		PRIMARY_BLOCK:
			progress("MODULE_LOCKED")
			phase = Phase.MACHINE_STARTUP
			machine.startup()

func register_failure() -> void:
	super.register_failure()
	if not recovery_started:
		recovery_started = true
		recovery_time = 0.0

func progress(value: String) -> void:
	super.progress(value)
	recovery_time = 0.0
	match value:
		"COOLING_READY": hardware.cooling_engaged()
		"RELAY_READY": hardware.relay_engaged()

func pulse_route(marker: String, color: Color, duration: float) -> void:
	if marker == "RelayRoute" and rejection_pulse != null:
		rejection_pulse.kill()
	if marker != "RelayRoute" or color.r < color.b:
		var flow := create_tween().set_parallel()
		for surface in tint_indicator(routes, marker + "Flow", color):
			surface.emission_energy_multiplier = .10
			flow.tween_property(surface, "emission_energy_multiplier", 1.7, duration)
		return
	rejection_pulse = create_tween().set_parallel()
	var resting := Color(.025, .038, .045)
	for surface in tint_indicator(routes, marker + "Flow", color):
		surface.emission_energy_multiplier = 1.7
		rejection_pulse.tween_property(surface, "emission", resting, duration)
		rejection_pulse.tween_property(surface, "albedo_color", resting, duration)
func energize_routes() -> void:
	tint_indicator(machine, "MachineIndicator", Color(.12, .66, .91))
	hardware.sector_drive_engaged()
	var tween := create_tween()
	for marker in ["CouplerRouteFlow", "CoreRouteFlow"]:
		var mesh := routes.find_child(marker, true, false) as MeshInstance3D
		var surface := mesh.get_active_material(0).duplicate() as StandardMaterial3D
		mesh.material_override = surface
		surface.emission_enabled = true
		surface.emission = Color(.13, .68, .96)
		surface.emission_energy_multiplier = 0.0
		tween.tween_property(surface, "emission_energy_multiplier", 2.2, .30)

func machine_online() -> void:
	tint_indicator(machine, "CoreIndicator", Color(.12, .66, .91))
	surroundings.restore_room()
	super.machine_online()
	await presentation.speak("mb01.radio.complete", 5.5).finished
	exit_ready = true
	operations_console.refresh()
