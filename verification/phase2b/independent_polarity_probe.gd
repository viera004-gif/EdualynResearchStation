extends "res://verification/phase2b/polarity_probe.gd"
func run(world: Node) -> void:
	bay = world
	selected = bay.localization.locale
	await pause(1)
	await test_route("BOTH_RELAYS_MISMATCHED")
	# Reverse exploration order: repair B first, with no scanner or AI requests.
	await turn(bay.relay_b, 1)
	await turn(bay.relay_b, 1)
	await test_route("INPUT_BLOCKED_AT_A")
	await turn(bay.relay_a, 1)
	await turn(bay.relay_a, 1)
	await face(bay.route_tester, Vector3(-2.2, 0, -2.05), Vector3(0, 1.25, .3))
	await action("interact")
	await pause(5)
	check(bay.phase == bay.Phase.COMPLETE, "b_first_independent_completion")
	check(bay.history.help_requests == 0 and bay.player.held == null, "no_help_or_scanner_required")
	bay.telemetry.export_trace("res://verification/phase2b/telemetry_independent_mb02.json")
	report["all_gameplay_checks_passed"] = not failed
	var file := FileAccess.open("res://verification/phase2b/independent_mb02.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	bay.get_tree().quit(2 if failed else 0)
