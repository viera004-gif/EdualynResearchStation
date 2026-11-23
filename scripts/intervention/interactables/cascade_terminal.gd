extends "res://scripts/interaction/mission_terminal.gd"
func _ready() -> void:
	super._ready()
	refresh()
func refresh() -> void:
	var prefix: String = "mission." + bay.definition.data.text_namespace
	var key := prefix + ".terminal_offline"
	if bay.phase == bay.Phase.COMPLETE:
		key = prefix + ".terminal_complete"
	elif bay.phase != bay.Phase.PRE_MISSION:
		key = prefix + ".terminal_active"
	bay.localization.bind_label(screen, key)
func prompt() -> String:
	return "interaction.terminal"
