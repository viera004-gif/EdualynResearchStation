extends "res://scripts/interaction/energy_module.gd"
func prompt() -> String:
	return "interaction.pick_up_module" if state == State.AVAILABLE else ""
func interact(player: Node) -> void:
	if player.held != null or state != State.AVAILABLE:
		return
	bay.begin_action("pickup", "ENERGY_MODULE_A", interaction_id, 0, "POWER_COUPLER")
	orientation_step = 0
	super.interact(player)
func turn(direction: int) -> void:
	if state != State.CARRIED:
		return
	bay.begin_action("rotation", "ENERGY_MODULE_A", bay.last_placement_target, posmod(orientation_step + direction, 4), "POWER_COUPLER")
	super.turn(direction)
func release_to(point: Vector3) -> void:
	bay.begin_action("release", "ENERGY_MODULE_A", "WORLD_SURFACE", orientation_step, "POWER_COUPLER")
	reparent(bay)
	global_position = point + Vector3.UP * .055
	rotation = Vector3(0, orientation_step * PI / 2.0, 0)
	state = State.AVAILABLE
	collision_layer = 2
	bay.telemetry.record("object_released", {"world_position": [global_position.x, global_position.y, global_position.z]}, "ENERGY_MODULE_A", "WORLD_SURFACE")
