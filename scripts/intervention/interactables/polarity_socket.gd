extends "res://scripts/intervention/interactables/cascade_socket.gd"
func prompt() -> String:
	return "interaction.scan_coupling" if bay.player.held == bay.scanner else "polarity.coupler_prompt"
func scan_status() -> String:
	return "polarity.coupler_stable" if bay.route_ready else "polarity.coupler_unstable"
func attempt(_player: Node) -> void:
	pass
