# Android Readiness — Module Bay 01 Reference Build v0.1
Audit only, 2026-11-12. No Android export, SDK setup, touch controls or PC-quality reduction.
Evidence: actual Windows Vulkan/Forward Mobile runs on AMD Radeon(TM) Graphics.
These are engineering screening classifications, NOT measured phone performance or approval for release.

| Asset / feature | Classification | Observed state and implication |
|---|---|---|
| Triangle budget | GREEN | 79,244 source/runtime triangles in one compact room; no geometry expansion in Phase 1B. Triangle count alone is not a mobile guarantee. |
| Mesh/node submission | YELLOW | 438 MeshInstance3D nodes. Fixed-camera monitor reports 318 idle / 569 active draw calls including renderer passes; submission/material/state overhead merits batching review before Android. |
| Source textures | GREEN | Four original 128x128 roughness maps; 18 image entries across seven GLBs. No large room-image textures or 4K maps. |
| Repeated texture references | YELLOW | Small maps are repeated/extracted across GLBs. Deduplication should be evaluated, but current files were retained to preserve the accepted build. |
| PBR materials | GREEN / YELLOW | 13 semantic source materials are straightforward metal/roughness/emission. Runtime resource count reaches 52 after the full mission because assets/overrides have separate instances. Sharing compatible materials is a future submission optimization. |
| Transparency / glass | YELLOW | MAT_GLASS uses alpha BLEND and KHR_materials_transmission in the room GLB. Two small airlock panes have bounded coverage; transmission/overdraw behavior must be checked on target devices. No large transparent room shell. |
| Dynamic lighting | YELLOW | 7 Light3D nodes: 3 facility omnis, 1 task spotlight, 1 machine light, 2 socket lights. Six have nonzero energy at the complete-state snapshot; pulses may overlap. Android overlap/fragment cost needs device profiling. |
| Shadows | YELLOW | Exactly 1 shadow-casting task spotlight. Keep a target shadow resolution/distance budget; no PC shadow settings were lowered here. |
| Reflection / sky | YELLOW | One local box-projected ReflectionProbe plus procedural sky preserve accepted metal response. Capture/atlas cost and resolution require mobile budgeting. |
| Reflection-atlas cleanup | RED release gate | Godot 4.7.2 reproduces the upstream seven-Texture-RID leak. Resolve/validate an upstream-patched engine before mobile release rather than deleting the accepted reflections. |
| Aggregate texture memory | RED budget risk | Desktop engine monitor peaks around 392.4 million bytes (~374.2 MiB), including renderer allocations; this is NOT just the small asset maps or a physical-VRAM measurement. Cannot assume suitability for lower-memory Android. Device memory budgets and allocation breakdown remain unmeasured. |
| MSAA 4x at 1280x720 | YELLOW | Accepted PC setting retained. Multisample color/depth bandwidth and attachment memory need device-specific evaluation. No unsupported phone FPS prediction is made. |
| Emissive indicators | GREEN | Small emissive surfaces, no bloom-heavy effects or ray tracing. Pulse materials are reused rather than recreated per feedback event. |
| Machine animation | GREEN | Two small rigid Node3D mechanisms and a few tweens; no skinned crowds, deforming physics or CPU geometry generation. |
| Collision | GREEN | 13 BoxShape3D + 1 CapsuleShape3D in the full scene. No ConcavePolygonShape3D, ConvexPolygonShape3D or automatically generated render-mesh collision. |
| Audio | GREEN | Seven original short mono 48 kHz cues (~546 KiB source PCM), cached streams and seven reused positional players; one seamless 2-second hum loop. No per-event resource loading. |
| Offline/networking | YELLOW release gate | Serialized HTTP is nonblocking, but the queue is in memory and lost on exit. Final Android durability is deliberately not implemented. |
| Device controls / thermal / lifecycle | RED unvalidated | No Android run, sustained thermal test, touch design, pause/resume or background/restart test. Windows Mobile-renderer success does not establish Android readiness. |

## What was preserved
All seven accepted GLBs and seven Blender sources retain their Phase 1B starting SHA-256.
Lighting layout, PBR assets, room geometry, perspective gameplay, resolution and MSAA remain intact.
No PC assets were downgraded and no Android build was produced.

## Profiling interpretation
Controlled fixed-camera audio-off/audio-on profiles use four-second idle and active windows after
warmup, with input disabled in the diagnostic only and no screenshots. The synthetic active
benchmark turns the machine on without docking, so it has five active lights; the full gameplay
test has six after docking. See REFERENCE_BUILD.md for exact numbers and JSON paths.
The six-capture gameplay test includes synchronous GPU readback/PNG-save stalls; its instantaneous
minimum must not be presented as a sustained gameplay FPS floor. Engine draw/memory monitors
can be delayed and do not isolate physical VRAM, overdraw, GPU timing or phone behavior.
