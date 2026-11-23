extends "res://scripts/intervention/interactables/cascade_socket.gd"
func prompt() -> String:
	return "coolant.cooling_status"
func scan_status() -> String:
	return bay.diagnostic_for("core")
func attempt(_player: Node) -> void:
	pass
