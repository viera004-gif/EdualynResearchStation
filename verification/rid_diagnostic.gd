extends SceneTree
var mode := "minimal_probe"
var world: Node3D
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rid-case="):
			mode = arg.trim_prefix("--rid-case=")
	build.call_deferred()
func build() -> void:
	if mode.begins_with("full"):
		world = load("res://scenes/main/module_bay_01.tscn").instantiate()
		root.add_child(world)
	else:
		world = Node3D.new()
		root.add_child(world)
		var camera := Camera3D.new()
		camera.position = Vector3(0, .4, 1.5)
		world.add_child(camera)
		camera.look_at(Vector3(0, .1, 0))
		camera.current = true
		world.add_child(load("res://assets/models/energy_module.glb").instantiate())
		var light := OmniLight3D.new()
		light.position = Vector3(1, 2, 1)
		world.add_child(light)
		if mode != "minimal_no_probe":
			var probe := ReflectionProbe.new()
			probe.position = Vector3(0, .3, 0)
			probe.size = Vector3(4, 4, 4)
			world.add_child(probe)
	for i in 120:
		await process_frame
	if mode == "full_early_cleanup":
		world.queue_free()
		for i in 12:
			await process_frame
	print("RID_DIAGNOSTIC_DONE ", mode)
	quit(0)
