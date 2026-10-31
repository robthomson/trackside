# Setting up a model on the VX10

Checked in the VX10 simulator (Ethos 26.2.0-RC1). Do mixer changes on the bench, never on track,
and confirm failsafe still works afterwards.

## 1. Install

Copy `src/trackside/` to `SCRIPTS/trackside/` on the radio (or use the VS Code **Deploy Radio** task).

## 2. Enable the Lua sources

**Model → Lua** (page 2): turn **Throttle Aid** and **Steer Aid** ON (and **Rock** if you want the rock
feature, see step 3).
Once they run, Trackside also creates a telemetry sensor called **Trackside** (it reads 1 while Trackside runs).
Ethos only lists Lua sources in pickers once they're enabled for the model.

## 3. Mixes

The car wizard creates `Steering → CH1` and `Throttle → CH2`. Keep those lines as they are and add one
Free mix per channel, directly after it:

| After | Source | Operation | Weight | Channel |
| --- | --- | --- | --- | --- |
| Throttle | Lua → **Throttle Aid** | **Multiply** | 100% | the throttle channel |
| Steering | Lua → **Steer Aid** | **Multiply** | 100% | the steering channel |

Set each Free mix's **Output** to the right channel (CH2 Throttle / CH1 Steering on the car template).
A new Free mix starts with Output = `---` (shown in red) and does nothing until it's set.

Use exactly one Multiply line per channel. A second one multiplies twice.
The Multiply line must come after its stick line: placed above it, it does nothing.
Reverse a channel on the **Channels** page. The wizard's stick lines have no reverse option, and a reverse
on the Multiply line flips the whole channel.

### Safety switch (required)

If the Trackside scripts are missing, Ethos treats each aid as 0, so a Multiply line on its own gives
**no steering and no throttle**. Make the Multiply lines run only while Trackside is loaded:

1. Open the Throttle Aid line → **Active condition** → **Logic switches** → **+ Add a new logic switch**.
2. Set **Function** `A > X`, **Source (A)** Telemetry → **Trackside**, **Value (X)** 0. LS1 shows green while
   Trackside runs.
3. Set the Steer Aid line's **Active condition** to **LS1** too.

### Rock line (optional)

Rock pulses the throttle forward and reverse to rock the car off its roof. It needs one more Free mix,
directly **after** the Throttle Aid line:

| After | Source | Operation | Weight | Channel |
| --- | --- | --- | --- | --- |
| Throttle Aid | Lua → **Rock** | **Add** | 100% | the throttle channel |

A missing Rock source adds 0, so this line needs no LS1. While the Rock Switch is held, Throttle Aid
sends ×0 and the channel is the rock waveform alone; the rest of the time Rock sends 0 and the line does
nothing. It must be an Add line: a Multiply here always gives 0.

Measured in the sim: with the scripts removed, both channels follow the stick 1:1. If the script stops,
the sensor goes lost and the stick is back 1:1 within ~5 s. On a Lua error the aid sources send ×1.0 at once.

If the model is edited while the scripts are missing (even a trim click), Ethos saves it without the Lua
links on the Multiply lines (the sensor and LS1 are kept). The car still drives normally. After
reinstalling, pick the aid source on each Multiply line again.

## 4. Dashboard

**Screens → +** → **Full screen** → widget **Trackside**.

## 5. Check it works and settings

**System** (page 2) → **Trackside** opens the Trackside tool:

- **Settings**: Brake / ABS, Drive aids, Rock, Inputs, Timer & laps, Battery (alarm, Pack Capacity).
- **Aids Switch** (Drive aids page): a switch position that turns all aids on; anywhere else the sticks pass
  straight through and Trackside says "Drive aids off". This is the everyday on/off; LS1 above stays, because
  it covers Trackside not running at all.
- **Rock** page: pick the **Rock Switch** (not set = feature off). Hold it with the trigger at rest and the
  throttle channel pulses forward and reverse; let go, pull the trigger or wait for the Hold Limit and it
  stops. Set **Reverse Style** to match the ESC: *Direct* for an ESC that reverses straight from forward
  (crawlers), *Via neutral* when it needs a pause at neutral first (most bashers; **Neutral Dwell** is that
  pause), *Double tap* when it needs brake, neutral, then reverse. Pulse length and power ramp from Start
  to Max over **Ramp Cycles** and start again, so one of the cycles meets the car's natural rock. Reverse
  must be enabled on the ESC. If the switch is already in the Rock position at power-up, flick it off and
  back before Rock will start. Test on the bench with the car on a stand first.
- **Fuel**: a real fuel sensor is used if the car has one. Otherwise Trackside estimates it (from mAh used if
  Pack Capacity is set, else from resting voltage) and publishes it as the **Pack Fuel** sensor.
- **Diagnostics → Check setup**: shows whether the Trackside sensor is sending and both aids are running.
  Turn **Aid Test** on (both aids ×0.5), then pull the trigger and turn the wheel: each result should read
  **OK: moves half as far**. *Not working* = the aid line is missing, off or on the wrong output; *Wrong* =
  Operation isn't Multiply. The test ends when you leave the page (or after 60 s). The **Rock result** needs
  no Aid Test: hold the Rock Switch, let go, and it says whether the throttle channel followed Rock.

Settings save per model to `SCRIPTS/trackside.user/models/` when you leave a page, so redeploying the
scripts never wipes them.
Throttle Input and Steering Input default to the VX10's physical trigger and wheel.
