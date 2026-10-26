# Features and goals

What Trackside does in Phase 1 (the first goal), and how far along each part is. Later phases: [ROADMAP.md](ROADMAP.md).

Status key: ☐ not started · ◐ scaffolded · ☑ done

## How it fits into Ethos

| Part | How it works | Status |
| --- | --- | --- |
| Drive aids output | Lua sources `Throttle Aid` (`tsDrv`) and `Steer Aid` (`tsStr`), enabled under Model → Lua | ◐ |
| Mixing | Stick line (Add) + Lua source line (Multiply) per channel; confirmed in the VX10 sim | ☑ |
| Inputs | Throttle Input / Steering Input source pickers (default: VX10 physical `Throttle` / `Steering`), so no feedback loop through the mixer | ☑ |
| Dashboard | Widget `Trackside` (`tshome`) on any layout; header row only in full screen | ◐ |
| Settings | Widget Configure page; opening settings straight from the dashboard: ☐ | ◐ |
| Storage | Per-model file `SCRIPTS:/trackside.user/models/<model>.lua` | ☑ |

## Drive-aid pipeline

Fixed order: **Traction Control → Steer Cut Throttle → Corner Brake → ABS → Steer Limit**.
Throttle/steer come from the physical sticks (no mixer feedback loop).
The output is a multiplier; if Lua stops, the raw stick line still drives the car.

| Aid | Letter | Behaviour | Status |
| --- | --- | --- | --- |
| ABS | A | Pulses brake past ABS Trigger between full brake and Brake Floor | ☐ |
| Traction Control | T | Rise-only throttle slew limit; release is instant. 100% = moderate launch, not a crawl | ☐ |
| Steer Cut Throttle | S | Less throttle the more you steer | ☐ |
| Corner Brake | C | Less brake while steered; Corner ABS Hz / Corner Delay adjust ABS from steering | ☐ |
| Steer Limit | D | Shrinks steering travel once throttle passes Steer Limit Start; capped at ~60% shrink at 100% | ☐ |

### ABS detail

- **OFF**: no ABS. **STATIC**: fixed ABS Frequency and Brake Floor. **DYNAMIC**: as brake deepens, pulse rate moves toward DYN Target and floor eases toward ~60% of Brake Floor at full pull; optional DYN Min Delay moves the hold toward its value.
- **Pulse Delay** = baseline full-brake hold inside each cycle. 0 ms = maximum chatter (not a lock).
- **DYN Min Delay** (hard brake) and **Corner Delay** (steering) are independent; both start from Pulse Delay and move toward their own value. If both apply, the **shorter** hold wins (they don't stack).
- **Corner ABS Hz** adds 0–7 Hz to the base rate from steering. Needs ABS Mode ≠ OFF; doesn't run ABS alone.
- ABS starts only when brake passes **ABS Trigger**. **Brake Direction** (NEG/POS) picks which trigger side is brake.

## Settings (all in [settings.lua](../src/trackside/lib/settings.lua))

| Tab | Setting | Range / step | Default |
| --- | --- | --- | --- |
| BRK | ABS Mode | OFF / STATIC / DYNAMIC | OFF |
| BRK | ABS Frequency | 5–33 Hz, 1 | 5 Hz |
| BRK | Brake Floor | 0–100%, 5 | 40% |
| BRK | Pulse Delay | 0–100 ms, 5 | 50 ms |
| BRK | ABS Trigger | 5–100%, 5 | 30% |
| BRK | DYN Target | 5–33 Hz, 1 | 6 Hz |
| BRK | DYN Min Delay | OFF, 5–100 ms, 5 | OFF |
| DRV | Traction Control | OFF, 0–100%, 5 | OFF |
| DRV | Steer Cut Throttle | OFF, 0–100%, 5 | OFF |
| DRV | Corner Brake | OFF, 0–100%, 5 | OFF |
| DRV | Corner ABS Hz | OFF, 0–7 Hz, 1 | OFF |
| DRV | Corner Delay | OFF, 5–100 ms, 5 | OFF |
| DRV | Steer Limit | OFF, 0–100%, 5 | OFF |
| DRV | Steer Limit Start | 0–100%, 5 | 50% |
| SET | Throttle Input / Steering Input | any source | VX10 Throttle / Steering |
| SET | Timer | 1–45 min | 5 min |
| SET | Timer Switch | any source | — |
| SET | Show Timer | OFF / ON (footer: timer vs A T S C D) | OFF |
| SET | Brake Direction | NEG / POS | NEG |
| SET | Graph Direction | NOR / REV (scope only) | NOR |
| SET | Lap Switch | any source | — |
| SET | Laptimer Haptic | OFF / ON | ON |
| SET | Throttle Start Lap | OFF / ON | OFF |
| VOLT | Battery Type | LiPo (4.20 V full) / LiHV (4.35 V full); empty ≈ 3.50 V | LiPo |
| VOLT | Cells | Auto, 1S–6S (Auto locks on first valid pack, unlocks after ~5 s telemetry loss) | Auto |
| VOLT | Volt Alarm | OFF / ON | OFF |
| VOLT | Alarm Cell Voltage | 3.20–3.90 V, 0.05 | 3.50 V |

Suggested first-session map: ABS STATIC, 12 Hz, Floor 40%, Pulse 50 ms, Trigger 30%, DRV aids OFF, Timer 5 min.

## Dashboard

| Area | Content | Status |
| --- | --- | --- |
| Header (full screen only) | Model name, LQ (0–100), SNR, TX voltage, TX power mW | ◐ |
| Battery | Pack voltage + cell count, cell V, battery %, min pack V, state (OFF/NOTEL/OK/LOW/ALARM) | ◐ |
| Laps | Current lap, last laps, lap count, best (flashes on new best) | ◐ |
| Footer | A T S C D letters, or session countdown when Show Timer = ON (blinks when expired) | ◐ |
| Battery highlight | Colour change on LOW / flashing on ALARM | ☐ |

## Live scope bar

Fill from centre = processed throttle/brake (green throttle, red brake); marker = brake floor (ABS active) or
trigger depth (ABS armed); raw-stick marker when aids are shaping it; tick under the bar = steering
(Graph Direction flips only this); ABS ON/OFF + letters. Status: ◐ (fill + steer tick on the dashboard).

## Laps & timer

- Lap from Lap Switch; minimum lap 3 s (debounce). Throttle Start Lap starts the clock on throttle.
- Laptimer Haptic on each new lap. Dashboard shows recent laps; a lap view shows more + AVG / TOT / LAPS / BEST.
- Long hold (~1.2 s, progress bar) on the lap control resets the session.
- Timer: short press start/pause/restart; long hold ~1.2 s resets. Haptic at zero always on (~3 s bursts with quiet gaps).

## Battery alarm

States: OFF (alarm off) · NOTEL (no pack/cells yet) · OK · LOW (under threshold, ~5 s hold not done) · ALARM (haptic ~3 s on / ~30 s quiet).
Small hysteresis so it doesn't chatter on the threshold.
