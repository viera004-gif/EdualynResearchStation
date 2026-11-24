# Module Bay Intervention Program — Phase 2C

Module Bay is a real-time 3D repair intervention: repeated practice with varied physical problems, recovery after failure, information seeking, strategy modification and optional adaptive help. It is not a test battery, T1/T2/T3 assessment, quiz, or psychological scoring system. Completion alone enables the next implemented mission.

## Mission sequence

| Slot | Mission | Role | Implementation |
|---|---|---|---|
| MB01 | Power Coupling Cascade | Introductory intervention and first gameplay-language learning experience | Opening experience upgrade on the accepted v0.2 repair |
| MB02 | Relay Polarity Failure | Configuration diagnosis: two rotary relay cartridges, polarity contacts and routing integrity | New Phase 2B mission |
| MB03 | Coolant Pressure Imbalance | Diagnostic hypothesis-testing and recovery through action, system evidence and revision | Phase 2C implementation |
| MB04 | Future | Reserved variation | Config placeholder only |
| MB05 | Future | Reserved variation | Config placeholder only |
| MB06 | Future transfer/challenge | Reserved reduced-support challenge | Config placeholder only |

No Mission 04–06, Control Core, Adaptive Matrix, Diagnostics Lab, Mission Operations module, full Intervention Engine, learner scoring, protected assessment, Android, authentication, cloud saves or academic-outcome analysis is implemented.

## Practical reusable framework

`config/module_bay_program.json` holds the six slots, implementation flags and completion prerequisites. `config/missions/mb01.json`, `mb02.json` and `mb03.json` describe identity/version, localized title/objective/completion keys, scene, dependency graph, available tools, meaningful failure states, valid end states, help policy, tutorial level, scaffolding level and intervention-only use. The dependency graph describes each physical model; mission-specific scripts enforce its actual mechanics. It is not a generic automatic puzzle solver.

`scripts/program/mission_definition.gd` validates/loads these definitions. `module_bay_mission.gd` is the shared room/session controller: accepted room GLBs and lighting, collision layout, player, physical scanner and AI station, input/localization, HUD, action history, adaptive salience, raw telemetry and machine completion. Mission-specific rules remain in `power_coupling_cascade.gd`, `relay_polarity_failure.gd` and `coolant_pressure_imbalance.gd`. MB03's bounded hydraulic model is `coolant_network.gd`. No mission copies an entire other's controller. The frozen v0.1 implementation remains a read-only foundation.

The shared components retain one player implementation, one scanner, one help-request policy hook, one translation service and one serialized HTTP transport. Mission-specific help-key selection and physical behavior stay in their small mission scripts. A mission's current phase/state and the local program's completion flags represent completion; there are no scores or performance gates.

## Physical access and local development progression

Start `Launch_Module_Bay_Program.ps1` (default offline, Turkish; optional `-Locale en`). The project default and program launcher open the live MB01 boot sequence. `Launch_Module_Bay_01.ps1` explicitly opens the original reference scene.

The physical operations console at the left side of the room displays MB01, MB02 and MB03 completion/availability in TR or EN. Completion alone unlocks the next implemented exercise: MB01 -> MB02 -> MB03. After MB01 restoration and the Chief Engineer's closing transmission, the physical console enables MB02 entry. The player can stay in the restored bay. F in completed MB02 accesses MB03. Before MB03 is available, MB02's console returns to MB01; MB03's console also returns to MB01 for replay of the program. Returning starts a fresh physical layout/session and retains completion flags. Help usage, failures, speed and other performance never gate access. No conventional 2D level selector is added.

`scripts/program/module_bay_program.gd` persists a schema version, program ID, completed slot IDs and deterministic configuration cursors to `user://module_bay_program_v01.json`. Existing schema-1 saves remain compatible; missing cursors default to the first variant. Cursors only rotate verified starts and are not a performance measurement. This is prototype local state, not a student/cloud record, learner model or protected progression. A custom `--progress-file=<path>` isolates verification fixtures. The chosen language is retained in memory across mission transitions; MB01 uses the launch locale at boot. L opens the language selector in the corridor or bay.

Unacknowledged telemetry nodes survive scene changes under the SceneTree root and continue retrying. A completed mission's `mission_completed` event is its evidence boundary; subsequent free room exploration does not append orphaned events to a closing/closed session. Leaving an unfinished mission records `mission_left` before closing that exercise session. Each newly entered mission opens its own identified intervention session. The queue remains in memory only and is lost if the application exits offline. This is not a durable offline-save system.

## Mission 01 opening experience

A short system boot leads into a shorter service corridor, a physical sliding airlock and the existing Module Bay. An optional ventilation panel introduces F in context and shows that the sector is on reserve airflow. Station AI and the Chief Engineer appear on a localized text radio channel. The first objective is to restore the primary coupling. Movement and look guidance fade automatically. Module rotation and scanner operation are introduced on first pickup.

The original dependency, keyed coupling, handling, diagnostics, L1/L2/L3 requests and recovery mechanics remain in the room. Upstream power rejection briefly lights the relay route. The Service socket gives a local incompatibility warning, and key misalignment moves the alignment rails. The first rejected action opens an unprompted recovery window. The dock can wake with a lamp and sound after 25 seconds of eligible time without progress. Inspection, tool handling and repair progress defer the cue. The manually available AI station requires fresh repair evidence between guidance tiers.

MB01 has three physical placements. A service module drives its cradle latch, a keyed contact module drives a flywheel, and the Primary Energy Module locks at Power A. The first two receivers can be used in either order, independently of Cooling and Relay. The final coupling needs both input contacts and the original Cooling and Relay conditions. A receiver's small approach response indicates a compatible held module even when alignment or input power is missing. F and left-click both seat a module when aimed at a receiver.

A segmented display and ventilation fan animate during exploration. The lock brings the power route, rising core, ring and machine hum online. Room lighting changes, both ventilation readouts switch to normal airflow, and the fan speeds up. The operations console enables departure when the Chief Engineer's completion transmission ends.

The exact accepted bilingual v0.2 source/assets/configuration before refactoring are archived at `reference_builds/module_bay_intervention_v02_pre_phase2b.zip`, with a SHA-256 manifest beside it. All 215 snapshot entries are verified. The earlier `module_bay_01_reference_v0_1.zip` and its 207-entry manifest remain unchanged. Existing accepted assets are not regenerated for Mission 02.

## Mission 02 — Relay Polarity Failure

Mission ID: `MODULE_BAY_02_RELAY_POLARITY`. Version: `relay_polarity_v0_1`.

The seated Energy Module and the terminal carry the previous repair forward. The terminal reports restored coupling and unstable secondary transfer. Two mounted rotary cartridges and a source contactor form the new repair.

Each relay has moving positive/negative contact geometry and matching fixed housing contacts. A has lateral fixed contacts and side guards; B has vertical fixed contacts and crown guards. A valid configuration can be deduced by comparing these physical symbols and scanner information. F turns the targeted relay one quarter-turn; R/T allow reverse/forward quarter-turns, including while holding the scanner. Rotation is animated and matters electrically. Initial orientations are A=3, B=0; the housing geometry defines A=1 and B=2 as the matching orientations. These numbers are internal state buckets, not a solution instruction on screen.

A physical source contactor tests the configured route. A pulse travels from the source to the stopping point and briefly lights the affected fixed contacts. A relay turn marks the tester as needing a new test. Aligned contacts enter a dim standby state. Manual engagement closes both latches and sends sustained transfer to the rising core. The secondary bus comes online as the machine completes startup.

### Meaningful failures

| Observable configuration | System reaction |
|---|---|
| A and B mismatched | Amber source-side return pulse, local mismatches, contactor kickback |
| A aligned, B mismatched | Power reaches B; amber pulse/collapse there, downstream route remains dark |
| A mismatched, B aligned | Power stops at A; B's local polarity is aligned but it has no stable input |

These are physical states and diagnostic information, not WRONG/TRY AGAIN popups. Repeating the same contactor attempt yields the same observable action signature; orientation changes, target switching, comparison, inspection, scanning and help are reconstructable alternatives. First-time alignment of a relay counts as mission progress; toggling a previously aligned relay does not repeatedly manufacture progress.

### Scanner and help

The optional DS-01 reports local polarity, interrupted input, the last relevant test location, and coupling input state. An unchanged repeat scan displays a short no-change status. Diagnostic result keys and raw orientations remain language-independent.

Mission-specific TR/EN help preserves three tiers. L1 encourages comparison, L2 narrows attention, and L3 describes the interrupted relationship. Escalation requires distinct evidence between requests. A new relay orientation, changed test result, or fresh observation can qualify.

MB02 uses contextual control prompts and a language shortcut. The AI kiosk stays subdued at entry. Test inputs and outcomes share an attempt UUID, and route events distinguish unengaged continuity, test transfer, and energized load transfer.

## Blender → GLB → Godot assets

`art_source/blender/scripts/build_relay_polarity.py` creates five original assets using the accepted material/helper definitions, bevels, weighted normals and standard glTF PBR roughness textures. Source BLEND files live in `art_source/blender/mb02/`; runtime GLBs live in `assets/models/mb02/`.

| Asset | Triangles |
|---|---:|
| polarity_relay_a | 5,836 |
| polarity_relay_b | 6,220 |
| relay_coupling_assembly | 1,580 |
| polarity_connectors | 3,000 |
| polarity_routes | 2,160 |
| New authored geometry total | 18,796 |

Moving contacts and levers use authored pivots. New status strips use emissive materials and short rejection pulses, adding no shadow lights. All visible repair geometry is Blender-authored; Godot boxes/capsules are invisible colliders. Existing original industrial audio is reused for rotation, rejection, engagement, scanner and machine states.

## Localization and telemetry

`localization/program/{tr,en}.json` and `localization/relay_polarity/{tr,en}.json` extend the existing catalog. All mission/console/prompt/help/diagnostic strings use stable keys. The existing Turkish-capable font and unchanged readable screen sizes are verified in runtime. A/B, +/− and equipment identifiers remain invariant. Switching language retains current configuration and support state and changes neither policy nor telemetry event vocabulary.

Mission 02 records `relay_unit_rotated`, `relay_configuration_invalid`, `relay_configuration_valid` and `power_route_changed`, alongside the existing scanner/inspection/help/machine/completion families. It does not fabricate pickup/insertion events for mounted rotary hardware. Context contains the required mission ID, version, slot, tutorial/scaffolding level, locale, both relay orientation buckets, route state and preceding failure UUID. No trait, score or assessment interpretation is generated. The existing Phase 1A HTTP contract, acknowledgement, retry, idempotency and quarantine behavior remain in place.

## Mission 03 — Coolant Pressure Imbalance

Mission ID: `MODULE_BAY_03_COOLANT_PRESSURE`; version: `coolant_pressure_v0_1`. This is a diagnostic hypothesis-testing/recovery intervention, using observation, action, evidence and revision. No hypothesis terminology is shown to the player. The terminal reports overheating and inadequate cooling without naming a faulty component. A steady source gauge, changing downstream gauge, regulator travel and bypass flow make multiple causes initially plausible.

The real 3D network contains a source/manifold, primary valve, linear spring regulator, bypass valve, cooling core, two analog gauges and physical pipes. F/T increases a targeted control; R decreases it. Controls have bounded mechanical stops and animate before their parameter changes take effect. Closing the primary valve reduces supply, opening the bypass diverts flow, and regulator settings alter pressure gain and oscillation. Several configurations produce the same cooling-failure symptom. The source gauge remains steady while the downstream gauge reveals the combined effects, so players can compare before/after adjustments and investigate in different orders.

### Controlled starting configurations and valid balances

| ID | Internal primary / regulator / bypass steps | Initial fault |
|---|---|---|
| A | 3 / 2 / 3 | Excessive bypass diversion |
| B | 3 / 0 / 0 | Regulator pressure instability |
| C | 2 / 1 / 1 | Combined mild regulator and bypass fault |

Normal entries cycle A -> B -> C -> A using a device-local cursor. Verification may select a declared case with `--coolant-config=A|B|C`. No random unverified systems are generated. A 64-state bounded model check proves every start can reach a working balance. The valid step triples are `(2,2,0)`, `(3,2,0)` and `(3,2,1)`: the player is not required to find one exact accepted combination. In particular, a partly open bypass can work with sufficient regulated inlet flow.

This is a deliberately small gameplay hydraulic model, not an engineering or clinical simulator. Its parameters produce continuous instrument response and believable diagnostic consequences. Output target pressure is inlet fraction × retained flow fraction × regulator gain; instability combines regulator oscillation and diversion. Gauge pressure follows smoothly with a visible oscillating component. Core temperature falls only with adequate, steady supply. Four seconds of stable supply and thermal recovery release the protective interlock, followed by the accepted live machine startup. No correct-control sequence or component values are shown on an instruction screen.

### Physical feedback and recovery

- Modeled analog needles, a physical operating band and local bar readings show pressure changes. The core has a physical temperature display.
- Pipe emission strength follows source/core/bypass flow. The core warning indicator pulses under insufficient cooling and steadies during recovery.
- Valve orientation, linear regulator travel, contextual scanner readings and original positional flow audio reveal system consequences. Adverse adjustments cause a brief machine vibration.
- Stops give a small mechanical kickback. Every wrong adjustment remains recoverable in the same session; no restart, score or punishment screen is used.

The scanner reports evidence such as unstable pressure, low inlet flow and high bypass flow. It does not instruct the player to close a valve or select a numbered setting. Gauge-only diagnosis and optional scanner use are both supported. One verified C repair adjusts bypass then regulator; another adjusts regulator then primary supply and succeeds with the bypass still partly open, without scanner or AI requests.

MB03 L1 asks the player to compare system conditions before and after adjustments. L2 directs comparison along the coolant path. L3 identifies the relevant evidence (diversion before the core, a restricted inlet or downstream oscillation) and asks for inspection; it never moves controls. TR and EN share the same keys, rules and information gradient.

Scaffolding is lower than MB02: `tutorial_level=instrument_only`, `scaffolding_level=minimal`, no persistent control-teaching footer and no tutorial line. Local interaction prompts and the language shortcut remain. Automatic support salience waits 75 seconds without meaningful progress or three exact repeats after the initial stopped action. These are provisional gameplay parameters only. The actual runtime test confirms no 45-second nudge and a nudge after the configured 75 seconds. No forced help or performance gate is introduced.

### Raw action -> consequence -> next action evidence

`coolant_valve_interaction/changed`, `regulator_interaction/changed` and `bypass_interaction/changed` link the physical activation and committed setting using `cause_event_uuid`. The resulting `pressure_changed` and `coolant_flow_changed` events refer to that committed adjustment. Context on later actions carries `last_system_consequence_uuid`, settings, target pressure/flow/oscillation, mission ID and configuration ID. `reverses_action_uuid` links a return to the preceding control setting. The raw boolean `action_differs_from_last_negative` compares observable action signatures after adverse feedback; it is not a judgment of strategy or a psychological feature/score. Existing signatures still describe repetition, parameter/target/subsystem change, inspection, tool use and help.

Events record target pressure changes and oscillation amplitude, not every rendered oscillation frame. They support causal behavioral reconstruction without pretending to sample every instantaneous needle position. The same serialized transport, intervention purpose, UUID/retry/acknowledgement and API-down behavior are retained.

### Assets, materials and mission resource lifetime

`art_source/blender/scripts/build_coolant_pressure.py` exports seven original GLBs and corresponding BLEND sources under `mb03/`: manifold, primary valve, regulator, bypass valve, cooling core, pressure gauge (instanced twice), and pipes. Static surfaces are batched by material while moving mechanisms and flow strips remain separate. Tiny gauge tick geometry avoids unnecessary bevel tessellation; the modeled bezels, raised needles, clear scale and accepted room quality are retained. MB03 pools nine standard PBR material resources across its own assets; accepted MB01/MB02 assets are untouched.

Before MB03 implementation, actual MB01 -> MB02 -> MB01 transitions verified that outgoing mission-specific meshes/materials were released. The same check now covers MB01 -> MB02 -> MB03 -> MB01 using weak references to actual mesh/material resources, rather than GLB PackedScene cache wrappers (which are transient after instantiation). Only current-mission heavy resources remain alive. Persistent program/telemetry nodes hold completion strings and raw data, not room resources. No whole-project loader rewrite or Android implementation was needed. Exact accepted Phase 2B source/assets are also preserved in `reference_builds/module_bay_program_pre_phase2c.zip` with a 284-entry manifest.

Moving millimeter-scale gauge needles do not cast room shadows; their modeled housings and the accepted room task-light shadows remain. Vibration is a brief physical response rather than a perpetual whole-machine transform, avoiding continuous shadow-atlas refresh. There are no new light or shadow-casting light nodes. The existing upstream ReflectionProbe shutdown warning remains untouched.

### Phase 2C verification

```powershell
..\StudentPlanner\.venv\Scripts\python.exe -B verification\phase2c\run_coolant_checks.py --configs A,B,C --stall --online
..\StudentPlanner\.venv\Scripts\python.exe -B verification\phase2c\run_support_checks.py
```

Actual GPU/input checks exercise every start in TR and EN, actions/consequences/reversals, gauges, scanner and graduated help, thermal recovery, completion, no-restart repair, provisional help timers, causal traces and the existing API on synthetic temporary data. Additional checks cover independent alternative repair, MB02 -> MB03 completion-only unlock, save/reload, physical console transition, configuration rotation and resource release. MB01 and MB02 retain their actual runtime regression suites. Final measured performance and consolidated results are recorded in `verification/phase2c/summary.json` and `WORK_SESSION_HANDOFF.md`.

| Same-camera six-second profile | MB02 fresh comparison | MB03 |
|---|---:|---:|
| Mean FPS | 72.00 | 69.96 |
| Authored scene triangles | 115,664 | 122,400 |
| Draw calls | 414 | 361 |
| Estimated texture memory (MiB) | 376.86 | 375.73 |
| Light nodes / shadow lights | 8 / 1 | 8 / 1 |
| Runtime material resources, including shared room | 101 | 81 |

The earlier MB02 baseline was 74.97 FPS / 376.98 MiB; short-run hardware/timing variation applies. MB03 has approximately 5.8% more authored triangles, 12.8% fewer draw calls and 2.8% lower mean FPS in the fresh comparison. Seven unique MB03 GLBs total 22,644 triangles; the second gauge instance makes 25,532 mission-specific triangles in the scene. Batching and nine pooled new PBR materials contain the cost. Actuation, brief vibration and the accepted core startup can temporarily refresh shadows; persistent needle movement no longer refreshes the room shadow map. No accepted room geometry, lighting quality or renderer setting was reduced. This is a desktop Mobile-renderer profile, not an Android performance claim.

## Earlier Phase 2B verification and performance

```powershell
..\StudentPlanner\.venv\Scripts\python.exe -B verification\v02\run_cascade_checks.py --mode both
..\StudentPlanner\.venv\Scripts\python.exe -B verification\localization\run_localization_checks.py
..\StudentPlanner\.venv\Scripts\python.exe -B verification\phase2b\run_program_checks.py --mode all
```

The actual Vulkan/Forward Mobile game is exercised with input events and real physics raycasts. Checks cover Mission 01 regression, Mission 02 TR/EN equality, all three failure configurations, orientation/motion, scanner and help, faded onboarding, independent recovery, completion, API-down operation, synthetic FastAPI acknowledgement/replay/conflict, local save reload, locked access and physical console transition with offline evidence retained.

Controlled six-second idle profiles use the same camera in each mission after warmup. Reports in `verification/phase2b/profile_MB01.json` and `profile_MB02.json` include FPS, authored scene triangles, draw-call monitors, texture/video-memory estimates, light/shadow counts and the reflection probe. Scene triangle inventory includes hidden imported text meshes and excludes Label3D glyph geometry; draw-call and memory monitors are engine estimates rather than physical GPU residency. Playthrough profiles also include screenshot/readback overhead. The comparison does not lower visual quality or remove accepted lighting.

| Same-camera measurement | Mission 01 | Mission 02 |
|---|---:|---:|
| Mean FPS | 76.31 | 74.97 |
| Authored scene triangles | 111,160 | 115,664 |
| Mean draw calls (monitor) | 366 | 414 |
| Texture-memory estimate (MiB) | 376.36 | 376.98 |
| Light nodes, including inactive signals | 8 | 8 |
| Shadow-casting lights | 1 | 1 |
| Reflection probes | 1 | 1 |

Mission 02 is approximately 1.7% slower in this short same-camera sample, with about 4.1% more authored triangles and 13.1% more draw calls. Its initially amber coupler activates an existing signal light; no new light or shadow nodes are added. The new authored assets total 18,796 triangles but replace the Mission 01 valve/relay/routes, so the net scene increase is 4,504. Another runtime scenario repairs B before A and completes without scanner or AI requests, demonstrating that support and a fixed exploration order are not required.

The additional relay surfaces/material resources and text may affect draw calls; the shared shadowed task light and reflection atlas remain the main existing lighting costs. Known Windows certificate-store and upstream seven Texture RID ReflectionProbe shutdown messages are retained. No claim of human usability, efficacy, clinical validity or minimum FPS is made by the automated checks. Final measured results and the exact next action are in `WORK_SESSION_HANDOFF.md`.
