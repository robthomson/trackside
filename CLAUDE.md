# CLAUDE.md

Trackside: Ethos Lua race suite for the FrSky Velox VX10 (800×480 colour touch, surface radio). Phase 1 spec:
[docs/FEATURES.md](docs/FEATURES.md), then the roadmap ([docs/ROADMAP.md](docs/ROADMAP.md)).

## Key facts (checked in the VX10 sim, Ethos 26.2.0-RC1)

- Physical analogs: member 0 = `Steering`, 1 = `Throttle`, 2/3 = pots `S1`/`S2`. `source:value()` is ±1024.
- The VX10 has haptic (vibration) and a speaker: use both for race feedback.
- Lua sources only appear in pickers after enabling them in **Model → Lua**. Mixes support **Multiply**.
- A Lua source value of 1.0 shows as 100% in the mix editor (still to confirm on the channel monitor).
- All scripts share one Lua state: the suite lives in the global `trackside` table.
- Load files with absolute `SCRIPTS:/trackside/...` paths (see `trackside.BASE`).
- Registration keys are max 7 chars and must never change after release (`tsDrv`, `tsStr`, `tshome`).
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
- `lcd.invalidate()` only when something visible changed. Cache layout per window size.
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
