extends "res://verification/phase2b/polarity_probe.gd"
func run(world: Node) -> void:
	bay = world
	selected = bay.localization.locale
	var tree: SceneTree = bay.get_tree()
	var anchor := Node.new()
	anchor.set_meta("probe",self)
	tree.root.add_child(anchor)
	await pause(1)
	check(not bay.program.available("MB03"),"mb03_locked_before_mb02_completion")
	bay.program.enter("MB03",bay)
	await pause(.2)
	check(tree.current_scene==bay,"cannot_bypass_unlock")
	await turn(bay.relay_b,1)
	await turn(bay.relay_b,1)
	await turn(bay.relay_a,1)
	await turn(bay.relay_a,1)
	await face(bay.route_tester,Vector3(-2.2,0,-2.05),Vector3(0,1.25,.3))
	await action("interact")
	await pause(5)
	check(bay.phase==bay.Phase.COMPLETE and bay.program.available("MB03"),"completion_only_unlock")
	var restored = load("res://scripts/program/module_bay_program.gd").new()
	restored.configure()
	check(restored.available("MB03") and not restored.available("MB04"),"unlock_save_reload")
	restored.free()
	bay.localization.set_locale("tr")
	await face(bay.operations_console,Vector3(-3.5,0,1.2),Vector3(0,1.5,.16))
	check(bay.operations_console.prompt()=="program.enter_mb03","console_access_prompt")
	var transport = bay.telemetry
	var input := InputEventAction.new()
	input.action="interact";input.pressed=true
	Input.parse_input_event(input)
	await tree.process_frame
	input=InputEventAction.new();input.action="interact";input.pressed=false
	Input.parse_input_event(input)
	await tree.create_timer(2).timeout
	bay=tree.current_scene
	check(bay.definition.data.slot=="MB03" and bay.localization.locale=="tr","physical_console_transition_and_locale")
	check(transport.pending.size()>0 and transport.get_parent()==tree.root,"offline_evidence_retained")
	var rotation: Array[String]=[bay.configuration_id]
	for index in range(3):
		bay.program.enter("MB03",bay)
		await tree.create_timer(1).timeout
		bay=tree.current_scene
		rotation.append(bay.configuration_id)
	check(rotation==["A","B","C","A"],"controlled_configuration_rotation")
	report["configuration_rotation"]=rotation
	report["all_gameplay_checks_passed"]=not failed
	var file := FileAccess.open("res://verification/phase2c/progression.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	tree.quit(2 if failed else 0)
