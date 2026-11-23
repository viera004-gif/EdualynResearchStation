extends "res://scripts/interaction/interactable.gd"
var screen: Label3D
func _ready() -> void:
	bounds = Vector3(.96, .88, .48)
	bounds_offset = Vector3(0, 1.48, 0)
	super._ready()
	screen = Label3D.new()
	screen.position = Vector3(0, 1.55, .154)
	screen.font_size = 36
	screen.pixel_size = .0018
	screen.modulate = Color(.45, .78, .88)
	screen.no_depth_test = false
	screen.text = "MODULE BAY 01\n\nPOWER COUPLING OFFLINE\n\n[F]  RESTORE SYSTEM"
	add_child(screen)
func prompt() -> String:
	return "[F]  Access mission terminal" if bay.phase == bay.Phase.PRE_MISSION else "Module Bay 01 • coupling restoration"
func interact(_player: Node) -> void:
	bay.activate_terminal()
