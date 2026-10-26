# Trackside

Race dashboard and drive aids for the **FrSky Velox VX10** surface radio (FrSky Ethos).

Phase 1 covers ABS, traction control,
steer cut throttle, corner brake, steer limit, lap timer, session timer and battery alarm. After that the
aim is to build on it, using the VX10's colour touch screen and Ethos. See [docs/ROADMAP.md](docs/ROADMAP.md).

> **Status: bootstrap.** Loads and runs on the VX10 simulator. The drive aids are pass-through stubs, so
> they don't change throttle or steering yet.

## What's in it

| Part | Ethos item | What it does |
| --- | --- | --- |
| `Drive`, `StrMul` | Lua sources | Multipliers used on Multiply mix lines for throttle and steering |
| Trackside | Widget | Race dashboard: pack, laps, aid letters, live throttle/brake/steer scope |
| Settings | Widget Configure page | BRK / DRV / SET / VOLT settings, saved per model |

## Layout

```
src/trackside/         -> deployed to SCRIPTS/trackside/ on the radio
  main.lua             registers the sources and the widget
  lib/settings.lua     settings schema (ranges/defaults) + per-model save
  lib/core.lua         drive-aid pipeline (stubs for now)
  lib/form.lua         settings form for the widget Configure page (loaded on first open)
  lib/telemetry.lua    sensor values (simulator file or real sensors)
  lib/battery.lua      cell count, cell V, %, session minimum
  widget/home.lua      Trackside dashboard
bin/sensors/          simulator sensor tool
docs/
  FEATURES.md          Phase 1 feature spec + status
  RESEARCH.md          how racers use these features, race rules on driver aids
  ROADMAP.md           phases, design principles, ideas
  SETUP.md             how to set up a model on the VX10
.vscode/               deploy tooling (same style as rfsuite / wfsuite)
```

## Development

Requirements: VS Code with the Ethos extension, Python 3 (packages install automatically on first deploy;
see `requirements.txt`).

Run tasks from the VS Code Run and Debug panel:

| Task | Does |
| --- | --- |
| Deploy & Launch [SIM] | Copies `src/trackside` into `simulators/VX10_FCC@nightly26/scripts/` and starts the Ethos simulator |
| Deploy Radio / [Fast] | Copies to a USB-connected radio (Fast = changed files only) |
| Deploy Radio + Serial Debug | Deploy, then stream `print()` output from the radio |
| Radio: Serial Debug | Serial debug only |

The simulator board is set in [.vscode/settings.json](.vscode/settings.json) (`VX10`, `FCC`, `nightly26`).

Model setup on the radio: [docs/SETUP.md](docs/SETUP.md).

### Simulated telemetry

Run **Simulator: Sensors** (or `python bin/sensors/sensors.py`) while the simulator is running. It opens a
window with sliders for link quality, TX power, pack voltage, current, ESC/motor temp and RPM, and writes
them live to `SCRIPTS/trackside.user/sim/sensors.lua` in the simulator folder. The dashboard reads that file
only when Ethos reports it's running in the simulator. Sensors are defined in
[bin/sensors/sensors.xml](bin/sensors/sensors.xml).
