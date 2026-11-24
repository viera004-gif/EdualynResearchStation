extends "res://scripts/interaction/interactable.gd"
var screen: Label3D
var lever: Node3D
var moving := false
var status_key := ""
func _ready() -> void:
	bounds = Vector3(.64, 1.15, .68)
	bounds_offset = Vector3(0, 1.35, .25)
	super._ready()
	lever = find_child("RouteTestLever", true, false)
	var grip := find_child("RouteTestGrip", true, false) as MeshInstance3D
	grip.scale *= Vector3(1.26, 1.2, 1.2)
	bay.tint_indicator(grip, "RouteTestGrip", Color(.63, .43, .20))
	screen = Label3D.new()
	screen.position = Vector3(0, 2.02, .13)
	screen.font_size = 32
	screen.pixel_size = .00155
	add_child(screen)
	set_status("polarity.source_ready")
func show_message(_key: String, _values: Dictionary = {}) -> void:
	# Inspection reports the diagnostic without replacing the physical verdict.
	pass
func set_status(key: String) -> void:
	status_key = key
	bay.localization.bind_label(screen, key)
func prompt() -> String:
	return "polarity.test_locked" if bay.route_ready else "polarity.test_prompt"
func scan_status() -> String:
	if bay.route_ready:
		return "polarity.scan_test_live"
	if bay.route_transfer == "STANDBY_READY":
		return "polarity.scan_test_standby"
	if bay.test_stale or bay.last_test.is_empty():
		return "polarity.scan_test_pending"
	return "polarity.scan_test_a" if bay.last_test.failure_location == "RELAY_A" else "polarity.scan_test_b"
func interact(_player: Node) -> void:
	bay.test_route()
func reject(reason: String) -> void:
	moving = true
	set_status("polarity.failure." + reason)
	bay.audio.play_cue("relay_reject", global_position)
	bay.tint_indicator(self, "TestStatusIndicator", Color(.9, .25, .025))
	var tween := create_tween()
	tween.tween_property(lever, "rotation:z", -.37, .15)
	tween.tween_property(lever, "rotation:z", 0.0, .3)
	tween.tween_callback(func(): moving = false)
func engage() -> void:
	set_status("polarity.route_stable")
	bay.audio.play_cue("relay_engage", global_position)
	bay.tint_indicator(self, "TestStatusIndicator", Color(.08, .65, .8))
	create_tween().tween_property(lever, "rotation:z", -PI / 3, .35)
