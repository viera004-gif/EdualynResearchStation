# Module Bay 01 — Power Coupling Cascade v0.2

Phase 2A: Recovery + Adaptive Help-Seeking Intervention. This is the first intervention mission within Module Bay 01. It is an exercise, not a T1/T2/T3 assessment. It has no psychological scores, inferred traits, questionnaires, academic quizzes, image-choice tasks, or 2D cognitive tasks.

Phase 2B preserves this mission's physical rules while extracting its common room/session systems into `scripts/program/module_bay_mission.gd`. A physical operations console now exposes Mission 02 after completion alone. The exact accepted pre-refactor bilingual v0.2 build is archived in `reference_builds/module_bay_intervention_v02_pre_phase2b.zip`. The original v0.1 archive/default launch remain untouched. See `MODULE_BAY_PROGRAM.md` for the program framework, Mission 02 and updated verification.

## Bilingual TR / EN update

The active v0.2 intervention now has one gameplay implementation with separate Turkish and English catalogs. Choose TÜRKÇE or ENGLISH at startup; press L to reopen the selector. Turkish is the development default; the launcher also accepts `-Locale en`. HUD, contextual prompts/tutorials, terminal, scanner results, AI guidance, completion/status and scene-level equipment signage update without restarting or changing recovery/help state. The original v0.1 source, documentation, assets and launch configuration remain untouched.

Reusable service, catalog extension instructions, equivalent help wording, font/layout checks and intentionally invariant identifiers are documented in `LOCALIZATION.md`. Telemetry adds locale context and stores diagnostic/guidance keys rather than translated prose; event names, states, signatures and help levels remain language-independent. The bilingual GPU verifier is `verification/localization/run_localization_checks.py`; its TR/EN traces are compared for identical event semantics after normalizing locale, timestamps and UUIDs. Reports and screenshots are under `verification/localization/`.

## Play

Use the separate `Launch_Module_Bay_Intervention_v02.ps1` launcher after verification. `project.godot` and `Launch_Module_Bay_01.ps1` continue to launch Reference Build v0.1. The frozen archive is `reference_builds/module_bay_01_reference_v0_1.zip`; extract it into a separate directory to review it.

WASD moves, mouse looks, F operates/picks up, E inspects, R/T rotates the energy module, LMB couples or scans, Q places a held object on an upward-facing physical surface, L opens language selection, and ESC releases the mouse. Click resumes. Tools occupy one hand slot. Aim at the scanner dock deck or the floor to put a tool down. Movement is unrestricted within room collisions; no fixed sequence of UI clicks advances the mission. Interacting with a subsystem can begin the intervention without first visiting the mission terminal.

## Connected mechanics

The controller `scripts/intervention/power_coupling_cascade.gd` extends the accepted room controller without modifying it. It composes the existing lighting, room, HUD, first-person movement, module, sockets, animated machine and serialized telemetry with v0.2 extensions. `cascade_device.gd` supplies physical regulator, relay, scanner and AI station interactions using the six authored Blender/GLB assemblies. Render geometry remains authored GLB; code-created boxes/capsules are invisible collisions.

Internal dependency states are SYSTEM_OFFLINE → COOLING_UNRESOLVED → COOLING_READY → RELAY_UNRESOLVED → RELAY_READY → COUPLING_READY → MODULE_LOCKED → SYSTEM_ACTIVE. They are raw state-machine evidence, not player task labels. The world remains freely explorable. An early module placement produces amber socket feedback and mechanical kickback. The cooling wheel physically turns before flow becomes ready. The relay lever kicks back when cooling is unavailable and engages only after flow stabilizes. Coupling additionally requires POWER A and the module's correct physical quarter-turn. The final module snaps and locks; the existing core lifts, ring accelerates and machine lights become active in real time. Mistakes leave the same session playable.

The physical DS-01 scanner begins on a dock, reparents into the player's carry anchor when picked up, and scans the aimed raycast subsystem with LMB. Acquisition requires keeping the target in sight. Its own world-space screen displays contextual state: FLOW INTERRUPTED / FLOW STABLE, INPUT POWER UNSTABLE / CONTACT OPEN / RELAY ENERGIZED, and UPSTREAM LOCK / INTERFACE READY / COUPLING ACTIVE. Losing the target cancels acquisition. These reports describe conditions rather than solving the cascade.

The optional AI station is a separate physical console reached in-world. F requests support; its recessed screen displays the response. L1 offers a broad strategy, L2 directs attention toward the relevant subsystem, and L3 explains the current immediate dependency. Every operation remains manual. Very early requests with fewer than two exploration actions deliver L1 inspection/scanning encouragement. Help never deducts points or becomes mandatory. A second runtime scenario completes without terminal use or help.

## Prototype adaptation

All thresholds are **PROVISIONAL GAMEPLAY PARAMETERS — NOT VALIDATED PSYCHOMETRIC OR CLINICAL CUT-OFFS**. They live in `config/intervention_v02.json` and select gameplay support only.

- Two exact repeats after the initial invalid action make the station's light and invitation more salient.
- 45 seconds without mission progress makes optional support more salient.
- With sufficient exploration, successive help requests select L1, L2, then L3.
- Regulator and relay completion and module locking reset the progress clock; merely inspecting does not fabricate mission progress.

Action signatures contain action family, object/target IDs, orientation bucket, subsystem and tool. Bookkeeping distinguishes an exact repeat from parameter adjustment, target change, subsystem switch, information seeking, scanner use and help request. A changed action between failures breaks uninterrupted-repeat counting. No observable pattern is translated into a psychological trait or score.

## Audio and telemetry

`art_source/audio/generate_intervention_v02.py` deterministically synthesizes eight original mono 48 kHz PCM WAV cues: valve, flow, relay_reject, relay_engage, scan_start, scan_complete, station_wake and trace. `assets/audio/intervention_v02/audio_manifest.json` records provenance and hashes. No external samples or commercial assets are used. Runtime audio uses the existing positional bus and restrained industrial identity.

The Phase 1A HTTP contract is inherited unchanged: UUIDs, monotonic event indexes, one serialized HTTPRequest, retries, acknowledgement-based dequeue and quarantine. The v0.2 extension sets session purpose to `intervention`, app version to `research_station_v0_2` and content identity to `MODULE_BAY_01_POWER_COUPLING_CASCADE_V02`. Raw events include regulator changes, relay interactions/rejections/activation, scanner pickup/acquisition/result, inspection, station requests/delivered help, placement attempts/results, machine activation and completion. Context includes observable subsystem conditions, orientation, action signature, help level and preceding invalid-event UUID. Failure and subsequent actions can be reconstructed from the trace.

Gameplay never awaits network. The offline queue remains development-only in memory; quitting discards unacknowledged evidence. There is no save/resume, persistent offline queue, touch interface or rebinding UI in this phase. ESC pauses movement/input only; machine/network time continues as in v0.1. The launcher defaults to API-down mode to avoid writing development playtests to StudentPlanner production. An explicit `-ApiBase` can target a synthetic/dev endpoint.

## Verification and limits

Run `..\StudentPlanner\.venv\Scripts\python.exe -B verification\v02\run_cascade_checks.py --mode both`. The verifier runs the actual Godot 4.7.2 Vulkan/Forward Mobile game with input events and physics raycasts. It tests movement, recovery, dependencies, physical tool use, all support levels, the actual 45-second stall threshold, repeat salience, animated startup, completion, audio output and reconstructable telemetry. Online checks use existing FastAPI code with a temporary database containing only a synthetic student. Production database/backup hashes and rows are checked before/after. The reference ZIP entries and preexisting reference files are also hash checked.

Reports, traces, screenshots and logs are in `verification/v02/`. Automated aiming/positioning is test setup; it is not evidence of human usability or clinical efficacy. The accepted room assets, materials, lighting, renderer, resolution and machine animation remain intact. Additive v0.2 wheel/lever pivots were corrected in the Blender generator so the moving parts sit on their physical mounts.

Known environment messages: Godot cannot read the Windows root certificate store in this restricted execution environment; localhost HTTP integration is verified separately. The known seven Texture RID ReflectionProbe shutdown warning remains untouched. The Blender regeneration log contains inaccessible thumbnail-cache messages and a material API deprecation notice; BLEND/GLB export completed and runtime loading is verified. Initial import also encountered restricted editor-settings/log destinations; the final import uses an absolute workspace log path. No missing-resource or script error is accepted in runtime checks.

Final verification results and the exact next action are recorded in `WORK_SESSION_HANDOFF.md`.
