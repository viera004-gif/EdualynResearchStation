> Historical first-playable report. Current Phase 1B baseline: [REFERENCE_BUILD.md](REFERENCE_BUILD.md).

# Module Bay 01 quality checkpoint

Result: **CONDITIONAL GO**. Genuine playable 3D, no architectural replacement needed.
Stop for human visual review. No second room/mission, Android or learner-model work.

## 1. Blender assets
Seven authored source assemblies: module_bay_01, workbench, mission_terminal,
repair_machine, energy_module, socket_wrong, socket_correct. Room assembly includes
floor, wall panels, ceiling fixtures/ribs, airlock, ducts and service cabinets.
Bevels, weighted normals, key geometry, contacts, fasteners and converted mesh signage.
All source .blend files and reproducible authoring script are in art_source/blender.

## 2. GLB exports
Seven matching GLB files under assets/models; runtime imports are actual 3D meshes.
art_source/.gdignore excludes .blend from Godot's import system.
Reusable glTF-compatible Principled materials include dark/brushed metal, polymer,
light panel, glass, cyan/white/amber emission. Four deterministic 128x128 roughness
textures provide restrained surface variation. No image-based gameplay/backgrounds.

## 3. Scenes and scripts
Main, environment and player scenes; reusable Area3D interactables; CharacterBody3D
player; explicit mission phases; machine Tween/rotation script; serialized HTTPRequest
telemetry; separate verification harness. Runtime visible geometry comes from GLB,
not Godot primitive meshes. Only invisible physics shapes use primitive geometry.

## 4. Actual runtime verification
Actual Godot 4.7.2 Windows viewport using Vulkan 1.4.315 / Forward Mobile on AMD Radeon.
Both final GPU runs exited 0; no SCRIPT ERROR/ERROR entries in final runtime logs.
A shutdown warning reports 7 leaked Texture RIDs. Cause is not established; this
remains a runtime cleanup limitation rather than a hidden claim of warning-free output.
Six screenshots are directly saved from the live viewport, not rendered in Blender.

## 5. Visual observations
Inspected entry, carried module, wrong-interface and active-machine screenshots.
Readable industrial research room, live PBR response, modeled seams/fasteners/ducts,
physical screen/bench/keyed interfaces, restrained cyan and local amber feedback.
Amber specular artifact seen in an early test was corrected and visually rechecked.
This is early-game environment quality, not a photorealistic finished art pass.

## 6. Movement
InputMap WASD drives CharacterBody3D through actual physics; movement distance and
mouse yaw change verified via engine input. Live perspective camera, pitch limits,
interaction RayCast3D and carry anchor. ESC releases mouse; click resumes.
No claim of human usability testing: test aiming/position setup is automated.

## 7. Pickup
Real physics ray hits ENERGY_MODULE_A; F reparents the modeled 3D object to the
camera carry anchor. Verified live and captured. Three states: AVAILABLE/CARRIED/PLACED.

## 8. Rotation
R/T quarter-turn actual held Node3D geometry. Verified step and transform, and
orientation-dependent rejection. Deliberately discrete keyed orientation avoids
requiring precision motor alignment; orientation is relative to the module task,
not a continuous world-angle scoring rule.

## 9. Wrong socket
Real ray hits SOCKET_WRONG_01. Click produces placement_attempt/placement_invalid,
local amber indicator and rejection; module stays held and usable. No quiz popup.

## 10. Correct socket
Real ray hits SOCKET_CORRECT_01. Incorrect key orientation rejects; a right quarter
turn accepts. Module reparents/snaps into the physical dock and locks, leaving the hand.

## 11. Machine
OFFLINE -> STARTUP -> ACTIVE. Lock, indicator transition, core elevation, ring ramp
and stable rotation all occur in live Godot. Verified changed ring basis and active
light energy; mission reaches COMPLETE. No pre-rendered animation/video.

## 12. Telemetry
Actual HTTP integration against EXISTING StudentPlanner FastAPI code, with an
isolated temporary database and synthetic student_id=1. All 10 required event kinds
occurred across 15 actual test actions. Server acknowledged all 15 unique UUIDs;
replay already_accepted, changed payload conflict, no duplicate row. Session closed
only after the queue emptied. Offline run completed with all 15 events pending.
Production backend records were not used. Default manual game targets local port8000;
that intentionally records practice/raw telemetry if the real backend is running.

## 13. Performance
1280x720, Mobile/Vulkan, 4x MSAA. Mean frame rates in short final automated runs:
66.06 FPS offline, 65.10 FPS online, excluding the first 90 frames. Screenshot/frame
save work and shader warmup are not a sustained benchmark; no Android claim.
One shadowed task light, three facility fills, small status lights, one reflection probe.

## 14. Created files
See inventory below. Includes sources, runtime assets/scripts, launcher, README,
verification tool/results/captures, plus Godot-generated import/cache metadata.

## 15. Visual limits
Procedural surface variation is modest; no handcrafted wear/damage or final art
polish. Some small world lettering and specular edges still need art-direction review.
No sound design. Human review is required before treating the visual target as approved.

## 16. Gameplay limits
One mission only; no dropping/throwing, save/resume, rebind UI or touch controls.
ESC pauses movement/input, not machine/network time. Development outbox is in memory;
quitting loses pending events. Session-create retry has the current API's lost-response
orphan-session limitation. No auth; local trusted prototype only. Shutdown Texture RID
warning is recorded above. No Android, scientific measurement or learner-model work.

## 17. Decision and safety
CONDITIONAL GO: real-time 3D and complete playable coupling loop verified; remaining
work is polish/runtime cleanup and human acceptance, not an architectural replacement.
No further mission work is authorized until the user reviews this build.

| Explicit requirement | Result |
|---|---|
| Actual real-time 3D video game environment | YES |
| Visible Blender-created 3D environment | YES |
| Image-based gameplay | NO |
| Pre-rendered video | NO |
| Visible greybox primitives as final environment | NO |
| Free first-person movement | YES (automated engine input test) |
| Physical 3D object interaction | YES |
| Machine activates in real time | YES |
| Backend student/academic records changed | NO |
| Psychological scoring | NO |
| Android | NO |

Protected DB hashes and all production table counts remain identical to the starting
baseline. No StudentPlanner source, routes, templates, CSS or academic/Cognitive/Planner
functionality was changed. Test writes were confined to a temporary database.

Production counts: {"students": 1, "academic_records": 4, "cognitive_sessions": 0, "cognitive_trials": 0, "cognitive_profiles": 0, "research_station_sessions": 0, "research_station_events": 0}

Protected hashes:
```json
{
  "studentplanner.db": "39d34c25893754105f2f53f59481460a4c74e622e3fff88a79cf03eba099eed2",
  "studentplanner_backup.db": "af0fcd96bc8fa66a1895478ee1354526b18ce0451c9d5f93347c952cbf1ee1d7"
}
```

Asset manifest:
```json
{
  "module_bay_01": {
    "mesh_objects": 327,
    "triangles": 50256
  },
  "workbench": {
    "mesh_objects": 12,
    "triangles": 3356
  },
  "mission_terminal": {
    "mesh_objects": 12,
    "triangles": 4092
  },
  "repair_machine": {
    "mesh_objects": 39,
    "triangles": 13416
  },
  "energy_module": {
    "mesh_objects": 18,
    "triangles": 2160
  },
  "socket_wrong": {
    "mesh_objects": 15,
    "triangles": 3108
  },
  "socket_correct": {
    "mesh_objects": 15,
    "triangles": 2856
  }
}
```

Source/runtime file inventory (generated cache/logs omitted):

- `.gitignore`
- `Launch_Module_Bay_01.ps1`
- `README.md`
- `art_source/.gdignore`
- `art_source/blender/energy_module.blend`
- `art_source/blender/mission_terminal.blend`
- `art_source/blender/module_bay_01.blend`
- `art_source/blender/repair_machine.blend`
- `art_source/blender/scripts/build_assets.py`
- `art_source/blender/socket_correct.blend`
- `art_source/blender/socket_wrong.blend`
- `art_source/blender/workbench.blend`
- `assets/models/energy_module.glb`
- `assets/models/energy_module_mat_metal_brushed_roughness.png`
- `assets/models/energy_module_mat_metal_dark_roughness.png`
- `assets/models/mission_terminal.glb`
- `assets/models/mission_terminal_mat_metal_brushed_roughness.png`
- `assets/models/mission_terminal_mat_metal_dark_roughness.png`
- `assets/models/module_bay_01.glb`
- `assets/models/module_bay_01_mat_floor_roughness.png`
- `assets/models/module_bay_01_mat_metal_brushed_roughness.png`
- `assets/models/module_bay_01_mat_metal_dark_roughness.png`
- `assets/models/module_bay_01_mat_panel_graphite_roughness.png`
- `assets/models/repair_machine.glb`
- `assets/models/repair_machine_mat_metal_brushed_roughness.png`
- `assets/models/repair_machine_mat_metal_dark_roughness.png`
- `assets/models/repair_machine_mat_panel_graphite_roughness.png`
- `assets/models/socket_correct.glb`
- `assets/models/socket_correct_mat_metal_brushed_roughness.png`
- `assets/models/socket_correct_mat_metal_dark_roughness.png`
- `assets/models/socket_wrong.glb`
- `assets/models/socket_wrong_mat_metal_brushed_roughness.png`
- `assets/models/socket_wrong_mat_metal_dark_roughness.png`
- `assets/models/workbench.glb`
- `assets/models/workbench_mat_metal_brushed_roughness.png`
- `assets/models/workbench_mat_metal_dark_roughness.png`
- `assets/models/workbench_mat_panel_graphite_roughness.png`
- `assets/textures/mat_floor_roughness.png`
- `assets/textures/mat_metal_brushed_roughness.png`
- `assets/textures/mat_metal_dark_roughness.png`
- `assets/textures/mat_panel_graphite_roughness.png`
- `project.godot`
- `scenes/environment/module_room.tscn`
- `scenes/main/module_bay_01.tscn`
- `scenes/player/player.tscn`
- `scripts/interaction/energy_module.gd`
- `scripts/interaction/interactable.gd`
- `scripts/interaction/mission_terminal.gd`
- `scripts/interaction/module_socket.gd`
- `scripts/machine/repair_machine.gd`
- `scripts/mission/module_bay.gd`
- `scripts/player/first_person.gd`
- `scripts/telemetry/telemetry.gd`
- `scripts/verification/run_probe.gd`
