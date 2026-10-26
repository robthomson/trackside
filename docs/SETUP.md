# Setting up a model on the VX10

Checked in the VX10 simulator (Ethos 26.2.0-RC1). Do mixer changes on the bench, never on track,
and confirm failsafe still works afterwards.

## 1. Install

Copy `src/trackside/` to `SCRIPTS/trackside/` on the radio (or use the VS Code **Deploy Radio** task).

## 2. Enable the Lua sources

**Model → Lua** (page 2): turn **Throttle Aid** and **Steer Aid** ON.
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
Put any reverse on the original stick line, not on the Multiply line.
If the script stops, the stick lines still drive the car.

## 4. Dashboard

**Screens → +** → **Full screen** → widget **Trackside**.

## 5. Settings

Open the widget's **Configure** page (Configure screens → tap the Trackside slot).

Settings save per model to `SCRIPTS/trackside.user/models/` when you leave the page, so redeploying the
scripts never wipes them.
Throttle Input and Steering Input default to the VX10's physical trigger and wheel.
