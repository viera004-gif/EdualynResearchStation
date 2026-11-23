# Edualyn Research Station / Module Bay 01
Module Bay 01 Reference Build v0.1. Accepted real-time 3D visual direction; Phase 1B stabilized baseline.
See REFERENCE_BUILD.md (versions/profiles/known engine warning) and ANDROID_READINESS.md (audit only).
No second mission, Android, psychological scoring or learner-model work is included.

## Run
Open project.godot with Godot 4.7.2 (Mobile/Vulkan), or run Launch_Module_Bay_01.ps1.
If opening a fresh checkout, allow the editor to import assets first:
Godot --headless --editor --import --path <this-project>
Runtime assets are GLB only. art_source/.gdignore prevents .blend runtime imports.

WASD move; mouse look; F terminal/pickup; R/T quarter-turn module; LMB couple; ESC pause/release mouse.
Click resumes. No jump/sprint. All controls are InputMap actions (configured on startup).
Activate the physical terminal, lift the module from the workbench, and restore the POWER A interface.
SERVICE is deliberately incompatible. The amber key requires one right quarter-turn from pickup orientation.
Rotation is discrete and tested as keyed orientation rather than precision motor alignment.
The correctly keyed module snaps/locks; the core lifts, the ring turns, and lights transition online.
Failure remains in-world (amber socket), with no score or quiz screen.

## Source and rendering
Blender 5.2.3 source files: art_source/blender/*.blend.
Reproducible authoring: art_source/blender/scripts/build_assets.py.
Seven GLB assemblies in assets/models. Bevelled geometry, weighted normals, glTF-compatible Principled PBR.
Godot handles actual live lighting, player perspective, physics raycasts and all machine motion.
Collision boxes/capsules are invisible; no Godot primitive mesh is used for visible room/gameplay.
Scene assembled from named GLB assemblies by scripts/mission/module_bay.gd.
One shadow-casting task light, three facility fills, localized status lights and one reflection probe.
No rendered backgrounds/video. No runtime .blend dependency or external asset downloads.

## Telemetry
Default: http://127.0.0.1:8000/api/v2/research-station, student_id=1,
purpose=practice, platform=windows, app=research_station_v0_1, game=module_bay_01_v0_1.
Single serialized HTTPRequest with timeout/retry; gameplay never awaits network.
Events get UUIDv4 once and increasing session indexes. Only acknowledged UUIDs leave the queue.
Conflicts/permanent rejections remain quarantined in memory. Completion waits for a fully acknowledged queue.
Offline queue is development IN-MEMORY ONLY: quitting loses unsynced evidence; no Android durability claim.
Server-generated session creation has the existing API's lost-response duplicate-session limitation.
No names or psychological interpretations are sent. Local API currently has no auth; local trusted use only.
To disable live integration during a visual-only playtest, launch with:
Godot --path <project> -- --api-base=http://127.0.0.1:1/api/v2/research-station
Actual play with the default live backend writes only practice session/raw-event telemetry.

## Verification
Use StudentPlanner's existing Python environment:
..\StudentPlanner\.venv\Scripts\python.exe -B verification\run_checks.py --mode both
The verifier runs the actual Vulkan/Mobile game, renders screenshots, feeds engine input,
checks real physics ray targets, pickup/rotation/rejection/snap and machine movement,
then tests HTTP against the EXISTING FastAPI code using a TEMPORARY DB and synthetic student.
It does not use production records or mutate StudentPlanner source.
Verification aim/position setup is automated; no claim of human usability testing.
Captures: verification/captures/*.png. Reports/traces: verification/*.json.
The default game does not execute the verifier or auto-play.
First-run shader/import work may temporarily affect frame rate.

## Review gate
One room, one coupling mission. Stop for user visual review before expansion.
Seven original positional audio cues are included; generator/provenance are in art_source/audio and assets/audio.
Known limits: no touch controls, rebinding UI, save/resume, or persistent offline queue. Godot 4.7.2 retains the confirmed seven-texture reflection-atlas shutdown warning; it is not suppressed.
ESC is a development movement/input pause; machine/network can continue.
