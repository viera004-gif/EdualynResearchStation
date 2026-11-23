extends "res://scripts/machine/repair_machine.gd"
func prompt() -> String:
	return "machine." + ["offline", "startup", "active"][state]
func scan_status() -> String:
	return "diagnostic.core_active" if state == State.ACTIVE else "diagnostic.core_interlock"
