extends SceneTree

const BootProbe := preload("res://verification/mb01_experience/playthrough.gd")
const CoolantProbe := preload("res://verification/phase2c/coolant_probe.gd")
const Program := preload("res://scripts/program/module_bay_program.gd")

class CoolantRegression extends CoolantProbe:
	func run(world: Node) -> void:
		bay = world
		if bay.language_selector.opened:
			await action("language")
		check(bay.configuration_id == "C", "MB03 known combined-fault start")
		await adjust(bay.regulator, 1)
		check(not bay.network.evidence().safe, "MB03 first correction alone insufficient")
		await adjust(bay.primary, 1)
		await pause(8.5)
		check(bay.phase == bay.Phase.COMPLETE and bay.temperature <= 45, "MB03 normal balance and completion")
		check(bay.history.help_requests == 0 and bay.player.held == null, "MB03 completes without support")
		check(bay.telemetry.pending.size() == bay.telemetry.archive.size(), "MB03 offline evidence retained")
		var restored := Program.new()
		restored.configure()
		check(restored.completed == ["MB01", "MB02", "MB03"], "schema-1 save reloads all existing completion flags")
		check(not restored.available("MB04") and not restored.available("MB05"), "MB04 and MB05 remain unavailable")
		restored.free()

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(180).timeout.connect(func(): quit(3))
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await process_frame
	await process_frame
	var boot := BootProbe.new()
	await boot.run(current_scene)
	if boot.failed or current_scene.definition.data.slot != "MB03":
		quit(1)
		return
	var coolant := CoolantRegression.new()
	await coolant.run(current_scene)
	quit(2 if coolant.failed else 0)
