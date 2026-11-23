extends "res://verification/phase2c/coolant_probe.gd"
func run(world: Node) -> void:
	bay = world
	selected = bay.localization.locale
	await pause(1)
	check(bay.configuration_id == "C", "combined_fault_start")
	await face(bay.core_gauge,Vector3(.15,0,-2),Vector3(0,0,.1))
	await action("interact")
	# Regulator first, then supply adjustment. Bypass remains mildly open.
	await adjust(bay.regulator,1)
	check(not bay.network.evidence().safe, "one_fault_correction_not_enough")
	await adjust(bay.primary,1)
	await pause(9)
	check(bay.phase == bay.Phase.COMPLETE, "alternative_balance_independent_completion")
	check(bay.network.primary==3 and bay.network.regulator==2 and bay.network.bypass==1, "different_valid_final_balance")
	check(bay.history.help_requests==0 and bay.player.held==null, "scanner_and_ai_optional")
	report["all_gameplay_checks_passed"] = not failed
	bay.telemetry.export_trace("res://verification/phase2c/telemetry_independent.json")
	var file := FileAccess.open("res://verification/phase2c/independent.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	bay.get_tree().quit(2 if failed else 0)
