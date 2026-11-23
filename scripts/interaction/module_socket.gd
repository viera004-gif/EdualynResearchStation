extends "res://scripts/interaction/interactable.gd"
var accepts_module: bool = false
var feedback_light: OmniLight3D
var feedback_tween: Tween
var locked: bool = false
func _ready() -> void:
	bounds = Vector3(.68, .36, .72)
	bounds_offset = Vector3(0, .10, 0)
	super._ready()
	feedback_light = OmniLight3D.new()
	feedback_light.position = Vector3(0, .22, .24)
	feedback_light.omni_range = .4
	feedback_light.light_specular = 0.0
	feedback_light.light_energy = 0.0
	add_child(feedback_light)
func prompt() -> String:
	if bay.player.held != null:
		return "[LMB]  Couple module • [R / T] rotate"
	return "POWER A • keyed coupling" if accepts_module else "SERVICE • auxiliary interface"
func attempt(player: Node) -> void:
	if player.held == null or locked:
		return
	bay.placement_attempt(interaction_id)
	if not accepts_module:
		reject("incompatible_interface")
	elif player.held.orientation_step != 1:
		reject("key_orientation")
	else:
		var module = player.held
		player.held = null
		module.lock_to(self)
		lock_visuals()
		bay.placement_valid(interaction_id)
func stop_feedback() -> void:
	if feedback_tween != null and feedback_tween.is_valid():
		feedback_tween.kill()
func reject(reason: String) -> void:
	stop_feedback()
	set_indicator(Color(.95, .25, .035), .18)
	bay.audio.play_cue("invalid", global_position)
	bay.telemetry.record("placement_invalid", {"reason": reason}, "ENERGY_MODULE_A", interaction_id)
	bay.phase = bay.Phase.MODULE_ACQUIRED
	var materials: Array = bay.tint_indicator(self, "SocketIndicator", Color(.95, .25, .035))
	feedback_tween = create_tween()
	feedback_tween.tween_property(feedback_light, "light_energy", 0.0, .65)
	for material in materials:
		feedback_tween.parallel().tween_property(material, "emission", Color(.018, .026, .035), .65)
		feedback_tween.parallel().tween_property(material, "albedo_color", Color(.018, .026, .035), .65)
func lock_visuals() -> void:
	stop_feedback()
	locked = true
	set_indicator(Color(.08, .61, .88), 1.0)
	bay.audio.play_cue("lock", global_position)
	# Close the already modeled guide rails, without replacing any render geometry.
	for rail in find_children("*DockGuideRail*", "MeshInstance3D", true, false):
		var tween := create_tween()
		tween.tween_property(rail, "position:x", rail.position.x - signf(rail.position.x) * .018, .18)
func set_indicator(color: Color, energy: float) -> void:
	feedback_light.light_color = color
	feedback_light.light_energy = energy
	bay.tint_indicator(self, "SocketIndicator", color)
