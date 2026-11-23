extends "res://scripts/interaction/interactable.gd"
var screen: Label3D
var lever: Node3D
var moving := false
func _ready() -> void:
	bounds = Vector3(.55, 1.15, .65)
	bounds_offset = Vector3(0, 1.35, .25)
	super._ready()
	lever = find_child("RouteTestLever", true, false)
	screen = Label3D.new()
	screen.position = Vector3(0, 2.02, .13)
	screen.font_size = 28
	screen.pixel_size = .00125
	add_child(screen)
	show_message("polarity.source_ready")
func show_message(key: String, values: Dictionary = {}) -> void:
	bay.localization.bind_label(screen, key, values)
func prompt() -> String:
	return "polarity.test_locked" if bay.route_ready else "polarity.test_prompt"
func scan_status() -> String:
	return "polarity.source_stable"
func interact(_player: Node) -> void:
	bay.test_route()
func reject(reason: String) -> void:
	moving = true
	show_message("polarity.failure." + reason)
	bay.audio.play_cue("relay_reject", global_position)
	bay.tint_indicator(self, "TestStatusIndicator", Color(.9, .25, .025))
	var tween := create_tween()
	tween.tween_property(lever, "rotation:z", -.18, .12)
	tween.tween_property(lever, "rotation:z", 0.0, .3)
	tween.tween_callback(func(): moving = false)
func engage() -> void:
	show_message("polarity.route_stable")
	bay.audio.play_cue("relay_engage", global_position)
	bay.tint_indicator(self, "TestStatusIndicator", Color(.08, .65, .8))
	create_tween().tween_property(lever, "rotation:z", -PI / 3, .35)
