extends RefCounted
var tree: SceneTree
var report: Dictionary = {}
var failed := false
var tracked: Dictionary = {}
var paths := {
	"MB01": ["res://assets/models/intervention_v02/cooling_regulator.glb", "res://assets/models/intervention_v02/auxiliary_relay.glb", "res://assets/models/intervention_v02/power_routes.glb"],
	"MB02": ["res://assets/models/mb02/polarity_relay_a.glb", "res://assets/models/mb02/polarity_relay_b.glb", "res://assets/models/mb02/polarity_routes.glb"],
	"MB03": ["res://assets/models/mb03/coolant_manifold.glb", "res://assets/models/mb03/pressure_regulator.glb", "res://assets/models/mb03/coolant_routes.glb"]}
func snapshot(label: String) -> void:
	var current = tree.current_scene
	var loaded: Dictionary = {}
	for slot in paths:
		var meshes: Array = []
		var materials: Array = []
		for node in current.find_children("*", "MeshInstance3D", true, false):
			for path in paths[slot]:
				if node.mesh != null and node.mesh.resource_path.begins_with(path + "::"):
					meshes.append(weakref(node.mesh))
					for surface in node.mesh.get_surface_count():
						var material = node.mesh.surface_get_material(surface)
						if material != null:
							materials.append(weakref(material))
		var old_alive := 0
		if tracked.has(slot):
			for weak in tracked[slot]:
				if weak.get_ref() != null:
					old_alive += 1
		loaded[slot] = {"live_scene_meshes": meshes.size(), "previous_resources_still_alive": old_alive}
		var expected: bool = slot == current.definition.data.slot
		if expected != (meshes.size() > 0) or (not expected and old_alive > 0):
			failed = true
		if expected:
			tracked[slot] = meshes + materials
	report[label] = loaded
func run(world: Node) -> void:
	tree = world.get_tree()
	var anchor := Node.new()
	anchor.set_meta("probe", self)
	tree.root.add_child(anchor)
	await tree.create_timer(2).timeout
	snapshot("initial_MB01")
	var destinations: Array[String] = ["MB02"]
	if world.program.entry("MB03").get("implemented", false):
		destinations.append("MB03")
	destinations.append("MB01")
	for slot in destinations:
		var current = tree.current_scene
		current.program.enter(slot, current)
		await tree.create_timer(2).timeout
		snapshot("after_" + slot)
		for child in tree.root.get_children():
			if child.get_script() == load("res://scripts/intervention/cascade_telemetry.gd"):
				if child.context_provider.is_valid():
					failed = true
	report["only_current_mission_heavy_resources"] = not failed
	var suffix := "all" if paths.MB03[0] and tree.current_scene.program.entry("MB03").get("implemented", false) else "before_mb03"
	var file := FileAccess.open("res://verification/phase2c/resources_" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("RESOURCE_AUDIT ", JSON.stringify(report))
	tree.quit(2 if failed else 0)
