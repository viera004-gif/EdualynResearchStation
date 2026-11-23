extends "res://scripts/program/module_bay_mission.gd"
# Mission 01 repair rules and opening experience.
const RECOVERY_SECONDS := 25.0
const FREE_EXPLORE_SECONDS := 40.0
const EnvironmentScene := preload("res://scripts/intervention/mb01_environment.gd")
const Presentation := preload("res://scripts/intervention/mb01_presentation.gd")
var surroundings: Node3D
var presentation: CanvasLayer
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

var cooling_ready := false
var relay_ready := false
var cooling
var relay
func setup_mission() -> void:
	cooling = device("cooling_regulator", "cooling", "COOLING_C01", Vector3(-1.35, 0, -3.9))
	relay = device("auxiliary_relay", "relay", "RELAY_R02", Vector3(0, 0, -3.9))
	setup_tools()
	routes = load("res://assets/models/intervention_v02/power_routes.glb").instantiate()
	add_child(routes)
func mission_context() -> Dictionary:
	return {"cooling_ready": cooling_ready, "relay_ready": relay_ready}
func upstream_ready() -> bool:
	return cooling_ready and relay_ready
func early_help_condition() -> bool:
	return not cooling_ready
func select_guidance(level: int, early: bool) -> String:
	var key := "help.level1.power_coupling.early" if early else "help.level1.power_coupling"
	var dependency := "cooling" if not cooling_ready else ("relay" if not relay_ready else "coupler")
	if level in [2, 3]:
		key = "help.level%d.power_coupling.%s" % [level, dependency]
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
	telemetry.record("game_intro_started")
	await presentation.boot_sequence()
	intro_complete = true
	player.set_process_unhandled_input(true)
	player.set_physics_process(true)
	telemetry.record("game_intro_completed")
	if not program.has_meta("mb01_controls_shown"):
		program.set_meta("mb01_controls_shown", true)
		teach_control("mb01.controls", 7.0)
	await get_tree().create_timer(1.1).timeout
	if not entered_bay:
		presentation.speak("mb01.radio.station", 8.5)

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
	prompt_label.position = Vector2(-480, -62)
	prompt_label.size = Vector2(960, 30)
	prompt_label.add_theme_constant_override("outline_size", 7)
	var reticle := hud_label("·", Vector2.ZERO, 25, Color(.79, .89, .94, .75))
	ui.add_child(reticle)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-4, -17)

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
		if player.held == scanner:
			if target != null and target.has_method("scan_status"):
				key = "mb01.interaction.scan"
			elif key.is_empty():
				key = "mb01.interaction.release"
		elif player.held == module and key.is_empty():
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
			telemetry.record("scanner_dock_woke", {"reason": "no_recent_interaction"})

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

func record_first_interaction(family: String, object_id, target_id: String) -> void:
	if first_interaction:
		return
	first_interaction = true
	telemetry.record("first_object_interaction", {"action_family": family}, object_id, target_id)

func activate_terminal() -> void:
	super.activate_terminal()
	record_first_interaction("terminal", null, "TERMINAL_01")
	recovery_time = 0.0

func module_acquired() -> void:
	super.module_acquired()
	if not taught_rotation:
		taught_rotation = true
		program.set_meta("mb01_rotation_shown", true)
		teach_control("mb01.rotate", 5.0)

func register_failure() -> void:
	super.register_failure()
	if not recovery_started:
		recovery_started = true
		recovery_time = 0.0

func progress(value: String) -> void:
	super.progress(value)
	recovery_time = 0.0

func pulse_route(marker: String, color: Color, duration: float) -> void:
	if marker == "RelayRoute" and rejection_pulse != null:
		rejection_pulse.kill()
	if marker != "RelayRoute" or color.r < color.b:
		for surface in tint_indicator(routes, marker + "Flow", color):
			surface.emission_energy_multiplier = 1.7
		return
	rejection_pulse = create_tween().set_parallel()
	var resting := Color(.025, .038, .045)
	for surface in tint_indicator(routes, marker + "Flow", color):
		surface.emission_energy_multiplier = 1.7
		rejection_pulse.tween_property(surface, "emission", resting, duration)
		rejection_pulse.tween_property(surface, "albedo_color", resting, duration)
func energize_routes() -> void:
	tint_indicator(machine, "MachineIndicator", Color(.12, .66, .91))
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
	presentation.speak("mb01.radio.complete", 8.0)
	await get_tree().create_timer(FREE_EXPLORE_SECONDS).timeout
	exit_ready = true
	operations_console.refresh()
