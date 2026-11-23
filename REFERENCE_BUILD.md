# Module Bay 01 Reference Build v0.1

Phase 1B stabilization baseline, 2026-11-12. Accepted visual direction preserved.
One room and one mission only. This is a source-project reference build, not a packaged
Android/Windows export. The remaining engine-level shutdown warning is explicit below.

## 1. Texture RID root cause and attempts
Four controlled actual-GPU diagnostics isolate the defect:
- Minimal imported module + camera/light, no ReflectionProbe: exit 0, no warning.
- Same minimal scene + ReflectionProbe: exit 0, exactly seven leaked Texture RIDs.
- Full accepted room without screenshot capture: same seven.
- Full room freed twelve render frames before quit: same seven.

The minimal scene has no HUD, dynamic indicator overrides or screenshot ViewportTexture reads,
so those are not necessary to reproduce it. The count is constant, not proportional to
actions/captures/material creation. Upstream identifies missing reflection-atlas color-buffer
and six face-view cleanup in the engine, not an application-owned texture lifetime error.
Sources: https://github.com/godotengine/godot/issues/122498
and https://github.com/godotengine/godot/pull/124743 (engine fix assigned to 4.8).

Warnings were NOT eliminated on pinned 4.7.2. Removing the probe removes the warning in the
diagnostic but would alter accepted metal reflections, so it was not shipped as a workaround.
No warning filters or logger suppression were added. No engine upgrade/custom binary was
installed. Application code cannot safely free those private engine atlas RIDs.
Five final full-game runs exit 0 and retain the same visible known warning.

## 2. Original audio
Seven deterministic, locally synthesized mono 48 kHz cues: terminal, pickup, rotate,
invalid, lock, startup and a seamless two-second active hum. Source generator:
art_source/audio/generate_audio.py; provenance/levels: assets/audio/audio_manifest.json.
No commercial samples. Seven reused positional players share StationSFX bus; hum fades in.
Streams are cached once. QOA/PCM loop length uses decoded duration and mix rate, never
compressed byte length. Hum loop is asserted at 96,000 frames.
Runtime WASAPI bus capture verifies real nonzero output, expected cue counts, active looping,
and ample headroom. This is automated routing/signal verification, not a human listening
approval of the final mix.

## 3. Interaction feedback
Wrong interface/key gives a short localized amber light and emissive pulse plus a low
mechanical rejection cue; both visual channels return to neutral. No large WRONG popup.
Success cancels any prior rejection tween, closes existing modeled guide rails by 18 mm,
locks the module, and keeps the blue socket light on. The previous tween could otherwise
fade a successfully locked socket. Startup/core/ring animation and minimal completion HUD
remain intact, supported by lock/startup/hum cues. No behavioral event is emitted by audio.

## 4. Visual preservation
All pre-existing runtime assets and seven .blend sources match starting hashes.
No Blender mesh, PBR source, room layout, light layout, resolution or MSAA downgrade.
Indicator overrides are reused instead of allocating a new material for every pulse.
Six actual viewport captures were regenerated and inspected; these are real Godot output.
Expected visible differences are pulsed rejection, slightly closing rails, and stable
correct-interface illumination. No 2D task/image gameplay, replacement primitives or video.

## 5. Performance baseline
Windows AMD Radeon(TM) Graphics, Vulkan 1.4.315 / Forward Mobile, 1280x720, 4x MSAA.
Primary comparison is a controlled audio-off/audio-on A/B of the SAME accepted view:
camera/input/physics are locked in the diagnostic; four-second idle and active windows
after warmup; no screenshots. This isolates audio, rather than claiming a speedup from
other stabilization changes. Initial actual pre-integration profiles are also archived
as profile_before.json; an unlocked-camera run was discarded for comparative conclusions.

| Controlled window | Audio off avg FPS | Audio on avg FPS | Audio off minimum single-frame FPS | Audio on minimum single-frame FPS | Audio on lowest engine 1-second FPS |
|---|---:|---:|---:|---:|---:|
| idle | 75.85 | 77.46 | 51.09 | 64.76 | 75 |
| active | 74.88 | 76.64 | 45.16 | 54.52 | 58 |

These short samples show no evident audio regression, not a statistically established
optimization. No sustained/thermal benchmark or GPU timestamp breakdown was available.
Engine monitors can be delayed by about a second. The full automated playthrough also
records minima, but six synchronous GPU readbacks/PNG saves create artificial stalls;
do not describe its approximately 7 FPS instantaneous minima as normal gameplay floors.

- idle: draw-call monitor mean 318, max 318; texture-memory estimate 392,410,336 bytes (374.23 MiB); video-memory monitor 445,665,056 bytes.
- active: draw-call monitor mean 569, max 569; texture-memory estimate 392,410,336 bytes (374.23 MiB); video-memory monitor 445,664,512 bytes.

Memory is the aggregate engine estimate, including renderer usage, not physical VRAM
residency or solely the source texture files. Driver frame timings, GPU busy percentages
and per-allocation breakdown are unavailable; none are fabricated.
The active benchmark turns the machine on without docking: five active lights there.
Full mission completion has six active lights after a successful socket lock.

## 6. Triangle/material/light inventory
79,244 triangles; 438 rendered mesh instances; 13 semantic glTF materials; 52 material
resources at the complete-state gameplay snapshot (including separate imports/overrides).
Four original 128x128 roughness maps / 18 glTF image entries. Seven dynamic Light3D nodes,
one shadow-casting spotlight, one local reflection probe. Geometry, textures and lighting
quality are unchanged. The source mesh total differs from per-frame engine primitives,
which depend on view, passes, shadows and culling.

## 7. Android audit
See ANDROID_READINESS.md. GREEN: modest triangle count alone, small textures, simple
collision, rigid machine animation and bounded audio. YELLOW: mesh/draw submission,
material/image duplication, glass/transmission, light overlap, shadows and MSAA4.
RED gates/risks: aggregate renderer memory budget, known engine cleanup bug and wholly
unvalidated phone/device lifecycle/thermal behavior. No PC visual downgrade, SDK install,
APK/AAB export, Android test or touch implementation occurred.

## 8. Collision
13 boxes (eight world solid bodies and five intentional interaction volumes) plus one
player capsule; no triangle/convex render-mesh collider generation. Floor/walls, bench
and machine base remain simple. Generous module/socket ray targets remain intentional.
New live checks verify floor contact, wall blocking, bench blocking and exact ray targets;
no render geometry simplification or unnecessary collision replacement was needed.

## 9. Telemetry regression
Five final GPU gameplay runs pass the original loop and audio/collision additions.
Two complete offline/online cycles plus a final default offline check. Online writes use
the EXISTING FastAPI code with a temporary DB/synthetic student, never production data.
Exact 15-event trace and indexes 0..14 are asserted:
game_started, terminal_interaction, mission_started, object_grabbed,
object_rotated, placement_attempt, placement_invalid, object_rotated,
placement_attempt, placement_invalid, object_rotated, placement_attempt,
placement_valid, machine_activated, mission_completed.
Required ten kinds are unchanged. All 15 UUIDs acknowledged online; duplicate replay returns
already_accepted and conflicting content returns conflict. Offline all 15 remain queued;
the game still completes. No API contract, psychological field or interpretation added.

## 10. Runtime and verification limits
All final runtime exits 0; no script/runtime ERROR; known seven-texture shutdown warning
remains in every final run. An intermediate editor-import access violation occurred during
reimport of generated captures/audio; exact cause was not established. Captures/diagnostic
data were excluded from import; two subsequent consecutive imports returned 0. It is not
presented as a proven import-engine fix or silently erased from the history.
Controls, physics, mission, animation, cue counts, audio samples and network are verified
with automated engine input and actual GPU/audio/HTTP. Human usability/listening testing
was not performed in this phase. Source-rendered captures were visually inspected.

## 11. Versions and files
- Godot 4.7.2.stable.official.ed1daf0bf; Blender sources authored with 5.2.3 LTS.
- Assets: module_bay_01_assets_v0_1, accepted hashes preserved.
- Gameplay: module_bay_01_v0_1; app: research_station_v0_1; project config version: 0.1-reference.
- Audio: original_synthetic_audio_v0_1.
- Telemetry: unchanged Phase 1A /api/v2/research-station.
- Machine-readable versions/checksums: config/reference_build.json.
- Key additions: original audio WAVs/generator, scripts/audio/bay_audio.gd,
  scripts/verification/build_metrics.gd, verification/rid_diagnostic.*, profile_reference.gd,
  this report and ANDROID_READINESS.md.
- Updated gameplay files: module_bay.gd, energy_module.gd, module_socket.gd,
  repair_machine.gd; regressions in run_probe.gd and run_checks.py.
- Logs/profiles/repeated results: verification/phase1b. Baseline sources were not deleted.
- Known limits: memory-only telemetry, current API session-create retry limitation,
  no auth, no save/resume/rebinding/touch; ESC pauses movement but not machine/network.

## 12. Data safety and scope
No StudentPlanner source or production records changed. Both production DB files retain
the starting SHA-256. Student/academic counts remain 1/4; Cognitive tables remain empty;
Research Station production sessions/events remain 0/0. Real integration tests are isolated.
No second mission/room, scoring, interventions, learner model or Android export added.

## 13. Exactly one recommended next step
Validate an engine build containing the upstream reflection-atlas cleanup fix against
this pinned reference build, including a visual comparison and repeated shutdown tests.
Stop here; do not expand Module Bay 01 into another mission.
