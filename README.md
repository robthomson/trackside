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
| Throttle Aid, Steer Aid | Lua sources | Multipliers used on Multiply mix lines for throttle and steering |
| Pack Fuel | Telemetry sensor (created automatically) | Fuel % from mAh used or resting voltage, when the car has no fuel sensor |
| Trackside | Telemetry sensor (created automatically) | Reads 1 while Trackside runs; logic switch LS1 uses it to turn the Multiply lines off if Trackside stops |
| Trackside | Widget | Race dashboard: pack, laps, aid letters, live throttle/brake/steer scope |
| Trackside | System tool | Settings (Brake / ABS, Drive aids, Inputs, Timer & laps, Battery), saved per model, and Check setup with the Aid Test |

## Layout

```
src/trackside/         -> deployed to SCRIPTS/trackside/ on the radio
  main.lua             registers the sources, the widget and the system tool
  lib/settings.lua     settings schema (ranges/defaults) + per-model save
  lib/core.lua         drive-aid pipeline (stubs for now)
  lib/form.lua         settings fields generated from the schema (loaded on first use)
  tool/app.lua         Trackside system tool: menu, settings pages, Check setup
  tool/gfx/            tool icons (made by bin/icons/make_icons.py)
  lib/telemetry.lua    sensor values (simulator file or real sensors)
  lib/battery.lua      cell count, cell V, %, session minimum
  lib/fuel.lua         fuel %: fuel sensor, else mAh used, else resting voltage
  lib/diysensor.lua    telemetry sensors Trackside creates (Trackside, Pack Fuel)
  lib/audio.lua        spoken phrases (user file, radio voice, en/default) and numbers
  lib/alerts.lua       voltage alarm, fuel callouts, Aid Test announcements
  audio/               generated WAVs (bin/audio/generate.py from bin/audio/phrases.json)
  widget/home.lua      Trackside dashboard
bin/sensors/          simulator sensor tool
bin/manual/           builds the setup guide PDF
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

**Setup guide (PDF, with screenshots):** [docs/Trackside-Setup-Guide.pdf](docs/Trackside-Setup-Guide.pdf).
Short text version: [docs/SETUP.md](docs/SETUP.md). Rebuild the PDF with `python bin/manual/build_manual.py`
(screenshots in `docs/manual/images`, captured from the VX10 simulator).

### Simulated telemetry

Run **Simulator: Sensors** (or `python bin/sensors/sensors.py`) while the simulator is running. It opens a
window with sliders for link quality, TX power, pack voltage, current, ESC/motor temp and RPM, and writes
them live to `SCRIPTS/trackside.user/sim/sensors.lua` in the simulator folder. The dashboard reads that file
only when Ethos reports it's running in the simulator. Sensors are defined in
[bin/sensors/sensors.xml](bin/sensors/sensors.xml).
