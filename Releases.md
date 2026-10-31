# 0.2.0

Adds **Rock**: hold a switch and the throttle pulses forward and reverse to rock a car off its roof.

Tested in the VX10 simulator (Ethos 26.2). Not yet tried on a real ESC, so try it on the bench first with the car
on a stand. Rock is off until you pick a Rock Switch, so updating changes nothing on an existing model.

**Rock**
- New Lua source **Rock**. Add one Free mix after the Throttle Aid line: source Lua → Rock, Operation **Add**,
  Output the throttle channel. It needs no LS1: it adds nothing unless you hold the switch, or if Trackside is missing.
- New **Rock** page in the Trackside tool: Rock Switch, Reverse Style (Direct, Via neutral, Double tap) to match
  the ESC, Neutral Dwell, Pulse Start / Max, Power Start / Max, Ramp Cycles and Hold Limit.
- Each rock pushes a little longer and harder than the last, then starts again, so one of them matches the car.
- Stops when you let go, pull the trigger past 30%, or reach the Hold Limit ("Rock limit"). Won't start with the
  trigger pulled, or if the switch was already on when the radio started.
- Dashboard: an **R** letter lights pink while rocking, and the bar shows each push (green forward, red reverse).
- Check setup: Rock status and a Rock result that confirms the mix line works.
- Reverse must be enabled on the ESC.

**Other**
- Setup guide: new section 4e and Rock settings in section 7.

# 0.1.0

First release of Trackside: race dashboard and drive aids for the FrSky Velox VX10.

Tested in the VX10 simulator (Ethos 26.2). Not yet driven on a real VX10, so try everything on the bench first.
Every drive aid is OFF in a new model. Setup guide: Trackside-Setup-Guide.pdf (attached).

**Install:** install the zip with Ethos Suite, or copy its `trackside` folder into the radio's `SCRIPTS` folder.
Then follow the setup guide: turn on the Throttle Aid and Steer Aid sources, add one Multiply mix line per
channel, and add the LS1 safety switch.

**Drive aids** (driver inputs and time only, no telemetry)
- ABS (Static / Dynamic), Traction Control, Steer Cut Throttle, Corner Brake, Steer Limit.
- Aids Switch: one switch position turns all aids on; anywhere else the sticks pass straight through.
- Safety: the aids send x1.0 on any script error, and the Trackside telemetry sensor with logic switch LS1
  turns the aid lines off if Trackside is missing or stops.

**Trackside tool** (System menu, or swipe up on the dashboard → Settings)
- Settings per model: Brake / ABS, Drive aids, Inputs, Timer & laps, Battery.
- Check setup: sensor and source status, fuel source, and the Aid Test, which shows per channel whether
  the Multiply line works.

**Dashboard**
- Pack voltage, cells, fuel, lowest voltage, laps (current, last, best, count), aid letters, live
  throttle / brake / steering bar, countdown in the footer.
- Swipe up for the toolbar: Laps (lap view with best / average / total), Start / Pause timer, Reset, Settings.
- PACK box turns amber on a low cell, flashes red on the battery alarm.

**Laps and timer**
- Lap switch with a 3 s minimum lap, hold 1.2 s to reset; session countdown on a switch.

**Fuel and alerts**
- Fuel from a fuel sensor, else mAh used with Pack Capacity, else resting voltage; published as the
  Pack Fuel telemetry sensor.
- Spoken alerts: lap times and best lap, fuel 50/30/20/10%, battery low, one minute / time up, Aid Test,
  drive aids on / off.

**Known limits**
- ABS above about 10–15 Hz can't be timed exactly (Lua updates about every 20 ms in the simulator).
- Fuel and link sensor names still need checking on real receivers and ESCs.
- Opening the Trackside tool from the dashboard needs Ethos 26.1 or later.
