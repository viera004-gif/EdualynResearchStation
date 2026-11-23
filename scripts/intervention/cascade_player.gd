extends "res://scripts/player/first_person.gd"
func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() and (event.is_action("interact") or event.is_action("inspect")) and bay.definition.data.slot == "MB01":
		return
	super._unhandled_input(event)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("inspect"):
		var node = target()
		if node != null and node.has_method("scan_status"):
			bay.inspect_subsystem(node)
	if event.is_action_pressed("put_down"):
		put_down()
	if (held == null or held.has_method("scan")) and (event.is_action_pressed("rotate_left") or event.is_action_pressed("rotate_right")):
		var node = target()
		if node != null and node.has_method("adjust"):
			node.adjust(-1 if event.is_action_pressed("rotate_left") else 1)
func attempt_placement() -> void:
	if held != null and held.has_method("scan"):
		held.scan(target())
	else:
		super.attempt_placement()
func put_down() -> void:
	if held == null or not held.has_method("release_to"):
		return
	if held.has_method("scan") and held.scanning:
		return
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 2.6, 1, [get_rid()])
	var contact := get_world_3d().direct_space_state.intersect_ray(query)
	if not contact.is_empty() and contact.normal.dot(Vector3.UP) > .65:
		var object = held
		held = null
		object.release_to(contact.position)
