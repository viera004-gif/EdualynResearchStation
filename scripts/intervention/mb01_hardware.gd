extends Node3D

const Block := preload("res://scripts/intervention/interactables/mb01_module.gd")
const Socket := preload("res://scripts/intervention/interactables/mb01_socket.gd")
const ENTRY_TINT := Color(.32, .62, .48)
const KEY_TINT := Color(.56, .51, .73)
const PRIMARY_TINT := Color(.73, .54, .25)

var bay: Node
var frame := finish(Color(.19, .23, .27))
var rim := finish(Color(.36, .43, .50))
var inset := finish(Color(.07, .095, .12))
var entry_latch: MeshInstance3D
var flywheel: Node3D
var pump_rotor: Node3D
var contactor: MeshInstance3D
var entry_lamp: StandardMaterial3D
var key_lamp: StandardMaterial3D
var service_contact: StandardMaterial3D
var carrier_contact: StandardMaterial3D
var input_contact_faces: Array[MeshInstance3D] = []
var pump_speed := 0.0
var wheel_speed := 0.0

func build(world: Node) -> void:
	bay = world
	var entry_at := Vector3(1.34, 1.03, 2.13)
	var entry_socket_at := Vector3(2.51, 1.04, -.26)
	var key_socket_at := Vector3(3.53, 1.05, -2.69)
	pedestal(entry_at, Vector3(.88, .10, .64))
	pedestal(entry_socket_at, Vector3(.94, .14, .80))
	pedestal(key_socket_at, Vector3(.90, .14, .81))
	make_block(bay.ENTRY_BLOCK, entry_at, ENTRY_TINT, false)
	make_block(bay.KEY_BLOCK, Vector3(-2.19, 1.08, .27), KEY_TINT, true)
	var entry_socket := make_socket(bay.ENTRY_BLOCK, "SERVICE_CRADLE_01", entry_socket_at, ENTRY_TINT, -1)
	var key_socket := make_socket(bay.KEY_BLOCK, "CONTACT_CARRIER_02", key_socket_at, KEY_TINT, 1)
	entry_latch = box(entry_socket, Vector3(0, .23, -.29), Vector3(.52, .09, .10), rim)
	entry_lamp = finish(ENTRY_TINT.darkened(.72))
	box(entry_socket, Vector3(0, .12, .41), Vector3(.20, .03, .024), entry_lamp)
	key_lamp = finish(KEY_TINT.darkened(.72))
	box(key_socket, Vector3(0, .12, .41), Vector3(.24, .03, .024), key_lamp)
	flywheel = rotor(Vector3(3.55, 1.56, -3.66), .54, KEY_TINT)
	pump_rotor = rotor(Vector3(-1.88, .55, -3.61), .30, Color(.22, .47, .57))
	box(self, Vector3(.42, .60, -3.57), Vector3(.42, .54, .21), frame)
	contactor = box(self, Vector3(.42, .69, -3.43), Vector3(.27, .13, .09), rim)
	primary_markings()
	batch_stationary_housings()

func batch_stationary_housings() -> void:
	var surfaces := {}
	for child in get_children():
		if not child is MeshInstance3D or child == contactor or child in input_contact_faces:
			continue
		var surface: Material = child.material_override
		if not surfaces.has(surface):
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builder.set_material(surface)
			surfaces[surface] = builder
		surfaces[surface].append_from(child.mesh, 0, child.transform)
		child.queue_free()
	var mesh := ArrayMesh.new()
	for builder in surfaces.values():
		builder.commit(mesh)
	var housing := MeshInstance3D.new()
	housing.mesh = mesh
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(housing)

func primary_markings() -> void:
	var socket = bay.correct_socket
	socket.block_id = bay.PRIMARY_BLOCK
	socket.key_step = 1
	socket.approach_color = PRIMARY_TINT
	box(bay.module, Vector3(.03, .287, .05), Vector3(.24, .012, .026), finish(PRIMARY_TINT))
	box(socket, Vector3(-.29, .165, .065), Vector3(.022, .014, .24), finish(PRIMARY_TINT)).name = "PowerInputLip"
	# The off-centre contact tab lines up with a gap when turned into the receiver.
	socket.find_child("DockRearStop", true, false).hide()
	box(socket, Vector3(-.23, .185, -.27), Vector3(.12, .14, .07), rim).name = "KeyContactLeft"
	box(socket, Vector3(.14, .185, -.27), Vector3(.30, .14, .07), rim).name = "KeyContactRight"
	service_contact = finish(ENTRY_TINT.darkened(.6))
	carrier_contact = finish(KEY_TINT.darkened(.6))
	for index in range(2):
		var at := Vector3(1.09 + .30 * index, .72, -1.99)
		box(self, at, Vector3(.24, .12, .035), inset)
		input_contact_faces.append(box(self, at + Vector3(0, 0, .025), Vector3(.16, .04, .022),
			service_contact if index == 0 else carrier_contact))

func open_contact_faces() -> Array:
	var faces := []
	if not bay.service_seated:
		faces.append(input_contact_faces[0])
	if not bay.contact_seated:
		faces.append(input_contact_faces[1])
	return faces

func make_block(id: String, at: Vector3, color: Color, keyed: bool) -> void:
	var block := Block.new()
	block.name = id
	block.interaction_id = id
	block.bay = bay
	block.keyed = keyed
	block.pickup_key = "mb01.block.lift_keyed" if keyed else "mb01.block.lift_entry"
	block.position = at
	var stripe := finish(color)
	var dimensions := Vector3(.47, .21, .32) if keyed else Vector3(.36, .23, .36)
	box(block, Vector3(0, .144, 0), dimensions, frame)
	box(block, Vector3(0, .26, 0), Vector3(dimensions.x - .06, .038, dimensions.z - .07), stripe)
	box(block, Vector3(0, .297, 0), Vector3(.23, .038, .09), rim)
	for x in [-.095, .095]:
		box(block, Vector3(x, .044, 0), Vector3(.04, .05, .14), rim)
	if keyed:
		var tongue := box(block, Vector3(.275, .153, .084), Vector3(.14, .16, .122), stripe)
		tongue.name = "KeyTongue"
		box(tongue, Vector3(.052, .035, 0), Vector3(.03, .07, .089), rim)
	add_child(block)

func make_socket(id: String, socket_id: String, at: Vector3, color: Color, angle: int) -> Node3D:
	var socket := Socket.new()
	socket.name = socket_id
	socket.interaction_id = socket_id
	socket.bay = bay
	socket.block_id = id
	socket.key_step = angle
	socket.approach_color = color
	socket.position = at
	box(socket, Vector3(0, .036, 0), Vector3(.77, .07, .68), frame).name = "InterfaceFace"
	box(socket, Vector3(0, .078, 0), Vector3(.53, .014, .53), inset)
	for x in [-.29, .29]:
		var rail := box(socket, Vector3(x, .135, 0), Vector3(.07, .16, .57), rim)
		rail.name = "DockGuideRailLeft" if x < 0 else "DockGuideRailRight"
		box(rail, Vector3(0, .084, .02), Vector3(.044, .015, .37), finish(color))
	box(socket, Vector3(0, .092, .295), Vector3(.24, .022, .046), inset).name = "SocketIndicator"
	if angle >= 0:
		# Gap left by the offset contact tongue, with the module sitting a quarter turn across the cradle.
		var left := box(socket, Vector3(-.147, .179, -.298), Vector3(.28, .18, .072), rim)
		var right := box(socket, Vector3(.229, .179, -.298), Vector3(.13, .18, .072), rim)
		var contact_finish := finish(color.lightened(.22))
		box(left, Vector3(.13, .036, .023), Vector3(.025, .104, .042), contact_finish).name = "KeyContactLeft"
		box(right, Vector3(-.055, .036, .023), Vector3(.025, .104, .042), contact_finish).name = "KeyContactRight"
	add_child(socket)
	return socket

func pedestal(at: Vector3, deck: Vector3) -> void:
	box(self, at - Vector3(0, .095, 0), deck, frame)
	box(self, Vector3(at.x, .48, at.z), Vector3(.29, .90, .33), frame)
	box(self, Vector3(at.x, .055, at.z), Vector3(.63, .11, .53), rim)
	bay.add_static("ModulePedestal", Vector3(at.x, .49, at.z), Vector3(deck.x, .98, deck.z))

func rotor(at: Vector3, diameter: float, color: Color) -> Node3D:
	box(self, at - Vector3(0, 0, .06), Vector3(diameter, diameter, .15), frame)
	var pivot := Node3D.new()
	pivot.position = at + Vector3(0, 0, .08)
	add_child(pivot)
	for angle in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
		box(pivot, Vector3.ZERO, Vector3(.05, diameter * .81, .045), finish(color)).rotation.z = angle
	box(pivot, Vector3(0, 0, .03), Vector3(.09, .09, .045), rim)
	return pivot

func entry_engaged() -> void:
	create_tween().tween_property(entry_latch, "position:y", .16, .24)
	light(entry_lamp, ENTRY_TINT)
	light(service_contact, ENTRY_TINT)

func carrier_engaged() -> void:
	light(key_lamp, KEY_TINT)
	light(carrier_contact, KEY_TINT)
	create_tween().tween_property(self, "wheel_speed", 4.3, 1.1)
	bay.audio.play_cue("flow", flywheel.global_position)

func cooling_engaged() -> void:
	create_tween().tween_property(self, "pump_speed", 5.2, .9)

func relay_engaged() -> void:
	create_tween().tween_property(contactor, "position:y", .48, .24).set_trans(Tween.TRANS_BACK)
	bay.audio.play_cue("lock", contactor.global_position)

func sector_drive_engaged() -> void:
	var startup := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	startup.tween_property(self, "wheel_speed", 6.4, 1.35)
	startup.tween_property(service_contact, "emission_energy_multiplier", 1.3, .85)
	startup.tween_property(carrier_contact, "emission_energy_multiplier", 1.3, .85)

func _process(delta: float) -> void:
	flywheel.rotate_z(wheel_speed * delta)
	pump_rotor.rotate_z(pump_speed * delta)

func light(surface: StandardMaterial3D, color: Color) -> void:
	surface.emission_enabled = true
	surface.emission = color
	surface.emission_energy_multiplier = .7

func finish(color: Color) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.metallic = .35
	surface.roughness = .55
	return surface

func box(parent: Node3D, at: Vector3, dimensions: Vector3, surface: Material) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	model.mesh = shape
	model.material_override = surface
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.position = at
	parent.add_child(model)
	return model
