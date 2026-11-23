extends "res://scripts/interaction/interactable.gd"
var kind := "source"
var needle: Node3D
var screen: Label3D
var title: Label3D
func _ready() -> void:
	bounds = Vector3(.52, .52, .3) if kind != "core" else Vector3(.8, 1.9, .7)
	bounds_offset = Vector3.ZERO if kind != "core" else Vector3(0, 1.0, 0)
	super._ready()
	needle = find_child("GaugeNeedle", true, false)
	if needle != null:
		# Millimeter-scale moving needles do not need to invalidate the room's
		# task-light shadow atlas. The modeled housing retains normal shadows.
		for mesh in needle.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen = Label3D.new()
	screen.position = Vector3(0, -.28, .10) if kind != "core" else Vector3(0, 1.65, .39)
	screen.font_size = 28
	screen.pixel_size = .001 if kind != "core" else .00125
	add_child(screen)
	title = Label3D.new()
	title.position = Vector3(0, .30, .1) if kind != "core" else Vector3(0, 2.05, .2)
	title.font_size = 28
	title.pixel_size = .00125
	add_child(title)
	bay.localization.bind_label(title, "coolant.name." + kind)
func prompt() -> String:
	return "coolant.instrument_prompt"
func scan_status() -> String:
	return bay.diagnostic_for(kind)
func show_message(_key: String, _values: Dictionary = {}) -> void:
	# Inspection never replaces the live numeric instrument with a static explanation.
	pass
func interact(_player: Node) -> void:
	bay.inspect_subsystem(self)
func update_reading(pressure_bar: float, temperature: float) -> void:
	if needle != null:
		needle.rotation.z = lerpf(2.35, -2.35, clampf(pressure_bar / 6.0, 0.0, 1.0))
	if kind == "core":
		bay.localization.bind_label(screen, "coolant.temperature", {"value": int(temperature)})
	else:
		bay.localization.bind_label(screen, "coolant.pressure_value", {"value": String.num(pressure_bar, 1)})
