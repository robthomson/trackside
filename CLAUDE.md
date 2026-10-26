# CLAUDE.md

Trackside: Ethos Lua race suite for the FrSky Velox VX10 (800×480 colour touch, surface radio). Phase 1 spec:
[docs/FEATURES.md](docs/FEATURES.md), then the roadmap ([docs/ROADMAP.md](docs/ROADMAP.md)).

## Key facts (checked in the VX10 sim, Ethos 26.2.0-RC1)

- Physical analogs: member 0 = `Steering`, 1 = `Throttle`, 2/3 = pots `S1`/`S2`. `source:value()` is ±1024.
- The VX10 has haptic (vibration) and a speaker: use both for race feedback.
- Lua sources only appear in pickers after enabling them in **Model → Lua**. Mixes support **Multiply**.
- The mixer reads a Lua source's raw value with 1024 = 100%. A value of 1.00 with 2 decimals counts as ~9.8%.
  So the aid sources send `round(multiplier * 1024)` with `decimals(0)` (checked on the channel monitor:
  throttle 50% x 1.0 = 50%, x 0.5 = 25%).
- All scripts share one Lua state: the suite lives in the global `trackside` table.
- Load files with absolute `SCRIPTS:/trackside/...` paths (see `trackside.BASE`).
- Registration keys are max 7 chars and must never change after release (`tsDrv`, `tsStr`, `tshome`). Telemetry sensor appIds `0x5E10` ("Trackside") and `0x5E11` ("Pack Fuel") are fixed too
  (lib/diysensor.lua creates them).
- A missing Lua source counts as 0 in a Multiply line (dead car). The Multiply lines therefore use LS1
  (`Trackside sensor > 0`) as Active condition. main.lua creates the DIY sensor and pushes 1 every second;
  Ethos marks it lost ~4 s after the last value. Mix Active conditions can't pick a Lua source directly.
- Spoken audio: add phrases to `bin/audio/phrases.json`, run `python bin/audio/generate.py` (Google TTS; the
  credentials are in the environment). `system.playNumber(value, unit, decimals)` takes the real value
  (3.4, not 340) on Ethos 26.2.
- Settings are per model in `SCRIPTS:/trackside.user/models/`, outside the deployed folder (deploy mirrors
  `src/trackside` and deletes stale files).

## Conventions

- Settings live in one schema ([lib/settings.lua](src/trackside/lib/settings.lua)); the form is generated from it.
- Colours: surfaces from `lcd.themeColor()`, status colours fixed (see ROADMAP design principles).
- Widget header row only in full screen.
- Own look and own wording.
- Never name other radio brands, firmwares or their products/scripts anywhere in the repo (code, docs,
  commit messages, links). Describe features on their own terms.

## Performance (Ethos radios are CPU/RAM constrained; same rules as rfsuite/wfsuite)

- Treat `wakeup`, `paint` and source callbacks as hot paths: no new tables, closures or strings per tick.
  Reuse tables; quantise values and only format text when the shown value changes.
- Widget redraws: `wakeup` returns early when `lcd.isVisible()` is false (as the rfsuite dashboard does);
  invalidate only the changed box rectangles with `lcd.invalidate(x, y, w, h)`, never the whole window,
  except once when the screen comes back into view; hold redraws while a touch slide is in progress.
  Cache layout per window size. `trackside.DEBUG_PAINT = true` logs paints per second.
- Core modules load eagerly in main.lua; UI-only code (the settings form) loads on first use.
- `main.lua` prints `[trackside] boot <s>, RAM <KB>`; check it after changes. Watch
  `system.getInstructionsUsage()` if a callback does heavy work (the script is killed at 100).

## Testing in the simulator

- VS Code: run **Deploy & Launch [SIM]**.
- Headless, scripted: `ethos-tools/simulation/run_wasm.js --serve --root-directory simulators/VX10_FCC@nightly26`
  with a VX10 build (`https://ethos.studio1247.com/nightly26/VX10_FCC.js` and `.wasm`). Lua errors and
  `print` show in `run_wasm.js log`, not on screen. In the sim, `analog I V` takes percent (100 = full).
- Fake telemetry: `bin/sensors/sensors.py` writes `SCRIPTS/trackside.user/sim/sensors.lua`; read by
  `lib/telemetry.lua` only when `system.getVersion().simulation` is true.
