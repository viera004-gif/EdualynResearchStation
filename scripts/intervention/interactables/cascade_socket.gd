extends "res://scripts/interaction/module_socket.gd"
func prompt() -> String:
	if bay.player.held != null and bay.player.held.has_method("scan"):
		return "interaction.scan_coupling"
	if bay.player.held != null:
		return "interaction.couple"
	return "interaction.power_socket" if accepts_module else "interaction.service_socket"
func scan_status() -> String:
	return "diagnostic.upstream_lock" if not bay.upstream_ready() else ("diagnostic.coupling_active" if locked else "diagnostic.interface_ready")
func attempt(player: Node) -> void:
	if player.held == null or player.held.has_method("scan") or locked:
		return
	bay.placement_attempt(interaction_id)
	if not accepts_module:
		reject("incompatible_interface")
	elif not bay.upstream_ready():
		reject("upstream_system_not_ready")
	elif player.held.orientation_step != 1:
		reject("key_orientation")
	else:
		var module = player.held
		player.held = null
		module.lock_to(self)
		lock_visuals()
		bay.placement_valid(interaction_id)
func reject(reason: String) -> void:
	super.reject(reason)
	bay.register_failure()
	# Mechanical kickback leaves the carried object available for immediate recovery.
	var held = bay.player.held
	var tween := create_tween()
	tween.tween_property(held, "position:z", .12, .1)
	tween.tween_property(held, "position:z", 0.0, .25)
	if reason == "upstream_system_not_ready":
		bay.pulse_route("RelayRoute", Color(.7, .22, .025), .55)
