# Work session handoff - Mission 01 experience upgrade - 2026-11-23

## Live entry and mission flow

The project default and `Launch_Module_Bay_Program.ps1` open Power Coupling Cascade from its localized system boot. The boot and fade take about 1.6 seconds. Movement, look and interaction controls appear for seven seconds. The Station AI introduction plays as a localized text radio transmission during the corridor walk. The automatic airlock reuses the two imported leaves and releases the collision barrier once they slide clear. The doorway leads directly into the existing Module Bay. Crossing its threshold triggers the Chief Engineer's assignment and the single fading objective. The older reference launcher explicitly selects the frozen reference scene.

The player can approach the module, coupler, regulator, relay, scanner, AI station or terminal freely. Module rotation and scanner information appear on first pickup and are remembered for the current program session. The first rejected action starts a 25-second recovery window. Inspection, terminal interaction, changes to handling, tool use or repair progress defer dock salience. The timer pauses near and while moving toward the dock. The dock's lamp and short boot cue are the automatic support cue. The physical AI station remains available on request, with L1 system comparison, L2 dependencies and L3 missing input conditions.

The original repair predicates, snap and lock, relay/flow dependencies, physics, objects and transport are reused. The socket keeps its amber pulse, mechanical recoil and rejection sound. The relay route's temporary amber flash returns to its resting state. Successful locking starts the staged coupler/core route lighting, core lift, ring rotation and machinery hum. The status panel switches to operational, the room lights intensify, and the ventilation fan speeds up. Chief Engineer completion comes through the same radio channel. The bay remains explorable for 40 seconds before the operations console enables departure. Completion flags still save at successful activation. Previously earned unlocks are retained on replay.

## Environment and localization

`scripts/intervention/mb01_environment.gd` builds four batched corridor sections, two service equipment banks, the airlock surrounds, the fan, the animated status display and the dock indicator. All existing Blender/GLB assets remain in place on disk. The entry replaces only the live positive-Z infill and collision at the airlock. The corridor uses four unshadowed spill lights and no authored textures. The fan and display reuse lightweight materials and meshes. A maintenance drone was omitted to avoid another moving asset and keep the scene budget small. The narrative channel is text only.

New stable keys in both `localization/power_coupling` catalogs are `mb01.boot`, `mb01.controls`, `mb01.rotate`, `mb01.pause`, `mb01.door`, `mb01.radio.station`, `mb01.radio.engineer`, `mb01.radio.complete`, `mb01.objective`, `mb01.scanner.intro`, `mb01.status.offline`, `mb01.status.operational`, `mb01.exit.standby` and `mb01.interaction.{couple,scan,release}`. Existing MB01 terminal and help keys retain their semantic identifiers. L opens the existing language selector.

## Telemetry hygiene

The live HUD raycast sets prompts and emits no events. Subsystem inspection has one explicit E handler; terminal interaction has one F dispatch and one logging call. There is no passive enter/leave inspection recorder. MB01 filters hardware echo for E and F at input dispatch. Separate presses retain separate observations. Ten injected echoes after one press produced one terminal event and one inspection event, respectively.

The opening adds `game_intro_started`, `game_intro_completed` (end of the boot fade), `module_bay_entered`, `control_prompt_shown`, `mission_objective_shown`, `first_object_interaction`, `scanner_dock_woke` and `scanner_tutorial_shown`. Existing `placement_invalid`, `machine_activated` and `mission_completed` cover the repair beats. The mission and application IDs, event schema, offline queue and API serializer stay on the existing contract. Completion retains its existing telemetry boundary while the player continues exploring.

## Verification and performance

MB01's rendered probe lives under `verification/mb01_experience`. The older baseline probes under `verification/v02` and `verification/localization` retain earlier scaffolding or startup expectations. Use the new walkthrough for the live opening and cooldown.

Godot 4.7.2 ran Forward Mobile on Vulkan and AMD Radeon Graphics at 1280 × 720 with the existing MSAA setting. Both locales traversed the corridor in about 20.7 seconds. The Turkish offline probe passed 69 checks and the English isolated API probe passed 54 checks. The default launch also passed a rendered boot smoke test. Turkish glyphs were verified on the physical airlock sign. The walkthrough uses real movement, mouse look, collisions, device raycasts, and hardware actions. It checks the recovery delay, scanner and AI interactions, route illumination, core and machinery activation, completion radio, free exploration and console gating.

The English run restored MB01 without scanner, AI help or terminal interaction. The actual Research Station router accepted all 43 MB01 events in order and closed the session against a synthetic SQLite database. The offline run retained the local event queue. The walkthrough physically repaired MB02, confirmed the MB03 unlock, and entered MB03 through the operations console while retaining the selected locale. Verification used isolated progress files and tested MB03 launch.

A short same-camera room sample compared the prior MB01 controller from the pre-Phase-2C archive with the upgraded scene. The baseline used the shared accepted room and project renderer settings.

| Metric | Before | After |
|---|---:|---:|
| Mean FPS, short room sample | 72.38 | 73.23 TR / 76.16 EN |
| Scene mesh triangle inventory | 111,160 | 113,188 |
| Mean draw calls | 366 | 390 |
| Engine texture memory estimate | 376.36 MiB | 376.73 MiB |
| Light nodes | 8 | 12 |
| Shadow-casting lights | 1 | 1 |

The corridor and fixtures add 2,028 inventory triangles and about 24 draw calls in the sampled view. New surface materials use procedural colors and emission. The texture estimate includes runtime font and renderer allocations. The renderer emitted certificate/cache warnings in this environment and the previously documented seven-texture RID warning at shutdown. The samples are short and subject to run-to-run variation.

Local probe reports and captures are under `.cache/mb01_*`. To repeat the walkthrough, run the project with `--script res://verification/mb01_experience/run.gd` and pass `--verify`, `--locale=tr` or `--locale=en`, an isolated `--progress-file`, and an offline or isolated development `--api-base` after Godot's `--` separator.

This session stops at the MB01 experience upgrade.

# Prior handoff - Phase 2C - 2026-11-13

## Exact phase and stop boundary

PHASE 2C COMPLETE: Module Bay Mission 03, COOLANT PRESSURE IMBALANCE, mission ID MODULE_BAY_03_COOLANT_PRESSURE, version coolant_pressure_v0_1. GO for the requested prototype scope after actual runtime verification. MB01 and MB02 remain accepted, working intervention missions. Stop after Mission 03. Mission 04 and other cognitive modules have not begun.

This is a real-time 3D repair intervention for observation, action, evidence and revision. There are no quizzes, image/matrix tasks, academic questions, psychological scores, assessments, cloud progression or Android implementation.

## Completed MB03 mechanics

- New bounded coolant network and mission controller reuse the existing room, movement, scanner, AI, localization, action history, adaptive salience, telemetry and machine startup.
- Source/manifold -> primary valve -> pressure regulator -> bypass path -> cooling core. The terminal initially reports a common overheating/cooling symptom, not a named culprit. Multiple components remain plausible until the player compares evidence.
- Primary valve and bypass orientation animate; the spring regulator moves linearly. Controls are bounded and reversible. Mechanical stops give brief kickback rather than an arbitrary error popup.
- Source and downstream analog gauges have modeled needles/scales and an operating band. Pressure follows adjustments smoothly and oscillates under unstable configurations. There is a local temperature display, flow-dependent pipe illumination/audio, a core warning indicator and brief vibration after adverse adjustments.
- Closing supply reduces flow, greater bypass diversion lowers downstream pressure, and regulator changes alter pressure gain/oscillation. The same cooling failure can arise from different underlying settings.
- Stable sufficient flow cools the core; after a four-second settling period and thermal recovery, the accepted real-time machine lifts/spins online. No restart is required after mistakes.
- Physical scanner readings report source pressure, inlet flow, bypass flow, downstream pressure and cooling state; they never prescribe a valve setting.
- Mission-specific TR/EN L1 compares before/after states, L2 directs comparison along the coolant path, and L3 identifies relevant physical evidence for inspection. Help never changes controls.
- MB03 has less automatic onboarding than MB02: no tutorial line and no persistent control-teaching footer. Context prompts and the language shortcut remain. Automatic help salience waits 75 seconds without progress (MB01: 45), or three exact repeats after the initial stopped action. These remain provisional gameplay parameters.

## Controlled variation and valid repairs

Three verified starts:

| ID | Primary / regulator / bypass steps | Fault |
|---|---|---|
| A | 3 / 2 / 3 | Excessive bypass diversion |
| B | 3 / 0 / 0 | Regulator pressure instability |
| C | 2 / 1 / 1 | Combined mild regulator and bypass fault |

Normal entries cycle A -> B -> C -> A using a prototype local cursor. Configuration ID is recorded on every mission event. Verification can select only declared starts with --coolant-config=A|B|C. No unverified random problems are generated.

The 64-state model check finds three working balances: (2,2,0), (3,2,0), (3,2,1), and confirms every start has a reachable repair path. These are developer state buckets, not player instructions or an answer-entry task. A gauge-first C repair changes bypass then regulator; a separate independent repair changes regulator then primary and succeeds with the bypass partly open, without scanner or AI. The physical observations and operating range determine success, not one memorized exact combination.

## Raw action -> consequence -> next action context

Control interaction events link to committed changes through cause_event_uuid. pressure_changed and coolant_flow_changed link back to that committed action. Subsequent actions carry last_system_consequence_uuid, settings, target pressure/flow/oscillation, mission ID and configuration ID. reverses_action_uuid links a reversed control adjustment. action_differs_from_last_negative is a literal signature comparison following adverse physical feedback, not a psychological interpretation. Existing action signatures retain exact repetition, parameter/target/subsystem changes, inspection, tool use and help requests.

Events describe pressure targets and oscillation amplitudes; they do not pretend to sample every rendered needle frame. The existing language-independent event names, serialized HTTP contract, UUIDs, retries, acknowledgement/quarantine and API-down gameplay remain intact.

## Progression and local state

Completion alone unlocks MB01 -> MB02 -> MB03. The physical operations console displays all three statuses in TR/EN. F in completed MB02 enters MB03; before unlock, MB02's console still returns to MB01. MB03's console returns to MB01 for replay. There is no conventional 2D level-select UI and no performance/psychological gate.

user://module_bay_program_v01.json remains prototype device-local state. It stores completed slots and now configuration_cursors for controlled variation. Existing schema-1 saves without cursors remain compatible. No cloud/student learner state is implemented. Verification uses isolated workspace progress files. Selected language and queued raw telemetry survive scene transitions; restarting a mission creates a fresh physical layout, not a save/resume snapshot.

## Resource loading and materials

Before adding MB03, actual MB01 -> MB02 -> MB01 transitions checked weak references to mission-specific meshes/materials; outgoing heavy resources were released. GLB PackedScene wrappers themselves are transient after instantiation, so their cache presence is not the resource-lifetime test.

The final audit covers MB01 -> MB02 -> MB03 -> MB01. Only the current mission's heavy mesh/material resources remain alive; outgoing references are released. Pending telemetry nodes clear scene callbacks and retain only raw data. No whole-project loading rewrite was required. Renderer/font caches and the existing common room remain shared; no claim is made that all driver caches are immediately purged.

New MB03 static surfaces are batched by material, and nine standard PBR materials are pooled across its own assets. Accepted MB01/MB02 asset files are unchanged. Moving millimeter-scale needles do not cast room shadows; their modeled housings and the accepted room lighting retain shadows. Vibration is a brief consequence pulse, avoiding perpetual shadow-map refresh while preserving physical feedback. No light/shadow nodes are added.

## Blender assets

Generator: art_source/blender/scripts/build_coolant_pressure.py.
Sources: art_source/blender/mb03/*.blend.
Runtime: assets/models/mb03/*.glb.

| Asset | Triangles |
|---|---:|
| coolant_manifold | 2,736 |
| primary_valve | 2,828 |
| pressure_regulator | 3,348 |
| bypass_valve | 1,928 |
| cooling_core | 4,296 |
| pressure_gauge | 2,888 |
| coolant_routes | 4,620 |

Seven unique GLBs total 22,644 triangles. Two gauge instances make 25,532 mission-specific scene triangles. PBR materials, beveled housings, weighted normals and industrial proportions match the accepted visual language. There are no visible greybox placeholders. Existing original positional flow/valve/scanner/machine audio is reused; actual audio mixing has nonzero output and headroom.

## Last verified playable state and evidence

Actual Godot 4.7.2 Vulkan / Forward Mobile on AMD Radeon(TM) Graphics at 1280x720:

- MB03 A/B/C each complete in TR and EN after adverse adjustments, observation and recovery. Language-independent causal traces are equivalent for the same exploration inputs. Turkish glyphs and terminal/scanner/help layouts pass.
- The real idle test confirms no automatic nudge at 46 seconds and subtle availability after the configured 75 seconds. Exact-repeat salience is also verified.
- MB03 C completes against existing FastAPI on a temporary synthetic database; all raw events are acknowledged, session completion/replay/conflict checks pass, and no pending/quarantined events remain.
- Independent C repair follows a different order and reaches a different valid balance with no scanner or help requests.
- MB02 -> MB03 physical unlock/console transition, save/reload and A/B/C/A rotation pass. MB04 remains unavailable.
- Outgoing mission-specific meshes/materials release across all three rooms while offline evidence remains queued.
- MB01 full offline/API regression and TR/EN regression pass. MB02 full TR/EN/API regression passes. Neither accepted physical problem is broken.
- StudentPlanner production databases/backups/rows remain unchanged. API fixtures contain synthetic data only.

Key reports and traces:

- verification/phase2c/summary.json: consolidated final audit.
- verification/phase2c/summary_coolant.json: six configuration/language playthroughs, actual stall and synthetic API.
- verification/phase2c/summary_support.json: independent repair, progression, resources and profiles.
- verification/phase2c/network_model.json: all 64 bounded parameter states and reachable valid balances.
- verification/phase2c/resources_before_mb03.json and resources_all.json: actual resource lifetime snapshots.
- verification/phase2c/runtime_*.json, telemetry_*.json, *.png: individual assertions, raw evidence and captures.
- verification/v02/summary_both.json and verification/localization/summary.json: current MB01 regression.
- verification/phase2b/summary_offline.json and summary_online.json: current MB02 regression.

Automated aiming/positioning is test setup, not human usability evidence.

## Performance

Fresh same-camera six-second comparison after warmup:

| Metric | MB02 | MB03 |
|---|---:|---:|
| Mean FPS | 72.00 | 69.96 |
| Authored scene triangles | 115,664 | 122,400 |
| Mean draw calls | 414 | 361 |
| Estimated texture memory, MiB | 376.86 | 375.73 |
| Runtime material resources, including common room | 101 | 81 |
| Light nodes including inactive indicators | 8 | 8 |
| Shadow-casting lights | 1 | 1 |
| Reflection probes | 1 | 1 |

The earlier accepted MB02 baseline was 74.97 FPS / 376.98 MiB. Short-run hardware variation applies. MB03 adds ~5.8% triangles but uses ~12.8% fewer draw calls and slightly less estimated texture memory; FPS is ~2.8% lower in the fresh comparison. Nine pooled new PBR materials and static batching contain growth. Actuation/vibration and accepted core startup may transiently refresh shadows. The first 660-draw idle profile was corrected by controlling unnecessary shadow refresh, not by reducing accepted room quality. Before/after profiles are retained under verification/phase2c/.

Engine memory is an estimate, not physical GPU residency. Inventory includes hidden imported text meshes and excludes Label3D glyph geometry. No Android readiness/performance claim.

## Files added / updated

New: config/missions/mb03.json; scenes/main/coolant_pressure_imbalance.tscn; scripts/intervention/coolant_network.gd and coolant_pressure_imbalance.gd; interactables/coolant_control.gd, coolant_instrument.gd, coolant_socket.gd, coolant_machine.gd; Blender generator/sources/GLBs under mb03; localization/coolant_pressure/{tr,en}.json; phase2c verifiers, reports, traces, screenshots and manifests.

Updated: config/module_bay_program.json; shared mission controller hooks/minimal footer; local progression cursors; physical operations console; program/catalog localization; verification-only MB02 dispatch and profile output routing; MODULE_BAY_PROGRAM.md; LOCALIZATION.md; this handoff. MB01/MB02 mission rules, configuration definitions and original asset bytes are preserved.

Accepted pre-Phase-2C source/assets are archived at reference_builds/module_bay_program_pre_phase2c.zip with a 284-entry manifest. Earlier accepted v0.2 and frozen v0.1 archives/manifests remain preserved. project.godot and original launch paths remain unchanged. Launch_Module_Bay_Program.ps1 accesses the three-mission program in-world and defaults to API-down development mode.

## Remaining limitations / warnings

No required MB03 mechanic remains incomplete or failing final verification. Human review of diagnostic clarity, contact/control readability and pressure feedback remains pending. The hydraulic model and thresholds are bounded gameplay parameters, not engineering/clinical validation. Local completion/variation saves are not physical save/resume, cloud/student progression or a durable offline queue; quitting offline still loses queued evidence.

Known Windows root-certificate access and upstream seven Texture RID ReflectionProbe shutdown messages remain unchanged and unsuppressed. Blender may emit existing material API deprecation/thumbnail-cache messages, and headless import may report restricted editor-settings writes; exports/imports and real runtime resources load. Final gameplay runs have no script, missing-resource or missing-localization errors. A verifier SQLite handle cleanup issue was corrected by explicitly closing the temporary connection; production data was never involved.

## Repeat checks

..\StudentPlanner\.venv\Scripts\python.exe -B verification\phase2c\run_coolant_checks.py --configs A,B,C --stall --online
..\StudentPlanner\.venv\Scripts\python.exe -B verification\phase2c\run_support_checks.py
..\StudentPlanner\.venv\Scripts\python.exe -B verification\v02\run_cascade_checks.py --mode both
..\StudentPlanner\.venv\Scripts\python.exe -B verification\phase2b\run_program_checks.py --mode offline
..\StudentPlanner\.venv\Scripts\python.exe -B verification\phase2b\run_program_checks.py --mode online

## Explicit confirmations

- genuine real-time 3D gameplay: YES
- Mission 03 physically distinct from MB01/MB02: YES
- multiple valid exploration paths: YES
- 2D cognitive task added: NO
- psychological scoring added: NO
- assessment added: NO
- Mission 04 started: NO
- StudentPlanner production data modified: NO

## Exactly one recommended next step

Run Launch_Module_Bay_Program.ps1 for a human TR/EN playtest of MB03 across its three starts, reviewing whether gauge/flow consequences support independent diagnosis and revision. Retain default API-down mode. Do not start Mission 04 or another cognitive module.
