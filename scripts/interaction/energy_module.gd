extends "res://scripts/interaction/interactable.gd"
enum State { AVAILABLE, CARRIED, PLACED }
var state: State = State.AVAILABLE
var orientation_step: int = 0
var turn_tween: Tween
func _ready() -> void:
	bounds = Vector3(.62, .39, .46)
	bounds_offset = Vector3(0, .15, 0)
	super._ready()
func prompt() -> String:
	if state == State.AVAILABLE and bay.phase >= bay.Phase.MISSION_ACTIVE:
		return "[F]  Lift energy module"
	return "Energy module • activate the terminal first" if state == State.AVAILABLE else ""
func interact(player: Node) -> void:
	if state != State.AVAILABLE or bay.phase < bay.Phase.MISSION_ACTIVE:
		return
	state = State.CARRIED
	collision_layer = 0
	reparent(player.carry_anchor)
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	player.held = self
	bay.module_acquired()
func turn(direction: int) -> void:
	if state != State.CARRIED:
		return
	orientation_step = posmod(orientation_step + direction, 4)
	if turn_tween != null and turn_tween.is_valid():
		turn_tween.kill()
	turn_tween = create_tween()
	turn_tween.tween_property(self, "rotation:y", float(orientation_step) * PI / 2.0, .16)
	bay.audio.play_cue("rotate", global_position)
	bay.telemetry.record("object_rotated", {"quarter_turn": direction, "orientation_step": orientation_step}, "ENERGY_MODULE_A")
func lock_to(socket: Node3D) -> void:
	if turn_tween != null and turn_tween.is_valid():
		turn_tween.kill()
	state = State.PLACED
	reparent(socket)
	position = Vector3(0, .09, 0)
	rotation = Vector3(0, PI / 2.0, 0)
	collision_layer = 0
