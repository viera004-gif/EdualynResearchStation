extends "res://scripts/intervention/interactables/cascade_machine.gd"
func prompt() -> String:
	return "coolant.cooling_status" if state == State.OFFLINE else super.prompt()
func scan_status() -> String:
	return bay.diagnostic_for("core")
