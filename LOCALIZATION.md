# Research Station localization — TR / EN

One gameplay implementation uses separate UTF-8 catalogs. Turkish is the development default. The minimal startup selector offers **TÜRKÇE** and **ENGLISH**; press **L** during play to reopen it. The v0.2 launcher accepts `-Locale tr` or `-Locale en` to choose the initially focused language. Selection does not restart the room, reset recovery history, advance help levels, or emit translated event names. Mission and network clocks continue while the selector is open, as with the existing input pause.

Phase 2B adds `localization/program/{tr,en}.json` for the physical operations console and `localization/relay_polarity/{tr,en}.json` for Mission 02. Both use the same service and key-binding API. The shared mission framework retains the selected locale when moving between the two 3D missions. Mission 02's A/B and +/− markings are physical, language-independent identifiers. Its help gradient, diagnostic keys and faded tutorial policy remain equivalent in TR and EN. See `MODULE_BAY_PROGRAM.md` and `verification/phase2b/` for program-specific evidence.

Phase 2C adds `localization/coolant_pressure/{tr,en}.json`, localized three-mission console status, physical gauge/temperature readouts, evidence-only scanner output and MB03-specific help. Configuration IDs and hydraulic target values remain language-independent telemetry context. Six actual A/B/C × TR/EN playthroughs verify equivalent behavior and causal events; the terminal, gauges, scanner, AI, completion and Turkish glyph/layout checks are recorded under `verification/phase2c/`. The instruments retain readable font sizes; `bar`, `°C`, scale digits and declared equipment identifiers are intentionally invariant units/markings.

## Shared architecture

- `localization/catalog.json` declares supported locale codes, displayed language names, default locale and resource packs.
- `localization/common/tr.json` and `en.json` hold shared station controls, prompts, diagnostics, support framing and world labels.
- `localization/power_coupling/tr.json` and `en.json` hold this mission's title, objectives, terminal states, tutorial and graduated help.
- `scripts/localization/station_localization.gd` loads these catalogs into Godot `Translation` resources and exposes `text(key, parameters)`, `bind_label(node, key, parameters)`, `set_locale(code)` and `locale_changed`. It owns no intervention logic. It is composed into the scene rather than installed as a project autoload, preserving the frozen v0.1 project configuration.
- `scripts/localization/language_selector.gd` is a reusable small CanvasLayer. It builds language buttons from the catalog and calls the same service.

`bind_label` retains a semantic key and parameters, uses weak references to avoid retaining freed displays, and refreshes live Label/Label3D nodes when language changes. Nested parameters such as `{"guidance": {"key": "help.level3.power_coupling.cooling"}}` resolve at display time, so a delivered response changes language without requesting help again. Stable bindings do not reshape text every frame. No gameplay decision inspects a translated sentence.

Example for a future module:

```gdscript
localization.bind_label(screen, "mission.new_module.objective")
localization.bind_label(help_screen, "support.response", {
    "level": level,
    "guidance": {"key": guidance_key}
})
```

To add a module, add its pack name in the catalog and matching files for each supported language. To add a language, declare its code/endonym in the catalog and supply that code's JSON file for every pack. Match the complete key set and formatting placeholders; the loader rejects incomplete catalogs and duplicate keys. Gameplay scripts need no language-specific branch. A missing key is recorded in `missing_keys` and reported as an error, rather than silently displaying English. Future languages requiring additional glyphs should provide a suitable font through the service's `font` property and pass the same runtime glyph/layout checks.

## Displays and translation equivalence

The mission HUD, objective, completion, contextual prompts, carry/rotate/scan tutorials, mission terminal, scanner and physical AI station all resolve keys. Physical scanner acquisition/result state persists across switches. Help levels select the same key in both languages: L1 strategy/inspection, L2 relevant subsystem, L3 immediate dependency and manual action. The early-request policy remains the same in both languages. No translated help response operates the machine.

Modeled text meshes for station identity, bay name, safety signs, bench/control/machine labels and v0.2 device names are hidden only in the running v0.2 scene and replaced by localized world-space labels. The GLBs themselves are untouched. Terminal text uses four concise lines; scanner diagnostics use explicit short lines. Font sizes/pixel sizes remain unchanged rather than shrinking Turkish text. Runtime checks measure every terminal, diagnostic and help variant against its physical screen dimensions.

Intentionally language-independent markings: **EDUALYN**, **RS**, **DS-01**, **E-A**, **POWER A**, **SERVICE**, **A-01**, **R-01**, **C-01**, **R-02**, bay number **01**, keyboard/mouse symbols, and technical acronyms **MOBILE / FPS**. POWER A and SERVICE remain the same physical interface identifiers in both languages; their contextual explanations are localized. `DİL / LANGUAGE` is intentionally bilingual. Language buttons display each language's own name. The frozen v0.1 experience remains independently accessible and unchanged; bilingual support applies to the active v0.2 intervention and reusable infrastructure.

## Encoding and telemetry

JSON and GDScript resources use UTF-8. The launcher uses UTF-8 with BOM for Windows PowerShell compatibility with its Turkish filesystem path. The service explicitly binds Godot's bundled fallback font to HUD/world displays. Runtime font coverage and screenshots verify `ç Ç ğ Ğ ı I i İ ö Ö ş Ş ü Ü`; resources contain the intended Unicode code points rather than repaired mojibake.

Telemetry event names, state IDs, object IDs, action signatures, failure reasons, help levels and policy thresholds stay language-independent. Event context adds `locale: tr|en`. Diagnostic payloads carry stable `diagnostic.*` keys, and help payloads carry `guidance_key`, never a localized sentence. UI selection itself creates no behavioral event. This preserves one event vocabulary and one intervention implementation.

## Verification

```powershell
..\StudentPlanner\.venv\Scripts\python.exe -B verification\localization\run_localization_checks.py
..\StudentPlanner\.venv\Scripts\python.exe -B verification\v02\run_cascade_checks.py --mode both
```

The bilingual verifier runs actual Godot Vulkan/Mobile sessions in TR and EN. It selects buttons through pointer input, reopens with L, switches at startup, after guidance, after scanning and after completion, checks state preservation, performs physical interaction/recovery through completion, measures screen fit and verifies every Turkish glyph. It compares the complete raw sequences after normalizing only timestamps, UUID references and locale; event names and observable metadata must otherwise match exactly. Reports, traces and TR/EN screenshots live in `verification/localization/`.

The broader regression verifier checks the actual 45-second stall parameter, repetition, all help dependencies, original audio, offline completion and the existing API against a temporary synthetic database. Production rows/database hashes and the 207-entry frozen archive are checked. Automated aiming is test setup, not human usability evidence. Known Windows certificate-store and upstream seven Texture RID shutdown messages remain documented and untouched.
