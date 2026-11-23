extends CharacterBody3D
var camera: Camera3D
var ray: RayCast3D
var carry_anchor: Node3D
var held: Node3D
var bay: Node
var pitch: float = -.045
var sensitivity: float = .0021
var speed: float = 2.5
func _ready() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = .27
	capsule.height = 1.72
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = .86
	add_child(shape)
	collision_layer = 1
	collision_mask = 1
	camera = Camera3D.new()
	camera.position.y = 1.61
	camera.fov = 72
	camera.near = .07
	add_child(camera)
	camera.current = true
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.65)
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	ray.collision_mask = 3
	ray.add_exception(self)
	camera.add_child(ray)
	carry_anchor = Node3D.new()
	carry_anchor.position = Vector3(.35, -.33, -.83)
	camera.add_child(carry_anchor)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.28, 1.28)
		camera.rotation.x = pitch
	if event.is_action_pressed("interact"):
		interact()
	if event.is_action_pressed("rotate_left") and held != null:
		held.turn(-1)
	if event.is_action_pressed("rotate_right") and held != null:
		held.turn(1)
	if event.is_action_pressed("place"):
		attempt_placement()
func target():
	ray.force_raycast_update()
	if ray.is_colliding():
		var node = ray.get_collider()
		if node is Area3D and node.has_method("prompt"):
			return node
	return null
func interact() -> void:
	var node = target()
	if node != null and node.has_method("interact"):
		node.interact(self)
func attempt_placement() -> void:
	if held == null:
		return
	var node = target()
	if node != null and node.has_method("attempt"):
		node.attempt(self)
func _physics_process(delta: float) -> void:
	camera.rotation.x = pitch
	var movement := Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		movement = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(movement.x, 0, movement.y)).normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 12)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 12)
	if not is_on_floor():
		velocity.y -= 18 * delta
	else:
		velocity.y = 0
	move_and_slide()
