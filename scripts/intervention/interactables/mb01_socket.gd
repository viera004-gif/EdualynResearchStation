extends "res://scripts/intervention/interactables/cascade_socket.gd"
func prompt() -> String:
	if bay.player.held == bay.module:
		return "mb01.interaction.couple"
	return super.prompt()
