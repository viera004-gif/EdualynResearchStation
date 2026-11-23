extends "res://scripts/intervention/interactables/cascade_machine.gd"
func startup() -> void:
	if state != State.OFFLINE:
		return
	state = State.STARTUP
	var at := global_position + Vector3(0, 1.6, 0)
	bay.audio.play_cue("startup", at)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_interval(.20)
	tween.tween_callback(bay.energize_routes)
	tween.tween_property(indicator_light, "light_energy", 1.8, .62)
	tween.tween_property(core, "position:y", core.position.y + .27, 1.18)
	tween.tween_property(self, "spin_speed", 1.45, 1.45)
	tween.parallel().tween_callback(func(): bay.audio.start_hum(at))
	tween.tween_callback(online)
