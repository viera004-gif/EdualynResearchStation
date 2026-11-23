extends SceneTree
var world
var metrics
var label := "before"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-label="):
			label = arg.trim_prefix("--profile-label=")
	run.call_deferred()
func run() -> void:
	world = load("res://scenes/main/module_bay_01.tscn").instantiate()
	root.add_child(world)
	world.player.set_process_unhandled_input(false)
	world.player.set_physics_process(false)
	world.player.position = Vector3(0, 0, 3.1)
	world.player.rotation = Vector3.ZERO
	world.player.pitch = -.045
	world.player.camera.rotation = Vector3(-.045, 0, 0)
	metrics = load("res://scripts/verification/build_metrics.gd").new()
	root.add_child(metrics)
	for i in 180:
		await process_frame
	metrics.reset_samples()
	await create_timer(4).timeout
	var idle: Dictionary = metrics.report(world)
	# Diagnostic-only activation; API explicitly points to an unavailable local
	# port. This never records a real student session.
	world.machine.startup()
	await create_timer(5).timeout
	metrics.reset_samples()
	await create_timer(4).timeout
	var active: Dictionary = metrics.report(world)
	idle["notes"] = "Fixed camera, no screenshot/readback; 4 seconds after warmup. Engine monitors delayed; memory is an estimate."
	active["notes"] = idle["notes"]
	var report := {"idle": idle, "active": active, "label": label, "camera_transform": str(world.player.camera.global_transform),
		"method": "Same fixed camera, no screenshots, 4-second windows after warmup; synthetic active-state diagnostic, API unavailable"}
	var file := FileAccess.open("res://verification/phase1b/profile_" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("REFERENCE_PROFILE ", JSON.stringify(report))
	quit(0)
