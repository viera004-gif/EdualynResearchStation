extends "res://scripts/interaction/interactable.gd"
var kind := ""
var screen: Label3D
var moving_part: Node3D
var moving := false
var carried := false
var scanning := false
var home := Vector3.ZERO
func _ready() -> void:
	bounds = Vector3(.78, 1.2, .65) if kind != "scanner" else Vector3(.38, .36, .48)
	bounds_offset = Vector3(0, 1.35, .25) if kind != "scanner" else Vector3(0, .18, 0)
	super._ready()
	home = position
	screen = Label3D.new()
	screen.position = Vector3(0, 1.54, .215) if kind == "ai" else (Vector3(0, .22, .22) if kind == "scanner" else Vector3(0, 2.04, .16))
	screen.font_size = 28
	screen.pixel_size = .00078 if kind == "scanner" else .00125
	screen.modulate = Color(.48, .8, .9)
	add_child(screen)
	if kind == "cooling":
		moving_part = find_child("ValveWheel", true, false)
	elif kind == "relay":
		moving_part = find_child("RelayLever", true, false)
	refresh()
func show_message(key: String, values: Dictionary = {}) -> void:
	bay.localization.bind_label(screen, key, values)
func refresh() -> void:
	if kind == "ai":
		show_message("support.idle")
	elif kind == "scanner":
		show_message("scanner.idle")
	else:
		show_message(scan_status())
func prompt() -> String:
	match kind:
		"cooling": return "interaction.cooling"
		"relay": return "interaction.relay"
		"ai": return "interaction.support"
		"scanner": return "interaction.pick_up_scanner" if bay.player.held == null else "interaction.hands_full"
	return ""
func scan_status() -> String:
	match kind:
		"cooling": return "diagnostic.flow_stable" if bay.cooling_ready else "diagnostic.flow_interrupted"
		"relay": return "diagnostic.relay_energized" if bay.relay_ready else ("diagnostic.contact_open" if bay.cooling_ready else "diagnostic.input_unstable")
	return "diagnostic.available"
func interact(player: Node) -> void:
	if kind == "ai":
		bay.request_help()
	elif kind == "scanner":
		if player.held != null or carried:
			return
		bay.begin_action("pickup", interaction_id, "SCANNER_DOCK", -1, "DIAGNOSTICS", "DIAGNOSTIC_SCANNER")
		carried = true
		collision_layer = 0
		reparent(player.carry_anchor)
		position = Vector3(0, -.06, 0)
		rotation = Vector3.ZERO
		player.held = self
		bay.telemetry.record("scanner_picked_up", {}, interaction_id, "SCANNER_DOCK")
		bay.audio.play_cue("pickup", global_position)
	elif kind == "cooling":
		if moving or bay.cooling_ready or bay.machine.state != bay.machine.State.OFFLINE:
			return
		bay.begin_action("regulator", interaction_id, interaction_id, -1, "COOLING")
		bay.telemetry.record("cooling_regulator_interaction", {}, interaction_id, interaction_id)
		moving = true
		bay.audio.play_cue("valve", global_position)
		var tween := create_tween()
		tween.tween_property(moving_part, "rotation:z", PI / 2, .8)
		tween.tween_callback(func():
			bay.cooling_ready = true
			moving = false
			bay.telemetry.record("cooling_regulator_changed", {"wheel_quarter_turns": 1}, interaction_id, interaction_id)
			bay.telemetry.record("cooling_ready")
			bay.progress("COOLING_READY")
			bay.set_stage("RELAY_UNRESOLVED")
			bay.tint_indicator(self, "CoolingIndicator", Color(.08, .65, .8))
			bay.pulse_route("CoolingRoute", Color(.08, .65, .8), 1)
			bay.audio.play_cue("flow", global_position)
			refresh())
	elif kind == "relay":
		if moving or bay.relay_ready:
			return
		bay.begin_action("relay", interaction_id, interaction_id, -1, "RELAY")
		bay.telemetry.record("relay_interaction", {}, interaction_id, interaction_id)
		moving = true
		var tween := create_tween()
		if not bay.cooling_ready:
			bay.telemetry.record("relay_rejected", {"reason": "cooling_not_ready"}, interaction_id, interaction_id)
			bay.register_failure()
			bay.audio.play_cue("relay_reject", global_position)
			tween.tween_property(moving_part, "rotation:z", -.15, .12)
			tween.tween_property(moving_part, "rotation:z", 0, .25)
			tween.tween_callback(func(): moving = false)
		else:
			bay.audio.play_cue("relay_engage", global_position)
			tween.tween_property(moving_part, "rotation:z", -PI / 3, .5)
			tween.tween_callback(func():
				bay.relay_ready = true
				moving = false
				bay.telemetry.record("relay_activated", {}, interaction_id, interaction_id)
				bay.progress("RELAY_READY")
				bay.set_stage("COUPLING_READY")
				bay.tint_indicator(self, "RelayIndicator", Color(.08, .65, .8))
				bay.pulse_route("RelayRoute", Color(.08, .65, .8), 1)
				refresh())
func turn(_direction: int) -> void:
	pass
func release_to(point: Vector3) -> void:
	if kind != "scanner" or scanning:
		return
	bay.begin_action("release", interaction_id, "WORLD_SURFACE", -1, "DIAGNOSTICS", "DIAGNOSTIC_SCANNER")
	reparent(bay)
	global_position = point + Vector3.UP * .03
	rotation = Vector3.ZERO
	carried = false
	collision_layer = 2
	bay.telemetry.record("scanner_released", {}, interaction_id, "WORLD_SURFACE")
func scan(target: Node) -> void:
	if kind != "scanner" or scanning or target == null or not target.has_method("scan_status"):
		return
	scanning = true
	var target_id: String = target.interaction_id
	bay.begin_action("scan", interaction_id, target_id, -1, target_id, "DIAGNOSTIC_SCANNER")
	bay.telemetry.record("scanner_scan_started", {}, interaction_id, target_id)
	bay.audio.play_cue("scan_start", global_position)
	show_message("scanner.reading")
	await get_tree().create_timer(.65).timeout
	# The player must keep the physical target in sight through acquisition.
	if bay.player.held != self or bay.player.target() != target:
		bay.telemetry.record("scanner_scan_cancelled", {"reason": "target_lost"}, interaction_id, target_id)
		show_message("scanner.target_lost")
	else:
		var status: String = target.scan_status()
		show_message(status)
		bay.telemetry.record("scanner_scan_completed", {"diagnostic": status}, interaction_id, target_id)
		bay.audio.play_cue("scan_complete", global_position)
		bay.audio.play_cue("trace", target.global_position)
	scanning = false
