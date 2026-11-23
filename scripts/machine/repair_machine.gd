extends "res://scripts/interaction/interactable.gd"
enum State { OFFLINE, STARTUP, ACTIVE }
var state: State = State.OFFLINE
var rotor: Node3D
var core: Node3D
var spin_speed: float = 0.0
var indicator_light: OmniLight3D
func _ready() -> void:
	bounds = Vector3(1.9, 2.4, .8)
	bounds_offset = Vector3(0, 1.2, -.15)
	super._ready()
	bay.tint_indicator(self, "CoreIndicator", Color(.018, .035, .045))
	rotor = find_child("RingRotor", true, false) as Node3D
	core = find_child("CoreLift", true, false) as Node3D
	indicator_light = OmniLight3D.new()
	indicator_light.position = Vector3(0, 1.8, .45)
	indicator_light.light_color = Color(.11, .57, .8)
	indicator_light.light_energy = 0
	indicator_light.omni_range = 2
	add_child(indicator_light)
	assert(rotor != null and core != null, "Imported moving machine assemblies missing")
func prompt() -> String:
	return "Repair assembly • " + ["OFFLINE", "STARTUP", "ACTIVE"][state]
func startup() -> void:
	if state != State.OFFLINE:
		return
	state = State.STARTUP
	bay.audio.play_cue("startup", global_position + Vector3(0, 1.6, 0))
	bay.tint_indicator(self, "CoreIndicator", Color(.09, .62, .86))
	bay.tint_indicator(self, "MachineIndicator", Color(.09, .62, .86))
	var tween := create_tween()
	tween.tween_interval(.35)
	tween.tween_property(indicator_light, "light_energy", 1.25, .65)
	tween.tween_property(core, "position:y", core.position.y + .16, 1.15).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(self, "spin_speed", .85, 1.6)
	tween.tween_interval(.6)
	tween.tween_callback(online)
func online() -> void:
	state = State.ACTIVE
	bay.machine_online()
func _process(delta: float) -> void:
	if rotor != null:
		rotor.rotate_z(spin_speed * delta)
