extends Node
var seen_frames: int = 0
var samples: int = 0
var elapsed: float = 0.0
var longest_frame: float = 0.0
var lowest_reported_fps: float = INF
var draw_sum: float = 0.0
var draw_max: float = 0.0
var primitive_sum: float = 0.0
var texture_max_bytes: float = 0.0
var video_max_bytes: float = 0.0
func _process(delta: float) -> void:
	seen_frames += 1
	if seen_frames <= 90:
		return
	samples += 1
	elapsed += delta
	longest_frame = maxf(longest_frame, delta)
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	if fps > 0:
		lowest_reported_fps = minf(lowest_reported_fps, fps)
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	draw_sum += draws
	draw_max = maxf(draw_max, draws)
	primitive_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	texture_max_bytes = maxf(texture_max_bytes, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	video_max_bytes = maxf(video_max_bytes, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
func inventory(root: Node, result: Dictionary, materials: Dictionary) -> void:
	if root is MeshInstance3D:
		result.mesh_instances += 1
		var mesh: Mesh = root.mesh
		if mesh != null:
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				var indices = arrays[Mesh.ARRAY_INDEX]
				result.mesh_triangles += int(indices.size() / 3) if indices != null and indices.size() > 0 else int(arrays[Mesh.ARRAY_VERTEX].size() / 3)
				var material: Material = root.material_override
				if material == null:
					material = root.get_surface_override_material(surface)
				if material == null:
					material = mesh.surface_get_material(surface)
				if material != null:
					materials[material.get_instance_id()] = material.resource_name
	if root is Light3D:
		result.dynamic_light_nodes += 1
		if root.light_energy > 0.001:
			result.active_lights_at_snapshot += 1
		if root.shadow_enabled:
			result.shadow_lights += 1
	if root is CollisionShape3D:
		var key: String = root.shape.get_class()
		result.collision_shapes[key] = result.collision_shapes.get(key, 0) + 1
	if root is ReflectionProbe:
		result.reflection_probes += 1
	for child in root.get_children():
		inventory(child, result, materials)
func report(world: Node) -> Dictionary:
	var result := {"mesh_instances": 0, "mesh_triangles": 0, "dynamic_light_nodes": 0,
		"active_lights_at_snapshot": 0, "shadow_lights": 0, "collision_shapes": {}, "reflection_probes": 0}
	var materials: Dictionary = {}
	inventory(world, result, materials)
	result["runtime_material_resources"] = materials.size()
	result["material_resource_names"] = materials.values()
	result["sample_frames"] = samples
	result["sample_seconds"] = elapsed
	result["average_fps"] = float(samples) / maxf(elapsed, .001)
	result["minimum_instantaneous_fps"] = 1.0 / maxf(longest_frame, .000001)
	result["lowest_engine_one_second_fps"] = lowest_reported_fps if lowest_reported_fps < INF else null
	result["draw_calls_mean_monitor"] = draw_sum / maxf(samples, 1)
	result["draw_calls_max_monitor"] = draw_max
	result["primitives_mean_monitor"] = primitive_sum / maxf(samples, 1)
	result["texture_memory_peak_bytes_monitor"] = texture_max_bytes
	result["video_memory_peak_bytes_monitor"] = video_max_bytes
	result["viewport"] = {"width": world.get_viewport().get_visible_rect().size.x, "height": world.get_viewport().get_visible_rect().size.y}
	result["msaa_3d_enum"] = world.get_viewport().msaa_3d
	result["notes"] = "Short automated playthrough; excludes first 90 frames; includes screenshot/readback overhead. Engine monitors may update at ~1Hz; memory is an engine estimate, not physical VRAM residency."
	return result

func reset_samples() -> void:
	seen_frames = 90
	samples = 0
	elapsed = 0
	longest_frame = 0
	lowest_reported_fps = INF
	draw_sum = 0
	draw_max = 0
	primitive_sum = 0
	texture_max_bytes = 0
	video_max_bytes = 0
