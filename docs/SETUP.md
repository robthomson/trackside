# Setting up a model on the VX10

Checked in the VX10 simulator (Ethos 26.2.0-RC1). Do mixer changes on the bench, never on track,
and confirm failsafe still works afterwards.

## 1. Install

Copy `src/trackside/` to `SCRIPTS/trackside/` on the radio (or use the VS Code **Deploy Radio** task).

## 2. Enable the Lua sources

**Model → Lua** (page 2): turn **Throttle Aid** and **Steer Aid** ON.
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

Measured in the sim: with the scripts removed, both channels follow the stick 1:1. If the script stops,
the sensor goes lost and the stick is back 1:1 within ~5 s. On a Lua error the aid sources send ×1.0 at once.

If the model is edited while the scripts are missing (even a trim click), Ethos saves it without the Lua
links on the Multiply lines (the sensor and LS1 are kept). The car still drives normally. After
reinstalling, pick the aid source on each Multiply line again.

## 4. Dashboard

**Screens → +** → **Full screen** → widget **Trackside**.

## 5. Check it works and settings

**System** (page 2) → **Trackside** opens the Trackside tool:

- **Settings**: Brake / ABS, Drive aids, Inputs, Timer & laps, Battery (alarm, Pack Capacity).
- **Aids Switch** (Drive aids page): a switch position that turns all aids on; anywhere else the sticks pass
  straight through and Trackside says "Drive aids off". This is the everyday on/off; LS1 above stays, because
  it covers Trackside not running at all.
- **Fuel**: a real fuel sensor is used if the car has one. Otherwise Trackside estimates it (from mAh used if
  Pack Capacity is set, else from resting voltage) and publishes it as the **Pack Fuel** sensor.
- **Diagnostics → Check setup**: shows whether the Trackside sensor is sending and both aids are running.
  Turn **Aid Test** on (both aids ×0.5), then pull the trigger and turn the wheel: each result should read
  **OK: moves half as far**. *Not working* = the aid line is missing, off or on the wrong output; *Wrong* =
  Operation isn't Multiply. The test ends when you leave the page (or after 60 s).

Settings save per model to `SCRIPTS/trackside.user/models/` when you leave a page, so redeploying the
scripts never wipes them.
Throttle Input and Steering Input default to the VX10's physical trigger and wheel.
