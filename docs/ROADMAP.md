# Roadmap

Goal: deliver the Phase 1 feature set first, then build on it with what Ethos and the
VX10 offer: 800×480 colour touch screen, source pickers, spoken audio, per-model files, and the
rfsuite dashboard engine.

## Design principles

- **Our own design.** Our own look, layout and wording throughout.
- **Colour carries meaning.** The VX10 has a colour screen: throttle green, brake red, one colour per aid
  (A red, T green, S amber, C violet, D blue), battery state colours. Status colours stay fixed across themes.
- **Honour the Ethos theme.** Surfaces, text and dimmed elements come from `lcd.themeColor()` (light and dark),
  like rfsuite and wfsuite. Checked in the VX10 sim with both themes.
- **Full screen vs windowed.** The header row (model, link, TX) only shows when the widget fills the screen;
  in a windowed layout Ethos already shows it (same rule as the rfsuite dashboard).
- **Self-contained.** One install: the sources, the dashboard widget and the `Trackside` system tool, which holds all settings.
- **Glanceable while driving.** Big numbers, few of them, readable at arm's length outdoors.

## Phase 1 — core feature set

Spec and checklist: [FEATURES.md](FEATURES.md).

1. ~~Drive-aid core~~ Done in the sim: all five aids, measured on the channel outputs. The ~20 ms Lua update
   limits ABS to about 10–15 Hz; check the rate on a real VX10 and cap the range if needed.
2. ~~Verify multiplier scale~~ Done: sources output on the mixer's 1024 = 100% scale; 0.5 halves the channel.
3. ~~Laps + session timer~~ Done: debounce, reset hold, haptics, spoken lap times, lap view (toolbar).
4. ~~Battery~~ Done: cells, %, fuel estimate (Pack Fuel sensor), spoken alarm with haptic, PACK amber / flashing red.
5. **Telemetry** for the top bar: LQ, SNR, TX voltage, TX power (ELRS and FrSky names).
6. ~~Dashboard~~ Done: all boxes, timer footer, new-best flash, PACK alarm highlight, lap view.
7. ~~Settings from the dashboard~~ Done: swipe up for the toolbar, then Settings. Later: a live scope bar on
   the Brake / ABS, Drive aids and Inputs pages.
8. Bench and track test on a real VX10.

## Phase 2 — dashboard engine

Port the rfsuite dashboard ([rotorflight-lua-ethos-suite/src/rfsuite/widgets/dashboard](../../rotorflight-lua-ethos-suite/src/rfsuite/widgets/dashboard)):
grid layout, typed objects (text, gauge, dial, time, image), themes, instruction-budget pacing.
Map its preflight / inflight / postflight states to **pre-race / racing / post-race**:

- Pre-race: pack, cells, link, settings summary, "ready" checks.
- Racing: big lap time, delta to best, pack, aid letters, timer.
- Post-race: lap table, best/avg, consistency, min pack voltage.

Ship a few themes (clean, high-contrast for sunlight, minimal).

## Phase 3 — new features

Pick by value once Phase 1 is done:

- **Spoken callouts**: lap time, delta to best, "best lap", laps remaining, pack voltage on request.
- **Lap delta and pace**: live +/− vs best, predicted heat result, consistency score.
- **Session history**: save every session per model (laps, best, avg, min pack) and browse it on the radio.
- **Touch tuning**: drag ABS / floor / trigger directly on the scope graph; presets per track/surface (dirt, carpet, asphalt) one tap away.
- **Live tuning graph**: rolling trace of raw vs processed throttle/brake/steer to see what the aids did on the last straight.
- **Drive modes integration**: switch aid presets with Ethos drive modes or a switch.
- **ESC telemetry** (where available): RPM, temp, current on the dash; traction control using wheel/motor RPM instead of throttle slew only.
- **Gyro-aware aids**: the source picker accepts Gyro sources; use them for steering assist if the VX10 or receiver provides them.
- **Translations** via the rfsuite i18n tooling.

## Research takeaways

Full report: [RESEARCH.md](RESEARCH.md). What it changes for us:

- **Race-legal vs practice.** ROAR 8.2.7, EFRA 8.6.2 and BRCA §14 ban sensor-driven aids (traction control
  devices, gyro steering aids, sensors adjusting the car in motion). Time-based shaping with no sensor input
  (pulsed braking, throttle ramps, curves) is widely sold and tolerated. Tag every aid as **race-legal** or
  **practice only** (anything that reads telemetry), and add an **event mode** that locks out practice-only aids,
  plus a scrutineering screen showing what's active.
- **Telemetry can be restricted** (EFRA electric 4.4). Event mode should also offer "telemetry off".
- **Neutral names** for the aids (e.g. "Brake Pulse", "Throttle Ramp") rather than "ABS" / "traction control".
- **Audio and haptic first while driving.** Drivers rarely look at the screen mid-race; lap times, best lap and alarms
  should be spoken, beeped or felt. The screen matters most in the pits (lap list, logs, tuning).
- **Ethos already has some surface ABS, a brake mixer and a steering mix**, so Trackside has to add value on top.
- The VX10 has haptic as well as a speaker: use vibration and audio together for laps, timer and alarms.

## Open questions

- Lua source `wakeup` rate on the VX10 (drives max ABS frequency).
- ~~Whether a widget can open a settings page~~ Yes: `system.openPage({system = handle})` (Ethos 26.1+), with the handle
  `system.registerSystemTool()` returns.
- Sensor names to look up for LQ / TX power across ELRS, FrSky ACCESS/ACCST and others.
