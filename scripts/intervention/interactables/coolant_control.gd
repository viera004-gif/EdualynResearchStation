extends "res://scripts/interaction/interactable.gd"
var kind := "primary"
var value := 0
var moving := false
var mechanism: Node3D
var base_y := 0.0
var screen: Label3D
func _ready() -> void:
	bounds = Vector3(.74, 1.08, .65)
	bounds_offset = Vector3(0, 1.35, .22)
	super._ready()
	mechanism = find_child({"primary": "ValveWheel", "regulator": "RegulatorSlide", "bypass": "BypassLever"}[kind], true, false)
	base_y = mechanism.position.y
	apply_position()
	screen = Label3D.new()
	screen.position = Vector3(0, 1.98, .13)
	screen.font_size = 28
	screen.pixel_size = .00125
	add_child(screen)
	show_message("coolant.name." + kind)
func show_message(key: String, values: Dictionary = {}) -> void:
	bay.localization.bind_label(screen, key, values)
func apply_position() -> void:
	if kind == "regulator":
		mechanism.position.y = base_y + (value - 1.5) * .06
	else:
		mechanism.rotation.z = value * (PI / 4 if kind == "primary" else PI / 6)
func prompt() -> String:
	if bay.phase >= bay.Phase.MACHINE_STARTUP:
		return "coolant.controls_locked"
	return "coolant.control_settling" if moving else "coolant.adjust_prompt"
func scan_status() -> String:
	return bay.diagnostic_for(kind)
func interact(_player: Node) -> void:
	adjust(1)
func adjust(direction: int) -> void:
	if moving or bay.phase >= bay.Phase.MACHINE_STARTUP or bay.active_control != null:
		return
	var next := clampi(value + direction, 0, 3)
	var action: Dictionary = bay.begin_adjustment(self, next, direction)
	moving = true
	bay.active_control = self
	bay.audio.play_cue("valve", global_position)
	var tween := create_tween()
	if next == value:
		var axis := "position:y" if kind == "regulator" else "rotation:z"
		var start: float = mechanism.position.y if kind == "regulator" else mechanism.rotation.z
		tween.tween_property(mechanism, axis, start + .025, .10)
		tween.tween_property(mechanism, axis, start, .18)
	else:
		if kind == "regulator":
			tween.tween_property(mechanism, "position:y", base_y + (next - 1.5) * .06, .32)
		else:
			tween.tween_property(mechanism, "rotation:z", next * (PI / 4 if kind == "primary" else PI / 6), .32)
	tween.tween_callback(func():
		moving = false
		bay.active_control = null
		bay.finish_adjustment(self, next, action)
		value = next)
