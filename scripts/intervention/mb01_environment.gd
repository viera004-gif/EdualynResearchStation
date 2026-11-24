extends Node3D
## MB01-only geometry, animated station fixtures, and physical airlock.
const SPAWN := Vector3(0, .04, 26)
const THRESHOLD := 3.8
const DOOR_Z := 4.48
const DOOR_WIDTH := 1.9
const CORRIDOR_END := 27.5
const SERVICE_POSITION := Vector3(1.37, 1.52, 22.0)

class VentilationPanel extends "res://scripts/interaction/interactable.gd":
	var environment: Node3D

	func prompt() -> String:
		return "mb01.vent.check"

	func interact(_player: Node) -> void:
		environment.check_ventilation()

var bay: Node
var door_open := false
var door_leaves: Array[Node3D] = []
var door_barrier: CollisionShape3D
var dock_material: StandardMaterial3D
var fan: Node3D
var fan_speed := .58
var display_material: StandardMaterial3D
var display_segments: Array[MeshInstance3D] = []
var display_step := 0
var display_clock := 0.0
var machine_status: Label3D
var ventilation: VentilationPanel
var vent_screen: Label3D
var bay_vent_status: Label3D
var vent_signal: StandardMaterial3D
var vent_online := false
var shell := material(Color(.16, .19, .22))
var trim := material(Color(.27, .32, .36))
var inset := material(Color(.09, .115, .135))
var lamp := material(Color(.47, .64, .76), .85)

func material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = .82
	if emission > 0:
		surface.emission_enabled = true
		surface.emission = color
		surface.emission_energy_multiplier = emission
	return surface

func box(parent: Node3D, at: Vector3, dimensions: Vector3, surface: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = dimensions
	var model := MeshInstance3D.new()
	model.mesh = shape
	model.material_override = surface
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.position = at
	parent.add_child(model)
	return model

func collision(id: String, at: Vector3, dimensions: Vector3) -> void:
	bay.add_static(id, at, dimensions)

func build(world: Node) -> void:
	bay = world
	build_corridor()
	build_airlock()
	build_fixtures()
	build_ventilation_panel()

func build_corridor() -> void:
	# Each section has one surface per finish, so repeating trim stays cheap to draw.
	var cube := BoxMesh.new()
	var length := (CORRIDOR_END - DOOR_Z) / 2.0
	for section in range(2):
		var surfaces: Array[SurfaceTool] = []
		for finish in [shell, trim, inset, lamp]:
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(finish)
			surfaces.append(surface)
		var start := DOOR_Z + section * length
		var middle := start + length / 2.0
		append_box(surfaces[0], cube, Vector3(0, -.12, middle), Vector3(3.3, .24, length))
		append_box(surfaces[0], cube, Vector3(0, 3.12, middle), Vector3(3.3, .24, length))
		for side in [-1, 1]:
			append_box(surfaces[0], cube, Vector3(side * 1.65, 1.5, middle), Vector3(.2, 3, length))
			append_box(surfaces[1], cube, Vector3(side * 1.51, .24, middle), Vector3(.10, .27, length))
			append_box(surfaces[2], cube, Vector3(side * 1.53, 1.26, middle), Vector3(.085, .75, length))
			for index in range(3):
				var z := start + (index + .5) * length / 3.0
				append_box(surfaces[1], cube, Vector3(side * 1.49, 1.53, z), Vector3(.16, 3.02, .15))
				append_box(surfaces[3], cube, Vector3(side * 1.51, 2.67, z + .72), Vector3(.055, .10, 1.15))
				append_box(surfaces[2], cube, Vector3(side * .99, .002, z), Vector3(.12, .01, length / 3.0))
		for index in range(3):
			var z := start + (index + .5) * length / 3.0
			append_box(surfaces[1], cube, Vector3(0, 2.94, z), Vector3(3.16, .18, .15))
		if section == 0:
			var side := -1.0
			var cabinet := Vector3(side * 1.48, 1.55, middle + 2.8)
			append_box(surfaces[1], cube, cabinet, Vector3(.16, 1.31, 1.82))
			append_box(surfaces[2], cube, cabinet - Vector3(side * .092, 0, 0), Vector3(.035, 1.12, 1.62))
			for index in range(4):
				var vent := cabinet - Vector3(side * .113, .35 - .065 * index, 0)
				append_box(surfaces[1], cube, vent, Vector3(.026, .021, 1.32))
			for index in range(2):
				var signal_at := cabinet - Vector3(side * .113, -.38, .56 - .11 * index)
				append_box(surfaces[3], cube, signal_at, Vector3(.025, .024, .046))
		var mesh := ArrayMesh.new()
		for surface in surfaces:
			surface.commit(mesh)
		var batch := MeshInstance3D.new()
		batch.mesh = mesh
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		var spill := OmniLight3D.new()
		spill.position = Vector3(0, 2.72, middle)
		spill.light_color = Color(.72, .83, .96)
		spill.light_energy = 1.15
		spill.omni_range = 8.1
		spill.omni_attenuation = 1.3
		add_child(spill)
	var total := CORRIDOR_END - DOOR_Z
	var center := (CORRIDOR_END + DOOR_Z) / 2
	collision("EntryDeck", Vector3(0, -.12, center), Vector3(3.3, .24, total))
	for side in [-1, 1]:
		collision("EntrySide", Vector3(side * 1.65, 1.5, center), Vector3(.2, 3, total))
	box(self, Vector3(0, 1.5, CORRIDOR_END), Vector3(3.3, 3, .23), trim)
	collision("EntryEnd", Vector3(0, 1.5, CORRIDOR_END), Vector3(3.3, 3, .23))

func append_box(surface: SurfaceTool, cube: BoxMesh, at: Vector3, dimensions: Vector3) -> void:
	surface.append_from(cube, 0, Transform3D(Basis.from_scale(dimensions), at))

func build_airlock() -> void:
	var room := bay.get_node("ModuleRoom")
	# Clear only the positive-Z end-wall infill behind the imported airlock.
	for mesh in room.find_children("*", "MeshInstance3D", true, false):
		var at: Vector3 = mesh.global_position
		if at.z > 4.27 and absf(at.x) < 1.1 and (
				mesh.name.begins_with("EndWall") or mesh.name.begins_with("PanelLowerInset")):
			mesh.hide()
	for side in [-1, 1]:
		var wall_at := Vector3(side * 2.725, 1.95, DOOR_Z)
		box(self, wall_at, Vector3(3.55, 3.9, .20), shell)
		collision("BayEndWall", wall_at, Vector3(3.55, 3.9, .20))
		var pocket := Node3D.new()
		add_child(pocket)
		door_leaves.append(pocket)
		for marker in ["AirlockLeaf", "AirlockRecess", "AirlockVisionGlass", "AirlockHandle"]:
			var leaf := room.find_child(marker if side == -1 else marker + "_001", true, false) as Node3D
			if leaf == null and side == 1:
				leaf = room.find_child(marker + ".001", true, false) as Node3D
			assert(leaf != null, marker)
			leaf.reparent(pocket)
			leaf.position.z += DOOR_Z - 4.1
		box(pocket, Vector3(side * .46, 1.64, DOOR_Z + .055), Vector3(.72, .64, .025), trim)
		box(pocket, Vector3(side * .46, 1.64, DOOR_Z + .074), Vector3(.60, .46, .016), inset)
		box(pocket, Vector3(side * .054, 1.44, DOOR_Z + .055), Vector3(.11, 2.67, .042), inset)
	var frame := room.find_child("AirlockFrame", true, false) as Node3D
	# The original frame is a solid surround behind decorative leaves.
	frame.hide()
	room.find_child("AirlockStatusBar", true, false).hide()
	for side in [-1, 1]:
		box(self, Vector3(side * 1.045, 1.44, DOOR_Z), Vector3(.19, 2.88, .47), trim)
	box(self, Vector3(0, 3.39, DOOR_Z), Vector3(DOOR_WIDTH, 1.02, .25), shell)
	box(self, Vector3(0, 2.84, DOOR_Z), Vector3(2.27, .18, .48), trim)
	box(self, Vector3(0, 2.74, DOOR_Z + .25), Vector3(1.68, .032, .024), lamp)
	box(self, Vector3(0, 2.43, DOOR_Z + .30), Vector3(1.85, .49, .055), inset)
	var inside_cover := box(self, Vector3(0, 2.95, DOOR_Z - .32), Vector3(2.2, .22, .095), trim)
	inside_cover.name = "AirlockMotorCover"
	var marker := sign_3d("mb01.door", Vector3(0, 2.44, DOOR_Z + .34), .00245)
	marker.modulate = Color(.73, .83, .89)
	var barrier := StaticBody3D.new()
	barrier.position = Vector3(0, 1.35, DOOR_Z)
	var shape := BoxShape3D.new()
	shape.size = Vector3(DOOR_WIDTH, 2.7, .16)
	door_barrier = CollisionShape3D.new()
	door_barrier.shape = shape
	barrier.add_child(door_barrier)
	add_child(barrier)

func sign_3d(key: String, at: Vector3, pixel_size: float) -> Label3D:
	var label := Label3D.new()
	label.position = at
	label.font_size = 36
	label.pixel_size = pixel_size
	label.outline_size = 0
	label.modulate = Color(.56, .74, .83)
	add_child(label)
	bay.localization.bind_label(label, key)
	return label

func open_airlock() -> void:
	if door_open:
		return
	door_open = true
	bay.audio.play_cue("relay_engage", Vector3(0, 1.5, DOOR_Z))
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_property(door_leaves[0], "position:x", -1.02, .82)
	tween.tween_property(door_leaves[1], "position:x", 1.02, .82)
	tween.chain().tween_callback(func(): door_barrier.disabled = true)

func build_ventilation_panel() -> void:
	ventilation = VentilationPanel.new()
	ventilation.environment = self
	ventilation.position = SERVICE_POSITION
	ventilation.bounds = Vector3(.19, .50, .99)
	add_child(ventilation)
	box(ventilation, Vector3.ZERO, Vector3(.15, .48, .98), trim)
	box(ventilation, Vector3(-.084, .03, 0), Vector3(.025, .31, .85), inset)
	vent_signal = material(Color(.70, .27, .06), .58)
	box(ventilation, Vector3(-.10, -.157, 0), Vector3(.019, .024, .68), vent_signal)
	vent_screen = sign_3d("mb01.vent.reserve", SERVICE_POSITION + Vector3(-.109, .035, 0), .00185)
	vent_screen.rotation.y = -PI / 2.0
	vent_screen.modulate = Color(.93, .63, .35)

func check_ventilation() -> void:
	bay.localization.bind_label(vent_screen, "mb01.vent.online" if vent_online else "mb01.vent.limited")
	bay.audio.play_cue("terminal", ventilation.global_position)

func build_fixtures() -> void:
	# Vent and status display are environmental props with no physics or gameplay state.
	box(self, Vector3(3.54, 2.64, -4.24), Vector3(1.08, 1.05, .16), trim)
	box(self, Vector3(3.54, 2.64, -4.15), Vector3(.89, .87, .05), inset)
	fan = Node3D.new()
	fan.position = Vector3(3.54, 2.64, -4.095)
	add_child(fan)
	for index in range(5):
		var root := Node3D.new()
		root.rotation.z = TAU * index / 5.0
		fan.add_child(root)
		box(root, Vector3(0, .235, 0), Vector3(.105, .30, .04), trim).rotation.z = -.26
	box(self, Vector3(3.54, 2.64, -4.06), Vector3(.16, .16, .08), shell)
	for index in range(3):
		box(self, Vector3(3.54, 2.43 + .21 * index, -3.98), Vector3(.92, .018, .035), shell)
	bay_vent_status = sign_3d("mb01.vent.reserve", Vector3(3.54, 1.98, -4.15), .00165)
	bay_vent_status.modulate = Color(.93, .63, .35)
	box(self, Vector3(-2.8, 2.48, -4.26), Vector3(1.53, .72, .12), trim)
	box(self, Vector3(-2.8, 2.48, -4.19), Vector3(1.45, .64, .055), inset)
	machine_status = sign_3d("mb01.status.offline", Vector3(-2.8, 2.56, -4.152), .00173)
	display_material = material(Color(.27, .47, .60), .65)
	for index in range(7):
		var segment := box(self, Vector3(-3.30 + .167 * index, 2.27, -4.15), Vector3(.126, .024, .021), inset)
		display_segments.append(segment)
	dock_material = material(Color(.22, .36, .43), .14)
	box(self, Vector3(-3.20, 1.03, 1.79), Vector3(.29, .035, .02), dock_material)

func wake_scanner_dock() -> void:
	create_tween().tween_property(dock_material, "emission_energy_multiplier", .95, .55)
	bay.audio.play_cue("station_wake", Vector3(-3.2, 1.12, 1.5))

func settle_scanner_dock() -> void:
	create_tween().tween_property(dock_material, "emission_energy_multiplier", .14, .35)

func restore_room() -> void:
	vent_online = true
	vent_signal.emission = Color(.12, .70, .83)
	vent_signal.albedo_color = vent_signal.emission
	for label in [vent_screen, bay_vent_status]:
		bay.localization.bind_label(label, "mb01.vent.online")
		label.modulate = Color(.48, .86, .95)
	bay.localization.bind_label(machine_status, "mb01.status.operational")
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	for node in bay.get_children():
		if node is OmniLight3D and node.position.y > 3.0:
			tween.tween_property(node, "light_color", Color(.70, .89, 1), 1.3)
			tween.tween_property(node, "light_energy", 3.25, 1.3)
	tween.tween_property(self, "fan_speed", 3.1, 2.1)
	tween.tween_property(display_material, "emission_energy_multiplier", 1.45, 1.3)
	bay.audio.play_cue("flow", fan.global_position)

func _process(delta: float) -> void:
	if fan == null:
		return
	fan.rotate_z(fan_speed * delta)
	display_clock += delta
	if display_clock >= .32:
		display_clock = 0
		display_segments[display_step].material_override = inset
		display_step = (display_step + 1) % display_segments.size()
		display_segments[display_step].material_override = display_material
