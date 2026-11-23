extends "res://scripts/program/operations_console.gd"
func refresh() -> void:
	if bay.phase == bay.Phase.COMPLETE and not bay.exit_ready:
		bay.localization.bind_label(screen, "mb01.exit.standby")
	else:
		super.refresh()

func prompt() -> String:
	return "mb01.exit.standby" if bay.phase == bay.Phase.COMPLETE and not bay.exit_ready else super.prompt()

func interact(player: Node) -> void:
	if bay.phase != bay.Phase.COMPLETE or bay.exit_ready:
		super.interact(player)
