extends "res://scripts/intervention/interactables/cascade_socket.gd"

const CarryBlock := preload("res://scripts/intervention/interactables/mb01_module.gd")

@export var block_id := ""
var key_step := -1
var idle_color := Color(.018, .026, .035)
var approach_color := Color(.16, .56, .68)
var approach_active := false
var seating := false
var rail_rest: Dictionary = {}
var refusal: Tween
var fault_display: Label3D
var fault_pulse: Tween
var fault_surfaces: Dictionary = {}

func _ready() -> void:
	super._ready()
	if not block_id.is_empty():
		feedback_light.queue_free()
		feedback_light = null
	bounds = Vector3(.88, .48, .92)
	for child in get_children():
		if child is CollisionShape3D:
			child.shape.size = bounds
	for rail in find_children("*DockGuideRail*", "MeshInstance3D", true, false):
		rail_rest[rail] = rail.position.x
	fault_display = Label3D.new()
	fault_display.position = Vector3(0, .24, .36)
	fault_display.font_size = 32
	fault_display.pixel_size = .00165
	if block_id == bay.KEY_BLOCK:
		fault_display.position = Vector3(-.21, .055, .42)
		fault_display.pixel_size = .00135
	fault_display.outline_size = 6
	add_child(fault_display)
	fault_display.hide()

func _process(_delta: float) -> void:
	if locked or seating or fault_display.visible or bay.player == null:
		return
	var held = bay.player.held
	var nearby: bool = held != null and held.interaction_id == block_id and global_position.distance_to(held.global_position) < 2.1
	if nearby == approach_active:
		return
	approach_active = nearby
	reopen_rails(-.24 if nearby else 0.0)
	set_indicator(approach_color if nearby else idle_color, 0.0)

func prompt() -> String:
	if bay.player.held is CarryBlock and not locked and not seating:
		return "mb01.interaction.seat_keyed" if key_step >= 0 else "mb01.interaction.seat"
	if block_id == bay.PRIMARY_BLOCK or block_id.is_empty():
		return super.prompt() if bay.player.held == null else ""
	return "mb01.socket.receptacle"

func interact(player: Node) -> void:
	attempt(player)

func scan_status() -> String:
	if block_id.is_empty():
		return "mb01.coupling.service"
	if block_id == bay.PRIMARY_BLOCK:
		if bay.relay_ready and not bay.upstream_ready():
			return "mb01.coupling.contacts_open"
		if bay.cooling_ready and not bay.relay_ready:
			return "mb01.coupling.relay_open"
		return super.scan_status()
	return "diagnostic.coupling_active" if locked else "diagnostic.interface_ready"

func attempt(player: Node) -> void:
	var held = player.held
	if not held is CarryBlock or locked or seating:
		return
	held.last_socket = interaction_id
	bay.begin_action("placement", held.interaction_id, interaction_id, held.orientation_step, held.interaction_id)
	var attempt_id: String = bay.block_event("placement_attempt", held, interaction_id)
	if held.interaction_id != block_id:
		reject_block(held, attempt_id, "incompatible_interface")
	elif block_id == bay.PRIMARY_BLOCK and not bay.upstream_ready():
		var reason := "upstream_system_not_ready"
		if bay.relay_ready:
			reason = "open_auxiliary_contacts"
		elif bay.cooling_ready:
			reason = "relay_not_ready"
		reject_block(held, attempt_id, reason)
	elif key_step >= 0 and held.orientation_step != key_step:
		reject_block(held, attempt_id, "key_orientation")
	else:
		seating = true
		stop_feedback()
		reset_refusal()
		fault_display.hide()
		player.held = null
		await held.seat(self, held.orientation_step)
		lock_visuals()
		seating = false
		bay.block_event("placement_valid", held, interaction_id, {"attempt_uuid": attempt_id})
		bay.block_seated(block_id)

func reject_block(held: Node, attempt_id: String, reason: String) -> void:
	stop_feedback()
	reset_refusal()
	var context: Dictionary = bay.placement_rejection_context(held, interaction_id, reason)
	context["attempt_uuid"] = attempt_id
	bay.block_event("placement_invalid", held, interaction_id, context)
	bay.register_failure()
	var repeated: bool = context.fault_emphasis
	var tint: Color
	var cue: String
	var display_key: String
	match reason:
		"upstream_system_not_ready":
			tint = Color(.92, .42, .07)
			cue = "relay_reject"
			display_key = "mb01.coupling.no_input"
			bay.pulse_route("RelayRoute", tint, 2.6 if repeated else 2.0)
			if repeated:
				pulse_feature([find_child("PowerInputLip", true, false)], tint, .85)
		"relay_not_ready":
			tint = Color(.92, .56, .18)
			cue = "relay_reject"
			display_key = "mb01.coupling.relay_open"
			pulse_feature([bay.hardware.contactor], tint, .85 if repeated else .38)
		"open_auxiliary_contacts":
			tint = Color(.71, .49, .84)
			cue = "trace"
			display_key = "mb01.coupling.contacts_open"
			pulse_feature(bay.hardware.open_contact_faces(), tint, .85 if repeated else .38)
		"incompatible_interface":
			tint = Color(.94, .18, .08)
			cue = "invalid"
			display_key = "mb01.coupling.service" if block_id.is_empty() else "mb01.coupling.incompatible"
			if repeated:
				pulse_feature([find_child("InterfaceFace", true, false) if has_node("InterfaceFace")
					else find_child("SocketMount", true, false)], tint, .72)
		"key_orientation":
			tint = Color(.20, .68, .92)
			cue = "alignment_refusal"
			display_key = "mb01.coupling.misaligned"
			refusal = create_tween().set_parallel()
			for rail in rail_rest:
				var rest: float = rail_rest[rail]
				refusal.tween_property(rail, "position:x", rest - signf(rest) * .045, .12)
			refusal.chain().tween_interval(.08)
			refusal.chain().tween_method(reopen_rails, 1.0, 0.0, .20)
			if repeated:
				var features := find_children("KeyContact*", "MeshInstance3D", true, false)
				features.append(held.find_child("KeyTongue" if block_id == bay.KEY_BLOCK else "AsymmetricKeyTab", true, false))
				pulse_feature(features, tint, .85)
	bay.audio.play_cue(cue, global_position)
	set_indicator(tint, .34)
	fault_display.modulate = tint.lightened(.36)
	bay.localization.bind_label(fault_display, display_key)
	fault_display.show()
	feedback_tween = create_tween()
	if feedback_light == null:
		feedback_tween.tween_interval(2.6)
	else:
		feedback_tween.tween_property(feedback_light, "light_energy", 0.0, 2.6)
	feedback_tween.tween_callback(clear_fault)

func pulse_feature(features: Array, color: Color, strength: float) -> void:
	fault_pulse = create_tween().set_parallel()
	for feature in features:
		if not feature is MeshInstance3D:
			continue
		var surface := feature.get_active_material(0).duplicate() as StandardMaterial3D
		fault_surfaces[feature] = feature.material_override
		feature.material_override = surface
		surface.emission_enabled = true
		surface.emission = color
		surface.emission_energy_multiplier = strength
		fault_pulse.tween_property(surface, "emission_energy_multiplier", 0.0, 1.15)
	if fault_surfaces.is_empty():
		fault_pulse.kill()
	else:
		fault_pulse.finished.connect(clear_feature)

func clear_feature() -> void:
	for feature in fault_surfaces:
		if is_instance_valid(feature):
			feature.material_override = fault_surfaces[feature]
	fault_surfaces.clear()

func set_indicator(color: Color, energy: float) -> void:
	if feedback_light == null:
		bay.tint_indicator(self, "SocketIndicator", color)
	else:
		super.set_indicator(color, energy)

func reopen_rails(amount: float) -> void:
	for rail in rail_rest:
		var rest: float = rail_rest[rail]
		rail.position.x = rest - signf(rest) * .045 * amount

func clear_fault() -> void:
	fault_display.hide()
	set_indicator(idle_color, 0.0)

func reset_refusal() -> void:
	if refusal != null:
		refusal.kill()
	if fault_pulse != null:
		fault_pulse.kill()
	clear_feature()
	approach_active = false
	reopen_rails(0.0)

func lock_visuals() -> void:
	reset_refusal()
	fault_display.hide()
	super.lock_visuals()
