extends SceneTree
## Rendered integration probe. Start with a fresh development progress file per locale.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(155).timeout.connect(func(): quit(3))
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await process_frame
	await process_frame
	var probe: RefCounted = load("res://verification/mb01_experience/playthrough.gd").new()
	await probe.run(current_scene)
	quit(2 if probe.failed else 0)
