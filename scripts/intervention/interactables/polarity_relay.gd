extends "res://scripts/interaction/interactable.gd"
var orientation_step := 0
var required_orientation := 0
var moving := false
var rotor: Node3D
var screen: Label3D
var contact_faces: Array[StandardMaterial3D] = []
func _ready() -> void:
	bounds = Vector3(.8, 1.1, .7)
	bounds_offset = Vector3(0, 1.35, .25)
	super._ready()
	rotor = find_child("PolarityRotor", true, false)
	assert(rotor != null)
	rotor.rotation.z = orientation_step * PI / 2
	var fixed_finish := StandardMaterial3D.new()
	fixed_finish.albedo_color = Color(.90, .75, .51)
	var moving_finish := StandardMaterial3D.new()
	moving_finish.albedo_color = Color(.88, .92, .95)
	for prefix in ["Fixed", "Rotor"]:
		for polarity in ["Positive*", "Negative*"]:
			for sign_mesh in find_children(prefix + polarity, "MeshInstance3D", true, false):
				sign_mesh.scale *= 1.46
				sign_mesh.material_override = fixed_finish if prefix == "Fixed" else moving_finish
				if prefix == "Rotor":
					sign_mesh.position.y *= .95
				else:
					sign_mesh.position.z += .08
	for face in find_children("FixedContact*", "MeshInstance3D", true, false):
		face.scale *= Vector3(1.10, 1.10, 1.0)
		var surface := face.get_active_material(0).duplicate() as StandardMaterial3D
		face.material_override = surface
		surface.emission_enabled = true
		surface.emission = Color(.92, .36, .10)
		surface.emission_energy_multiplier = 0
		contact_faces.append(surface)
	screen = Label3D.new()
	screen.position = Vector3(0, 2.02, .13)
	screen.font_size = 28
	screen.pixel_size = .00125
	screen.modulate = Color(.48, .8, .9)
	add_child(screen)
func aligned() -> bool:
	return orientation_step == required_orientation
func show_message(key: String, values: Dictionary = {}) -> void:
	bay.localization.bind_label(screen, key, values)
func refresh() -> void:
	show_message("polarity.unit_" + ("a" if interaction_id == "RELAY_A" else "b"))
func prompt() -> String:
	return "polarity.relay_locked" if bay.route_ready else "polarity.rotate_prompt"
func scan_status() -> String:
	var unit := "a" if interaction_id == "RELAY_A" else "b"
	if moving:
		return "polarity.scanner_settling"
	if not aligned():
		return "polarity.scan_" + unit + "_mismatch"
	if unit == "b" and not bay.relay_a.aligned():
		return "polarity.scan_b_input_lost"
	return "polarity.scan_" + unit + "_stable"
func interact(_player: Node) -> void:
	adjust(1)
func adjust(direction: int) -> void:
	if moving or bay.route_ready:
		return
	moving = true
	var next := posmod(orientation_step + direction, 4)
	bay.begin_action("relay_rotation", interaction_id, interaction_id, next, interaction_id)
	orientation_step = next
	bay.configuration_moving()
	bay.telemetry.record("relay_unit_rotated", {"quarter_turn": direction, "orientation_step": next}, interaction_id, interaction_id)
	bay.audio.play_cue("rotate", global_position)
	var tween := create_tween()
	tween.tween_property(rotor, "rotation:z", rotor.rotation.z + direction * PI / 2, .3)
	tween.tween_callback(func():
		moving = false
		bay.relay_changed(self))
func fault_strength(value: float) -> void:
	for surface in contact_faces:
		surface.emission_energy_multiplier = value
func latch() -> void:
	for rail in find_children("*LatchRail*", "MeshInstance3D", true, false):
		create_tween().tween_property(rail, "position:y", rail.position.y - .055, .25)
