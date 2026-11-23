extends "res://scripts/intervention/interactables/cascade_terminal.gd"
func _ready() -> void:
	super._ready()
	bay.program.progression_changed.connect(refresh)
func refresh() -> void:
	var status := "program.available" if bay.program.available("MB02") else "program.locked"
	if "MB02" in bay.program.completed:
		status = "program.complete"
	var third := "program.available" if bay.program.available("MB03") else "program.locked"
	if "MB03" in bay.program.completed:
		third = "program.complete"
	bay.localization.bind_label(screen, "program.console_three", {
		"m1": {"key": "program.complete" if "MB01" in bay.program.completed else "program.available"},
		"m2": {"key": status}, "m3": {"key": third}})
func prompt() -> String:
	if bay.definition.data.slot == "MB02":
		return "program.enter_mb03" if bay.program.available("MB03") else "program.return_mb01"
	if bay.definition.data.slot == "MB03":
		return "program.return_mb01"
	return "program.enter_mb02" if bay.program.available("MB02") else "program.unlock_hint"
func interact(_player: Node) -> void:
	var slot := "MB02"
	if bay.definition.data.slot == "MB02":
		slot = "MB03" if bay.program.available("MB03") else "MB01"
	elif bay.definition.data.slot == "MB03":
		slot = "MB01"
	bay.program.enter(slot, bay)
