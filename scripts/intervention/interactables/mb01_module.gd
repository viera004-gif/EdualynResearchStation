extends "res://scripts/interaction/energy_module.gd"

var keyed := true
var pickup_key := "interaction.pick_up_module"
var last_socket := ""

func prompt() -> String:
	if state != State.AVAILABLE:
		return ""
	return pickup_key if bay.player.held == null else "interaction.hands_full"

func interact(player: Node) -> void:
	if player.held != null or state != State.AVAILABLE:
		return
	bay.begin_action("pickup", interaction_id, interaction_id, orientation_step, interaction_id)
	state = State.CARRIED
	collision_layer = 0
	reparent(player.carry_anchor)
	position = Vector3.ZERO
	rotation = Vector3(0, orientation_step * PI / 2.0, 0)
	bay.block_event("object_grabbed", self)
	bay.audio.play_cue("pickup", global_position)
	player.held = self
	if keyed:
		bay.teach_rotation()

func turn(direction: int) -> void:
	if state != State.CARRIED:
		return
	orientation_step = posmod(orientation_step + direction, 4)
	bay.begin_action("rotation", interaction_id, last_socket, orientation_step, interaction_id)
	stop_turn()
	turn_tween = create_tween()
	var angle := rotation.y + angle_difference(rotation.y, orientation_step * PI / 2.0)
	turn_tween.tween_property(self, "rotation:y", angle, .16)
	bay.audio.play_cue("rotate", global_position)
	bay.block_event("object_rotated", self, "", {"quarter_turn": direction})

func release_to(point: Vector3) -> void:
	stop_turn()
	bay.begin_action("release", interaction_id, "WORLD_SURFACE", orientation_step, interaction_id)
	reparent(bay)
	global_position = point + Vector3.UP * .055
	rotation = Vector3(0, orientation_step * PI / 2.0, 0)
	state = State.AVAILABLE
	collision_layer = 2
	bay.block_event("object_released", self, "WORLD_SURFACE", {
		"world_position": [global_position.x, global_position.y, global_position.z]})

func seat(socket: Node3D, angle: int) -> void:
	stop_turn()
	state = State.PLACED
	collision_layer = 0
	reparent(socket)
	position = Vector3(0, .17, .24)
	rotation = Vector3(0, angle * PI / 2.0, 0)
	var insertion := create_tween().set_trans(Tween.TRANS_SINE)
	insertion.tween_property(self, "position:z", 0.0, .20)
	insertion.parallel().tween_property(self, "position:y", .09, .20)
	await insertion.finished

func stop_turn() -> void:
	if turn_tween != null:
		turn_tween.kill()
