# Features and goals

What Trackside does in Phase 1 (the first goal), and how far along each part is. Later phases: [ROADMAP.md](ROADMAP.md).

Status key: ☐ not started · ◐ scaffolded · ☑ done

## How it fits into Ethos

| Part | How it works | Status |
| --- | --- | --- |
| Drive aids output | Lua sources `Throttle Aid` (`tsDrv`) and `Steer Aid` (`tsStr`), enabled under Model → Lua | ◐ |
| Mixing | Stick line (Add) + Lua source line (Multiply) per channel; scaling measured exact in the VX10 sim | ☑ |
| Fail-safe | Trackside creates a DIY telemetry sensor `Trackside` (appId 0x5E10) and sends 1 every second. Logic switch LS1 (`Trackside > 0`) is the Active condition of both Multiply lines. Measured in the sim: scripts missing → stick 1:1 from boot; script stops → stick 1:1 after ~5 s; Lua error → sources send ×1.0 at once. The sensor and LS1 stay in the model when the scripts are missing | ☑ |
| Inputs | Throttle Input / Steering Input source pickers (default: VX10 physical `Throttle` / `Steering`), so no feedback loop through the mixer | ☑ |
| Dashboard | Widget `Trackside` (`tshome`) on any layout; header row only in full screen | ◐ |
| Settings | System tool `Trackside`: tile menu (Settings, Diagnostics), one page per group; toolbar → Settings on the dashboard opens it | ☑ |
| Aids Switch | Drive aids page, switch picker (switch positions, logic switches). Off = every aid ×1.0, flags cleared, letters struck through. Not set = always on. Measured: SA↑ ×0.5 → 25%, SA- / SA↓ → 50% (stick 1:1). LS1 is still needed for a missing script | ☑ |
| Check setup | Tool page: sensor and aid status, Aid Test (both aids ×0.5 while open, max 60 s) with a per-channel verdict. Verified in the sim on a good setup, a missing line and Operation Add | ☑ |
| Storage | Per-model file `SCRIPTS:/trackside.user/models/<model>.lua` | ☑ |

## Drive-aid pipeline

Fixed order: **Traction Control → Steer Cut Throttle → Corner Brake → ABS → Steer Limit**.
Throttle/steer come from the physical sticks (no mixer feedback loop).
The output is a multiplier from 0 to 1 (clamped), so an aid can only reduce a channel. A missing Lua source
counts as 0 in a Multiply line, which is why the lines need the LS1 safety switch (see SETUP.md).

| Aid | Letter | Behaviour | Status |
| --- | --- | --- | --- |
| ABS | A | Pulses brake past ABS Trigger between full brake and Brake Floor | ☑ |
| Traction Control | T | Rise-only throttle slew limit; release is instant. 0% = 0.1 s, 100% = 1.0 s zero to full | ☑ |
| Steer Cut Throttle | S | Throttle × (1 − setting × steering × 0.6) | ☑ |
| Corner Brake | C | Brake × (1 − setting × steering × 0.6); Corner ABS Hz / Corner Delay adjust ABS from steering | ☑ |
| Steer Limit | D | Steering shrinks from Steer Limit Start to full throttle, up to 60% at 100% | ☑ |

Measured on the channel outputs in the VX10 sim (lib/core.lua):

- Traction 50% (0.55 s): 25/50/75/100% at 131/264/396/530 ms. While the trigger rests, Throttle Aid waits at the
  rise allowed in one update (×0.055 at 50%), because the mixer applies a new stick ~1 update before the source
  catches up; without this a launch showed one frame of full throttle.
- Steer Cut 100%: full lock → 40%, half lock → 70%. Corner Brake 50%: full lock → 70% brake, half → 85%.
- Steer Limit 100% from 50%: full throttle → 40% steering, 75% → 70%, under 50% untouched.
- ABS Static 5 Hz, floor 40%, delay 50 ms: 152 ms full / 50 ms at 40% (±20 ms per pulse, the update rate).
  Dynamic to 10 Hz: full pull 47/53 ms at floor 24%; 65% brake ~7.5 Hz at floor 32%. Corner ABS Hz 5 at full lock: 5 → 10 Hz.

A letter lights only while its aid changes the output; armed aids show white, OFF ones grey.

### ABS detail

- **OFF**: no ABS. **Static**: fixed ABS Frequency and Brake Floor. **Dynamic**: as brake deepens, pulse rate moves toward Dynamic Target and floor eases toward ~60% of Brake Floor at full pull; optional Dynamic Min Delay moves the hold toward its value.
- **Pulse Delay** = baseline full-brake hold inside each cycle. 0 ms = maximum chatter (not a lock).
  Each cycle is full brake for half the period plus the hold (capped at 85% of the period), then Brake Floor.
- **Dynamic Min Delay** (hard brake) and **Corner Delay** (steering) are independent; both start from Pulse Delay and move toward their own value. If both apply, the **shorter** hold wins (they don't stack).
- **Corner ABS Hz** adds 0–7 Hz to the base rate from steering. Needs ABS Mode ≠ OFF; doesn't run ABS alone.
- ABS starts only when brake passes **ABS Trigger**. **Brake Direction** (Negative/Positive) picks which trigger side is brake.
- **Timing limit:** the mixer only sees a new aid value when Ethos runs the source's `wakeup`. In the VX10
  sim that's every 15–52 ms (about 20 ms on average). Measured square waves came through at 5 and 10 Hz;
  16.7 Hz came out as 15.9 Hz and 33 Hz as about 19 Hz, with uneven holds. So ABS Frequency above about
  10–15 Hz and Pulse Delay in 5 ms steps can't be delivered as set. Check the rate on a real VX10 before
  fixing the ranges.

## Settings (all in [settings.lua](../src/trackside/lib/settings.lua))

| Page | Setting | Range / step | Default |
| --- | --- | --- | --- |
| Brake / ABS | ABS Mode | OFF / Static / Dynamic | OFF |
| Brake / ABS | ABS Frequency | 5–33 Hz, 1 | 5 Hz |
| Brake / ABS | Brake Floor | 0–100%, 5 | 40% |
| Brake / ABS | Pulse Delay | 0–100 ms, 5 | 50 ms |
| Brake / ABS | ABS Trigger | 5–100%, 5 | 30% |
| Brake / ABS | Dynamic Target | 5–33 Hz, 1 | 6 Hz |
| Brake / ABS | Dynamic Min Delay | OFF, 5–100 ms, 5 | OFF |
| Drive aids | Aids Switch | any switch position / logic switch; --- = always on | --- |
| Drive aids | Traction Control | OFF, 0–100%, 5 | OFF |
| Drive aids | Steer Cut Throttle | OFF, 0–100%, 5 | OFF |
| Drive aids | Corner Brake | OFF, 0–100%, 5 | OFF |
| Drive aids | Corner ABS Hz | OFF, 0–7 Hz, 1 | OFF |
| Drive aids | Corner Delay | OFF, 5–100 ms, 5 | OFF |
| Drive aids | Steer Limit | OFF, 0–100%, 5 | OFF |
| Drive aids | Steer Limit Start | 0–100%, 5 | 50% |
| Inputs | Throttle Input / Steering Input | any source | VX10 Throttle / Steering |
| Inputs | Throttle Channel / Steering Channel | any channel (used by Check setup) | CH2 / CH1 |
| Timer & laps | Timer | 1–45 min | 5 min |
| Timer & laps | Timer Switch | switch position / logic switch | — |
| Timer & laps | Show Timer | OFF / ON (footer: timer vs A T S C D) | OFF |
| Inputs | Brake Direction | Negative / Positive | Negative |
| Inputs | Graph Direction | Normal / Reversed (scope only) | Normal |
| Timer & laps | Lap Switch | switch position / logic switch | — |
| Timer & laps | Lap Haptic | OFF / ON | ON |
| Timer & laps | Lap Callout | OFF / ON (speaks each lap time) | ON |
| Timer & laps | Throttle Start Lap | OFF / ON | OFF |
| Battery | Battery Type | LiPo (4.20 V full) / LiHV (4.35 V full); empty ≈ 3.50 V | LiPo |
| Battery | Cells | Auto, 1S–6S (Auto locks on first valid pack, unlocks after ~5 s telemetry loss) | Auto |
| Battery | Voltage Alarm | OFF / ON | OFF |
| Battery | Alarm Cell Voltage | 3.20–3.90 V, 0.05 | 3.50 V |
| Battery | Pack Capacity | OFF, 500–10000 mAh, 100 (fuel by mAh used) | OFF |
| Battery | Fuel Callouts | OFF / ON (spoken at 50, 30, 20, 10%) | ON |

Suggested first-session map: ABS Static, 12 Hz, Floor 40%, Pulse 50 ms, Trigger 30%, drive aids OFF, Timer 5 min.

## Dashboard

| Area | Content | Status |
| --- | --- | --- |
| Header (full screen only) | Model name, LQ (0–100), SNR, TX voltage, TX power mW | ◐ |
| Battery | Pack voltage + cell count, cell V, battery %, min pack V, state (OFF/NOTEL/OK/LOW/ALARM) | ◐ |
| Laps | Current lap (CUR), last lap (L1), best (green 3 s after a new best), lap count; reset bar along CUR | ☑ |
| Footer | A T S C D letters (own colour = working, white = armed, grey = OFF, struck through = Aids Switch off), or session countdown when Show Timer = ON (grey paused, red blinking when expired) | ☑ |
| Battery highlight | PACK value amber on LOW; box flashes red (0.5 s) on ALARM | ☑ |
| Toolbar | Swipe up (or long PAGE) → bar with Laps (lap view: LAPS / BEST / AVG / TOT + every lap, best green), Start/Pause timer, Reset (asks first), Settings (Trackside tool via `system.openPage` and the tool's handle, Ethos 26.1+). Any button, swipe down, a tap above, RTN or 10 s closes it. Wheel + ENTER work too. Vertical swipes only, so screen swipes still work | ☑ |

## Live scope bar

Fill from centre = processed throttle/brake (green throttle, red brake); marker = brake floor (ABS active) or
trigger depth (ABS armed); raw-stick marker when aids are shaping it; tick under the bar = steering
(Graph Direction flips only this); ABS ON/OFF + letters. Status: ◐ (fill + steer tick on the dashboard).

## Laps & timer

- Lap from Lap Switch; minimum lap 3 s (debounce). Throttle Start Lap starts the clock on throttle. ☑
- Lap Haptic on each new lap; Lap Callout speaks the time ("Best lap" first on a new best). ☑
- Long hold (1.2 s, progress bar along CUR) on the lap switch resets the session. The press that starts the hold
  is stamped as a lap first (laps must be timed at the press); the reset then clears it. ☑
- Timer: short press start/pause/restart; long hold 1.2 s resets. "One minute", "Time up", then haptic every 10 s
  for a minute. ☑
- A lap view with every lap + AVG / TOT / LAPS / BEST: toolbar → Laps. ☑

Measured in the sim (lib/laps.lua): presses 4.9 / 4.2 s apart → "4.8 seconds", "Best lap, 4.2 seconds"; a press
2.3 s after a lap ignored; next lap timed from the last counted lap (8.1 s); 1-minute countdown → "Time up" at
0:00 and buzzes at +10, +20, +30, +40 s.

## Fuel

Best source wins: a real fuel sensor (`Fuel`, `Bat%`, `Batt%`) → mAh used with Pack Capacity (start % from resting
voltage) → resting voltage on a LiPo/LiHV curve. The voltage estimate only reads after ≥1 s off throttle, holds
on throttle, never rises once driven, and falls ≤0.5 %/s. A new pack = voltage rising before the first drive, or
>5 s without pack voltage. mAh and voltage results are published as DIY sensor `Pack Fuel` (appId 0x5E11, %).
Measured in the sim (lib/fuel.lua): sag at 80% throttle ignored, resting 4.05 V/cell → 83%, mAh 1000/5000 → 75%. ☑

## Spoken alerts

Phrases: `bin/audio/phrases.json` → `python bin/audio/generate.py` (Google Text-to-Speech, or `--engine sapi`
offline) → 16 kHz mono WAVs in `src/trackside/audio/en/{default,us,gb}`. Played by lib/audio.lua: user file in
`trackside.user/audio/`, then the radio voice, then en/default. Numbers via `system.playNumber` (real value,
decimals = digits spoken). Checked in the sim log (lib/alerts.lua):

| Alert | When | Status |
| --- | --- | --- |
| "Fuel N percent" | fuel passes 50/30/20/10, once per pack (Fuel Callouts, default ON) | ☑ |
| "Battery low" + cell V + haptic | Voltage Alarm, ≥5 s of resting readings under the level; repeats 30 s | ☑ |
| "Aid test on/off" | Aid Test starts, ends or times out | ☑ |
| "Drive aids on/off" + buzz | Aids Switch flipped (not at start-up) | ☑ |
| "Drive aids off. Trackside error." + haptic | a Lua error released the aids | ☑ |
| Lap time / "Best lap" + buzz | each lap (Lap Callout, Lap Haptic) | ☑ |
| "One minute" / "Time up" + haptic | countdown at 1:00 and 0:00 | ☑ |
| "Laps reset" / "Timer reset" | long hold on the lap / timer switch | ☑ |

## Battery alarm

States: OFF (alarm off) · NOTEL (no pack/cells yet) · OK · LOW (under threshold, ~5 s hold not done) · ALARM (haptic ~3 s on / ~30 s quiet).
Small hysteresis so it doesn't chatter on the threshold.
