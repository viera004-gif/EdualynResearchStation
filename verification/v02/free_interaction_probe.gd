extends "res://scripts/verification/run_probe.gd"
# Separate short scenario: never open the terminal or support station.
func pause(seconds: float) -> void:
	await bay.get_tree().create_timer(seconds).timeout
func run(world: Node) -> void:
	bay = world
	await pause(1)
	await aim(Vector3(-1.35, 0, -2.1), bay.cooling.global_position + Vector3(0, 1.4, .3))
	await action("interact")
	await pause(1)
	check(bay.cooling_ready and bay.history.running, "free_start_at_regulator")
	await aim(Vector3(0, 0, -2.1), bay.relay.global_position + Vector3(0, 1.4, .3))
	await action("interact")
	await pause(.7)
	check(bay.relay_ready, "relay_without_terminal_or_help")
	await aim(Vector3(-1.7, 0, 1.45), bay.module.global_position + Vector3(0, .18, 0))
	await action("interact")
	await action("rotate_right")
	await pause(.3)
	await aim(Vector3(2.05, 0, .1), bay.correct_socket.global_position + Vector3(0, .11, 0))
	await action("place")
	await pause(5)
	check(bay.phase == bay.Phase.COMPLETE, "complete_without_help_or_terminal")
	check(bay.history.help_requests == 0, "help_never_required")
	bay.telemetry.export_trace("res://verification/v02/telemetry_free.json")
	report["all_gameplay_checks_passed"] = not failed
	var file := FileAccess.open("res://verification/v02/runtime_free.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	bay.get_tree().quit(2 if failed else 0)
