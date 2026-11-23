from pathlib import Path
import re
p=Path('scripts/intervention/power_coupling_cascade.gd')
original=p.read_text(encoding='utf-8')
def method(source,name):
    start=source.index('func '+name+'(')
    end=source.find('\nfunc ',start+1)
    return source[start:] if end<0 else source[start:end+1]
def replace(source,name,value):return source.replace(method(source,name),value+'\n')
base=original
for field in ['var cooling_ready := false\n','var relay_ready := false\n','var cooling\n','var relay\n']:
    base=base.replace(field,'')
base=base.replace('var config: Dictionary','var definition: RefCounted\nvar program: Node\nvar operations_console\nvar config: Dictionary')
ready=method(base,'_ready')
ready=ready.replace('func _ready() -> void:\n','''func definition_path() -> String:
\treturn "res://config/missions/mb01.json"
func socket_script() -> String:
\treturn "res://scripts/intervention/interactables/cascade_socket.gd"
func _ready() -> void:
\tdefinition = load("res://scripts/program/mission_definition.gd").new()
\tdefinition.read(definition_path())
\tprogram = get_node_or_null("/root/ModuleBayProgram")
\tif program == null:
\t\tprogram = load("res://scripts/program/module_bay_program.gd").new()
\t\tprogram.name = "ModuleBayProgram"
\t\tprogram.configure()
\t\tadd_child(program)
\t\tprogram.reparent.call_deferred(get_tree().root)
\tif not program.available(definition.data.slot):
\t\tget_tree().change_scene_to_file.call_deferred("res://scenes/main/power_coupling_cascade.tscn")
\t\treturn
''')
ready=ready.replace('config = JSON.parse_string(FileAccess.get_file_as_string("res://config/intervention_v02.json"))','config = definition.help_policy()')
ready=ready.replace('\ttelemetry.name =','\ttelemetry.content_id = definition.data.mission_id\n\ttelemetry.app_version = definition.data.app_version\n\ttelemetry.game_version = definition.data.version\n\ttelemetry.name =')
ready=ready.replace('"res://scripts/intervention/interactables/cascade_socket.gd", "SOCKET', 'socket_script(), "SOCKET')
ready=ready.replace('\tsetup_devices()','\tsetup_mission()')
ready=ready.replace('\tsetup_localized_engravings()','\toperations_console = make_interactable("mission_terminal", "res://scripts/program/operations_console.gd", "MODULE_BAY_OPERATIONS", Vector3(-3.5, 0, -.4))\n\tadd_static("OperationsCollision", Vector3(-3.5, .9, -.4), Vector3(.8, 1.8, .3))\n\tsetup_localized_engravings()')
probe_at=ready.index('\tif "--verify-v02"')
probes=ready[probe_at:]
ready=ready[:probe_at]+'''\tif "--verify" in OS.get_cmdline_user_args():
\t\tmetrics = load("res://scripts/verification/build_metrics.gd").new()
\t\tadd_child(metrics)
\tstart_verifier()
func start_verifier() -> void:
'''+probes
base=replace(base,'_ready',ready)
devices=method(original,'setup_devices')
tools=devices[devices.index('\tai_station ='):]
tools=tools.replace('\troutes = load("res://assets/models/intervention_v02/power_routes.glb").instantiate()\n\tadd_child(routes)\n','')
base=replace(base,'setup_devices','func setup_mission() -> void:\n\tpass\nfunc setup_tools() -> void:\n'+tools)
base=base.replace('localized_hud("mission.power_coupling.title"','localized_hud(definition.data.title_key')
base=base.replace('localized_hud("mission.power_coupling.objective"','localized_hud(definition.data.objective_key')
base=base.replace('"mission.power_coupling.complete" if phase == Phase.COMPLETE else "mission.power_coupling.objective"','definition.data.completion_key if phase == Phase.COMPLETE else definition.data.objective_key')
base=base.replace('var tutorial := "tutorial.explore"','var tutorial: String = "tutorial.explore" if definition.data.tutorial_level == "introductory" else ""')
base=base.replace('if player.held != null:\n\t\ttutorial =','if player.held != null and definition.data.tutorial_level == "introductory":\n\t\ttutorial =')
base=replace(base,'context','''func context() -> Dictionary:
\tvar value := {"content_version": definition.data.version, "session_purpose": "intervention",
\t\t"program_slot": definition.data.slot, "tutorial_level": definition.data.tutorial_level,
\t\t"scaffolding_level": definition.data.scaffolding_level,
\t\t"policy_version": config.get("policy_version", ""), "locale": localization.locale, "mission_state": stage,
\t\t"orientation": module.orientation_step if is_instance_valid(module) else -1,
\t\t"action_signature": history.last_signature.duplicate(true), "action_change": history.last_change_candidate,
\t\t"preceding_invalid_attempts": history.invalid_attempts, "exact_repeats": history.exact_repeats,
\t\t"preceding_failure_uuid": history.last_failure_uuid}
\tvalue.merge(mission_context())
\treturn value
func mission_context() -> Dictionary:
\treturn {}
''')
base=base.replace('set_stage("COOLING_UNRESOLVED")','set_stage(definition.data.initial_state)')
base=base.replace('["inspect", "scan", "regulator", "relay", "rotation"]','["inspect", "scan", "regulator", "relay", "rotation", "relay_rotation"]')
base=replace(base,'upstream_ready','func upstream_ready() -> bool:\n\treturn false')
base=base.replace('\ttelemetry.finished = true\n','\ttelemetry.finished = true\n\tprogram.complete(definition.data.slot)\n')
base=base.replace('history.exploration_actions < 2 and not cooling_ready','history.exploration_actions < int(definition.data.early_help_exploration_count) and not upstream_ready()')
a=base.index('\tvar guidance_key :=',base.index('func request_help'))
b=base.index('\tai_station.show_message',a)
base=base[:a]+'\tvar guidance_key: String = select_guidance(level, early)\n'+base[b:]
base+='\nfunc select_guidance(_level: int, _early: bool) -> String:\n\treturn ""\n'
Path('scripts/program/module_bay_mission.gd').write_text(base,encoding='utf-8')
mission='''extends "res://scripts/program/module_bay_mission.gd"
# Mission 01 rules only; shared room/tools/help/telemetry live in the program base.
var cooling_ready := false
var relay_ready := false
var cooling
var relay
func setup_mission() -> void:
\tcooling = device("cooling_regulator", "cooling", "COOLING_C01", Vector3(-1.35, 0, -3.9))
\trelay = device("auxiliary_relay", "relay", "RELAY_R02", Vector3(0, 0, -3.9))
\tsetup_tools()
\troutes = load("res://assets/models/intervention_v02/power_routes.glb").instantiate()
\tadd_child(routes)
func mission_context() -> Dictionary:
\treturn {"cooling_ready": cooling_ready, "relay_ready": relay_ready}
func upstream_ready() -> bool:
\treturn cooling_ready and relay_ready
func select_guidance(level: int, early: bool) -> String:
\tvar key := "help.level1.power_coupling.early" if early else "help.level1.power_coupling"
\tvar dependency := "cooling" if not cooling_ready else ("relay" if not relay_ready else "coupler")
\tif level in [2, 3]:
\t\tkey = "help.level%d.power_coupling.%s" % [level, dependency]
\treturn "help.power_coupling.complete" if phase == Phase.COMPLETE else key
'''
p.write_text(mission,encoding='utf-8')
