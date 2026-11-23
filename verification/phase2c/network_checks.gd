extends SceneTree
func _initialize() -> void:
	var model = load("res://scripts/intervention/coolant_network.gd").new()
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/missions/mb03.json"))
	var valid: Array = []
	for p in range(4):
		for r in range(4):
			for b in range(4):
				model.configure({"primary": p, "regulator": r, "bypass": b})
				var state: Dictionary = model.evidence()
				assert(state.flow >= 0 and state.amplitude >= 0)
				if state.safe:
					valid.append([p,r,b])
	assert(valid.size() >= 3, "Do not collapse the simulation to one exact answer")
	var reachability: Dictionary = {}
	for id in definitions.configuration_order:
		var start: Dictionary = definitions.start_configurations[id]
		model.configure(start)
		assert(not model.evidence().safe)
		var queue: Array = [[int(start.primary), int(start.regulator), int(start.bypass)]]
		var seen: Dictionary = {}
		var reached := false
		while not queue.is_empty():
			var point: Array = queue.pop_front()
			if seen.has(str(point)):
				continue
			seen[str(point)] = true
			if point in valid:
				reached = true
				break
			for axis in range(3):
				for direction in [-1,1]:
					var candidate := point.duplicate()
					candidate[axis] += direction
					if candidate[axis] >= 0 and candidate[axis] <= 3:
						queue.append(candidate)
		assert(reached)
		reachability[id] = reached
	model.configure({"primary":3,"regulator":2,"bypass":0})
	var full: Dictionary = model.evidence()
	model.bypass=1
	assert(model.evidence().pressure < full.pressure and model.evidence().flow < full.flow)
	model.bypass=0;model.primary=1
	assert(model.evidence().flow < full.flow)
	model.primary=3;model.regulator=0
	assert(model.evidence().amplitude > full.amplitude)
	var file := FileAccess.open("res://verification/phase2c/network_model.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"parameter_states_checked":64,"valid_balances":valid,"start_configurations_reachable":reachability,"monotonic_consequences_passed":true},"\t"))
	print("NETWORK_MODEL_PASS ",valid)
	quit()
