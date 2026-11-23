extends "res://scripts/verification/run_probe.gd"
func run(world: Node) -> void:
	bay = world
	await bay.get_tree().create_timer(2).timeout
	await aim(Vector3(0, 0, 2.4), Vector3(0, 1.5, -3.5))
	await bay.get_tree().create_timer(1).timeout
	bay.metrics.reset_samples()
	await bay.get_tree().create_timer(6).timeout
	var result: Dictionary = bay.metrics.report(bay)
	result["profile_kind"] = "controlled_idle_same_camera_six_seconds"
	result["mission_id"] = bay.definition.data.mission_id
	var directory := "res://verification/phase2b"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-output-dir="):
			directory = arg.trim_prefix("--profile-output-dir=")
	if bay.get("material_pool") != null:
		result["mission_pooled_materials"] = bay.material_pool.size()
	var file := FileAccess.open(directory + "/profile_" + bay.definition.data.slot + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	await RenderingServer.frame_post_draw
	bay.get_viewport().get_texture().get_image().save_png(directory + "/profile_" + bay.definition.data.slot + ".png")
	bay.get_tree().quit()
