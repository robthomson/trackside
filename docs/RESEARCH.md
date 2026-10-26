# Trackside: research on race features and driver aids

**Target radio:** FrSky Velox VX10 (Ethos, 4.3" 800×480 colour touch screen, wheel + trigger, 2 thumb knobs, 2 three-position switches, 4 momentary buttons, 6 trim buttons, built-in speaker, headphone jack and haptic vibration (confirmed: Ethos Special Functions offer haptic), 900 MHz/2.4 GHz TD-ISRM RF).
**Parity reference (Phase 1 feature set):** existing radio-side racing scripts on monochrome open-firmware radios. The set covers radio ABS (OFF/STATIC/DYNAMIC; frequency, brake floor, pulse delay, trigger), traction control (throttle rise limit / soft launch), steer-cut throttle, corner brake, steer limit at speed, lap timer (lap switch, 3 s minimum, last laps, best), session countdown, pack voltage alarm and a race dashboard with link quality.
**Compiled:** 2026-10-26. Labels used: **[VERIFIED]** means the primary document was read. **[SECONDARY]** means forum, retailer or press material. **[UNVERIFIED]** means inference or a gap.

---

## Summary

1. **The rules split aids in two, and Trackside should label them the same way.** ROAR, EFRA and BRCA all ban traction control *devices* and gyro/accelerometer steering aids, and they ban sensor data used "for adjusting the performance of the vehicle while in motion". Transmitter-side shaping with no sensor feedback is a different thing: curves, speed, ABS pulsing and time-based throttle ramps. Futaba, Sanwa and KO have sold it for decades, and it is generally treated as legal. **Any aid driven by telemetry is a closed-loop aid and is illegal in sanctioned racing.** That includes "steer limit at speed", DYNAMIC ABS if it reads speed or RPM, and temperature-based throttle cuts. [VERIFIED rule text; how it applies to transmitter functions is UNVERIFIED and comes from no official ruling]
2. **Telemetry itself is restricted in some sanctioning bodies.**
   - EFRA electric (2026 App. 3, rule 4.4): "No other signals than these for the official lap counting transponder may be sent from the car." Rule 4.1 also bans using the receiver to capture signals from on-car sensors.
   - BRCA and EFRA general rules: "not allowed to use any form of telemetry with active transmission" that gives an advantage.
   - EFRA GT: telemetry is allowed if it is part of the RC system.
   - Trackside needs a **race-legal mode** that switches off telemetry-driven features. It may also need a "no telemetry" mode. [VERIFIED]
3. **BRCA goes further.** It "strongly advise[s]" against radio/receiver combinations that *can* perform banned functions, even when they are disabled, and organisers may refuse such equipment. So Trackside must make its legal state visible and provable, for example with a scrutineering screen. [VERIFIED]
4. **Racers mostly use a small set of aids.** Steering dual rate/EPA, steering speed, throttle curve or expo (often negative on low grip), brake rate (ATL) on a quick knob, and throttle "acceleration"/punch for nitro linkages. Radio ABS is used mainly on nitro and large scale, and on low-grip carpet/asphalt in 4WD. Many experienced drivers leave ABS and radio traction control off. [SECONDARY]
5. **During a race drivers barely look at the screen.** High-end radios lean on **vibration, beeps and voice**: Futaba lap-navigation buzzer and grip vibrator, Sanwa voice readout of lap times and telemetry. The screen does its work in the pits: lap list, best/average, telemetry logs and graphs. [VERIFIED manuals]
6. **The common complaint about open-firmware surface radios is usability.** Owners say it is not intuitive for surface drivers and slow to adjust on the fly, and ABS was missing until scripts appeared. Some report dropout and latency trade-offs. The Velox VX10 already has some surface ABS, a brake mixer and a steering mix built into Ethos, so Trackside must add value *beyond* those. [SECONDARY]
7. **High-end radios have features beyond the Phase 1 feature set:**
   - Telemetry logging linked to laps (Sanwa M17 writes CSV to SD).
   - Interval/"lap navigation" target timers.
   - Timed setting progression (Sanwa R-MODE function).
   - Any parameter on any trim/dial (Futaba DT1–DT6 lists ABS and TC parameters).
   - Conditions/profiles, plus servo and ESC tuning from the radio (KO real-time ICS, Futaba MC Link).
   - Gear ratio and rollout calculators. [VERIFIED manuals]

---

## 1. Which aids are used, where, and what the rules say

### 1.1 Rule text (primary documents)

| Body | Rule | Exact wording (abridged) | Status |
|---|---|---|---|
| **ROAR** (Rules ver. 26-10a, effective 16 Oct 2026) | **8.2.7** (general vehicle rules; numbered 5.2.3 in 2014) | "The use of traction control sensing devices, active suspension devices, and steering control devices aided by gyroscopes or accelerometers (G-force sensors) of any kind is strictly prohibited. Sensors may be used for the purpose of passive data recording but not for adjusting the performance of the vehicle while in motion." In 2014 ROAR attached a **5-year suspension** to this rule (Big Squid RC). | VERIFIED |
| ROAR | **7.2** radio equipment | Radios limited to two channels (one servo + one ESC), "More than one function is allowed per device… Control is limited to forward, brake, and steering. The use of reverse in competition is not allowed." 1/5 scale may use 3 channels. | VERIFIED |
| ROAR | 7.2 ESC | In "Blinky"/fixed-timing classes the ESC "must be rendered incapable of changing that timing mode by any remote means"; ESCs with Bluetooth/NFC/IR/Wi-Fi remote programming are not allowed. ESC timing changes "must not be possible from the radio transmitter". Variable PWM/throttle/brake frequency is allowed if it doesn't change timing. | VERIFIED |
| ROAR | 3.8.1–3.8.2 (fuel on-road) | "only functions allowed are steering, throttle, and brake." "No onboard traction control or other electronic aids are allowed, other than fail-safe systems." | VERIFIED |
| **EFRA** (Handbook 2026, App. 3 Electric) | **4.1** | "The radio control receiver in the car may operate steering and motor management… Using the receiver to capture electrical signals from sensors carried in the car is prohibited, be it wireless or not." | VERIFIED |
| EFRA App. 3 | **4.2** | "Automated steering, gyroscopes to control car movement, traction control, active suspension are not allowed." | VERIFIED |
| EFRA App. 3 | **4.3** | ESC current/voltage limiters ("timed delay, current limiter, keyboard programs") and passive data recording are allowed, "but setting or programming of these devices must only be possible whilst the car is stationary." | VERIFIED |
| EFRA App. 3 | **4.4** | "No other signals than these for the official lap counting transponder may be sent from the car." | VERIFIED |
| EFRA General Rules 2024 | **8.6.2** | "Steering and driving/brake can only be operated by direct action of the driver using the Radio… Sensors are only allowed for the purpose of passive data recording and not for adjusting the performance of the car whilst in motion. It is not allowed to use any form of telemetry with active transmission." | VERIFIED |
| EFRA App. 1 (IC track, 2023) | **5.12** | "not allowed to use any electronic parts for 'Traction Control and/or braking control (ABS)' which can control the power of the transmission by means of a **feedback system**. It is not allowed to use any form of telemetry with active transmission." | VERIFIED |
| EFRA GT EP | class text | "Electronic driving aids such as ESP and ABS are prohibited. Telemetry is allowed as long as [its] function is part of the remote control and the receiver…" Whether *transmitter* ABS counts as "ABS" here is **UNVERIFIED**. Read strictly, it may. | VERIFIED text / UNVERIFIED scope |
| **BRCA** (General Rules 2026 V1, §14) | Electronic Driving Aids | Same wording as EFRA 8.6.2, plus "**power control** aided by gyroscopes… or devices giving a similar effect is strictly forbidden on vehicles with four or more wheels. It is strongly advised that competitors do not use any radio/receiver combinations that have the capability of performing the above functions… **even if the functions are disabled**. Organisers have the right to refuse such equipment." Penalty: DQ and up to a **10-year ban**. | VERIFIED (third-party hosted copy of BRCA PDF) |
| EFRA/IFMAR 2014 | clarification | Dallas Mathiesen (EFRA/IFMAR president) clarified that gyros, TC and active suspension are forbidden at sanctioned events, with long-term bans (Red RC). | SECONDARY |
| Event level | DNC 2014, Tamiya TCS | DNC enforced ROAR rules with pre-main inspection for gyros. Tamiya says gyros are banned by leading US sanctioning bodies and in TCS. | SECONDARY |

### 1.2 How the rules apply to Trackside's aids (interpretation, **UNVERIFIED**, no official ruling found)

| Trackside / Phase 1 aid | Mechanism | Sanctioned-race risk | Suggested label |
|---|---|---|---|
| Curves/expo, dual rate, EPA, steering & throttle speed | Pure transmitter shaping | Low. Standard on every race radio | Race-legal |
| ABS STATIC (time-based pulsing from trigger position) | Transmitter function, no sensor | Low to medium. Futaba, Sanwa and KO ship it, and EFRA 5.12 targets *feedback* systems. EFRA GT wording and the BRCA "direct action" wording are ambiguous | Race-legal (check class rules) |
| Traction control as throttle rise limit / soft launch, time-based | Transmitter shaping, comparable to Futaba "Throttle speed", "Traction control" and "Start" | Low to medium. The *name* "traction control" invites protests. Call it "Throttle Ramp" or "Launch" | Race-legal (rename) |
| Steer-cut throttle / corner brake (mix from steering input) | Transmitter mix, comparable to Futaba Brake-mixing "soften the brakes when steering" | Low. Driver-input-only mixing | Race-legal |
| **Steer limit at speed** | Needs speed/RPM telemetry, so **closed loop** | **High.** It matches "sensors… adjusting the performance of the vehicle while in motion" | **Practice / Bash only** |
| **ABS DYNAMIC** (if it adapts to speed/RPM telemetry) | Closed loop | **High** | Practice / Bash only |
| Telemetry-triggered throttle limit (like Sanwa "Telemetry switch", e.g. TL1 > 60 °C → throttle 50%) | Closed loop | **High** under ROAR 8.2.7 | Practice / Bash only (offer as a *warning* instead) |
| Telemetry display itself (RSSI, voltage, temp) | Downlink from car | **EFRA electric 4.1/4.4 and BRCA/EFRA "active transmission" may prohibit it.** It is widely used in clubs | Toggle: "Telemetry OFF for event" |
| Gyro mixing | Gyro on car | Banned in ROAR/EFRA/BRCA 4-wheel classes. Normal in RWD drift and many drift comps (Adrenaline RC: "Gyros are allowed") | Drift profile only |

### 1.3 Usage by class (SECONDARY unless noted)

- **1/10 electric off-road (2WD/4WD buggy, SCT, truck):** steering D/R and EPA, steering speed, and throttle expo or curves (negative expo on loose or low grip). Most power-delivery tuning happens in the ESC (punch, drag brake, brake strength). Racers often keep ESC brake strong and turn it down on the radio with a brake-rate knob or switch "because it's easier to adjust quickly as track conditions change". Radio "traction control" is mostly a throttle curve plus trigger finger. Many skip radio ABS and TC.
- **Touring / on-road electric:** small negative steering expo (about -25 to -30 on one poster's radio; others warn that past ~15% "the car will feel dead off center"). Steering speed is used as a "quick fix" when the car spins or traction-rolls. A fast servo matters more than torque.
- **1/8 nitro buggy / nitro on-road / 1/5 large scale:** throttle **acceleration** (Futaba) removes linkage slop at neutral ("sharp response comparable to that of electric motor cars"). Radio **ABS** is most at home here: one servo drives carb and mechanical brake, and Futaba's manual pitches ABS against understeer when braking into a corner on 4WD. Some 1/8 GP racers pulse the brake by hand and set brake EPA "so it barely locks". Brake mixing covers independent front/rear brakes on 1/5. Engine cut, idle-up and fuel down-timers also appear.
- **1/8 e-buggy:** similar to 1/10 electric. ESC-side tuning dominates. ROAR race lengths of 30–60 min mains make **session timers and pit-stop/pack timing** relevant (ROAR 8.1 table).
- **Drift (RWD):** a steering **gyro is essential** and is commonly allowed. Futaba radios have gyro-gain mixing on a dial, and Yokomo gyros offer ASSIST/NOR modes. Futaba notes TC pulsing can fake an engine "reverberation" sound in drift.
- **Crawler / scale:** drag brake, 4WS modes (front, rear, crab), dig switch, multi-position switches, low-speed throttle resolution, and long run timers. Telemetry focuses on voltage and temperature (community crawler telemetry scripts exist).
- **Bashing / beginners:** stability control (Spektrum AVC is a gyro, and some call it "a talent compensator" or "a massive crutch"), throttle limit / drive modes for kids and new drivers (Spektrum DX5 Pro: up to 5 drive modes), voltage alarms and temperature. Some local clubs allow gyros in novice classes.

---

## 2. Typical settings and how people tune them

**Futaba ABS (7PX manual, an example with an S9373SV servo)** [VERIFIED]
- Parameters and ranges: Brake return 0–100 (default 50; 100 = back to neutral), Delay 0–100 (0 = immediate, 100 ≈ 1.0–1.4 s; the manual quotes both), Cycle speed 1–100 (default 30; smaller = faster), Duty −4…+4 (− = brakes lock less), Trigger point 5–95% (default 30; Normal/Reverse range).
- Futaba's suggested start: **return ~30%, cycle 5–7, duty 0, delay 10–15%, trigger point ~70%**.
- Wheels lock or the car spins: raise return, move duty negative, cut delay.
- Braking too weak: lower return, move duty positive, add delay.
- Futaba warns that fast servos are needed for ABS to work well (backed by forum posts).
- **Sanwa M17 ALB** uses the same ideas: STROKE, POINT, LAG (s), CYCLE, DUTY, on a switch. The manual warns ALB can block reverse on ESCs with reverse.

**Futaba Traction Control** [VERIFIED]: throttle pulsing with return, delay, cycle, duty and trigger point. It is the mirror image of ABS. Futaba also has **Throttle speed** in high/mid/low bands, turn and return sides. That is the closer analogue to a "rise limiter" and is pitched against wheelspin on slippery surfaces.

**Steering** [SECONDARY]
- Speed vs expo: racers like steering *speed* because it keeps the wheel-to-servo mapping linear while softening the response. Expo moves resolution away from centre.
- Example values: one racer with a ~0.07 s servo used turn −9 / return −3.
- Setup order: EPA for full lock, then D/R so the car just makes the tightest corner, then expo or speed for fast corners.

**Throttle and brake** [SECONDARY]
- Set throttle and brake EPA/D/R to 100% and calibrate the ESC first.
- Then reduce punch in the ESC. Use negative throttle expo on the radio only if grip is very low; ESC settings are "much more effective".
- Brake: leave the ESC aggressive and trim with radio brake rate (ATL) on a dial.
- Futaba **Acceleration** is 0–100 on forward and brake sides, mainly for nitro.

**Assignability is a tuning tool in itself** [VERIFIED]. The Futaba 10PX can put on any digital trim/dial (DT1–DT6, DL1): ABS return/delay/cycle per brake channel, TC return/delay/cycle, throttle speed per band, acceleration, steering speed turn/return, curves, brake ATL and sub-trims. Sanwa M17 has a similar KEY ASSIGN list (ALB-POINT/STROKE/LAG/CYCLE/DUTY, ALB-SW, VOICE-REQ…).

---

## 3. What drivers look at: race vs pits

- **During the run, non-visual cues dominate.** [VERIFIED manuals; SECONDARY usage]
  - Futaba 10PX timers: **Up**, **Fuel down**, **Lap** (200 laps; 3 s lockout after each press; race-time alarm; pre-alarm) and **Lap navigate** (a fixed-interval buzzer used as a target-lap pace beep). Each has a 10 s pre-alarm and can start from the first trigger pull, and a **grip vibrator** offers 3 patterns.
  - Telemetry alarms: high/low thresholds with beep and vibration.
  - Sanwa M17: lap timer up to 999 laps with pre-alarm before goal time. Two interval timers can run together, a down timer turns into an up timer, and start can be TRIGGER/KEY/STARTER. **Voice** reads out lap times and telemetry on request (VOICE-REQ on a key).
  - Spektrum DX5 Pro vibrates on timer alarms, low voltage and telemetry limits.
- **In the pits / between heats:** lap list (each lap, best, average, total), telemetry logs and graphs (M17 logs at 1 s or 10 ms linked to the lap timer and exports CSV), ESC/motor temperature, pack voltage, RPM, and adjusting curves, rates and ESC parameters. In ROAR classes ESC changes are allowed only while stationary or via external modules.
- **What drivers want shown:** last lap, best lap, lap count, time remaining, and **delta to best/target**. Health data: pack voltage per cell, ESC/motor temperature, link quality. Community wish lists for open-firmware radios include motor/ESC temp display, burnout/launch screens and logging runs. One M17 user reported their thermal alarm firing at 165 °F mid-race and backing off. [SECONDARY]
- **Glanceability [inference, UNVERIFIED]:** a pistol-grip radio sits at waist height while the driver watches a car 10–40 m away. Any on-screen information must be readable in about 200 ms: very large numerals, colour-coded state, one primary number. Audio and haptics carry the critical events (lap, delta, alarms). The Velox VX10 has haptic (confirmed via Ethos Special Functions), so Trackside can use **audio/voice and vibration** together.
- **Lap timer vs transponder:** at sanctioned events the official count is **MyLaps/AMB transponders** (ROAR 14.3; EFRA personal transponders), and many tracks call out lap times over the PA. A radio lap timer is mainly for **practice at untimed tracks, car parks and home tracks**, for **pace targets** (lap-nav beeps) and for **self-analysis**. Standalone practice timers (LapMonitor, CloudLaps, SkyRC LapWiz) exist because this use case is real. [SECONDARY]

---

## 4. Complaints about existing radios and radio-side racing scripts

- **Open-firmware radio usability for surface racers [SECONDARY, RCTech and RCTalk owner threads; links omitted under project naming policy]:**
  - "not user friendly for surface drivers, nor is it intuitive when you need to make quick adjustments on the fly."
  - "initially a bit overwhelmed with how complex [the firmware] is to learn."
- **Missing ABS before scripts:** "The one advanced function I actually use occasionally (ABS) is absent…". People built steering reduction under braking by hand, for example −30% while braking and −20% on throttle with a mix delay. A Velox VX10 commenter named missing ABS as a "big gap" on the radio they were comparing against.
- **RF/latency trade-offs:** in its lowest-latency mode one user's open-firmware radio could not drive a 2WD steering servo to full travel. Early firmware caused 5–10 s signal losses and runaways, mostly fixed later. Another racer said it "will not be replacing my Flysky NB4". Others praise its responsiveness. [SECONDARY; mixed]
- **Script-ecosystem friction:** community scripts need file-name (6-character) or GVAR/channel tweaks to work, as seen in a GitHub issue on a race-display script. [SECONDARY]
- **Rules uncertainty:** owners ask whether scripted curve changes count as "driver aids". The forum consensus was that shaping is fine and that "something that is measuring forces and actively adjusting your inputs would absolutely be cheating." [SECONDARY]
- **Specifics of the reference racing script itself:** no public changelog, manual or review was found. Its exact DYNAMIC ABS and "steer limit at speed" inputs are **UNVERIFIED**. Confirm whether they read telemetry before deciding how to label them.
- **Other radios [SECONDARY]:** the Sanwa M17 has no third-party telemetry adapter, so a Sanwa ESC is needed for temperature. Telemetry support is ESC- and firmware-specific (Hobbywing adapters exist for Futaba S.BUS2, FrSky and JETI, not all models report current). Retailer listings disagree on whether the Flysky NB4 Pro supports telemetry.

---

## 5. High-end radio features beyond the Phase 1 feature set

| Feature | Seen on | Notes |
|---|---|---|
| **Telemetry logging tied to lap timer**, CSV export, on-radio graphs | Sanwa M17 (LOG DATA, GRAPH SETTING) | Log interval 1 s / 10 ms. [VERIFIED] |
| **Lap navigation / interval pace timers** | Futaba 10PX (Lap navigate), Sanwa M17 (INT1/INT2, run together) | Target-lap beep. [VERIFIED] |
| **Timed progression of settings** | Sanwa M17 R-MODE function (steps 1→5 or 5→1 at intervals) | E.g. soften as tyres or fuel change. [VERIFIED] |
| **Any parameter on any trim/dial**, plus per-switch function maps | Futaba 10PX DT1–6/DL1, Sanwa KEY ASSIGN | Includes ABS/TC sub-parameters. [VERIFIED] |
| **Conditions / profiles** (setting sets switched in-run) | Futaba Condition, Flysky NB4 condition modes, Spektrum drive modes | [VERIFIED/SECONDARY] |
| **Voice read-out** of laps and telemetry on demand | Sanwa M17 | [VERIFIED] |
| **Grip vibration** patterns for lap-nav and alarms | Futaba 10PX, Spektrum DX5 Pro | [VERIFIED/SECONDARY] |
| **Servo/ESC programming from the radio** | KO EX-NEXT real-time ICS, Futaba MC Link / S.BUS servo, Sanwa PGS | ROAR bans transmitter-side ESC *timing* changes in Blinky classes. [VERIFIED/SECONDARY] |
| **Gear ratio and rollout calculators** | Futaba 10PX | [VERIFIED] |
| **Multi-channel brake mixing** (front/rear, steering-softened brake) | Futaba Brake mixing | Like "corner brake". [VERIFIED] |
| **Throttle speed by band** (high/mid/low) and **Acceleration** | Futaba | Finer than one rise limit. [VERIFIED] |
| **Timer start on first trigger pull** | Futaba, Sanwa | [VERIFIED] |
| **Quick-setup wizard / direct model select launcher** | Sanwa M17 | [VERIFIED] |
| **Telemetry "switch/mix"** (sensor-driven actions) | Sanwa M17 | Closed loop, so practice only. [VERIFIED] |

---

## 6. Prioritised roadmap for Trackside

Effort is a rough guess for an Ethos Lua widget/system-tool suite: S ≈ days, M ≈ 1–2 weeks, L ≈ longer. **Priority 1 = must have for launch.**

| # | Feature | Why | Evidence | Effort |
|---|---|---|---|---|
| 1 | **Legality model: every aid tagged *Open-loop (race-legal)* vs *Closed-loop (practice/bash)*, with a one-tap "Event mode"** that locks out closed-loop aids and shows a persistent badge | The rules ban sensor-driven adjustment, and BRCA lets organisers refuse radios that are merely *capable*. Visible lockout is the defence | ROAR 8.2.7, EFRA 8.6.2/App.3 4.1–4.4, BRCA §14 | M |
| 2 | **Scrutineering screen** listing active aids, settings, telemetry on/off and a config hash | Gives tech inspectors a quick answer. Supports the BRCA "could be activated" clause | BRCA §14, DNC inspections | S |
| 3 | **Telemetry OFF for event switch** (and a dashboard that degrades gracefully without telemetry) | EFRA electric 4.4 forbids any signal from the car except the transponder. BRCA/EFRA ban advantageous active telemetry | EFRA App.3 4.1/4.4; EFRA Gen 8.6.2 | S |
| 4 | **Neutral, protest-proof naming**: "Throttle Ramp/Launch" instead of "Traction Control", "Brake Pulse" instead of "ABS" (with ABS in the help text) | The words "traction control" and "ABS" appear literally in banned-device rules (EFRA GT, IC 5.12) | EFRA App.1 5.12, GT EP text | S |
| 5 | **ABS parity+**: OFF/STATIC (+DYNAMIC behind the closed-loop gate if it uses telemetry). Params: return/floor, cycle, duty, delay, trigger point Normal/Reverse, optional "only when steering > x%". **Live waveform preview** of pulses on the colour screen | Matches Futaba/Sanwa parameter sets, and the preview cuts down tuning trial and error | 7PX/10PX manuals, M17 ALB | M |
| 6 | **Futaba-style starting presets with plain-language fixes** ("wheels lock → raise return / duty −") | Users say ABS is hard to set up and run defaults. Futaba publishes a tuning matrix | 7PX ABS example; RCTalk/RCTech threads | S |
| 7 | **Any-parameter-on-any-control mapping** (knobs S1/S2, trims, wheel buttons) with on-screen **"what does this knob do" HUD** when touched | The top high-end feature. The main owner complaint is slow on-the-fly adjustment | Futaba DT1–6, Sanwa KEY ASSIGN; RCTech owner complaints | M |
| 8 | **Throttle Ramp by band + Launch** (rise limit in low/mid/high bands, separate release speed, first-pull launch profile) | Futaba-level control beyond a single rise limit. Time-based, so race-legal | 10PX throttle speed bands, Start function | M |
| 9 | **Steer-cut throttle & corner brake as driver-input mixes** with proportional curves and a mix delay (avoids a jump at neutral) | Users already hand-build −30% brake / −20% throttle steering mixes with delay. Futaba ships steering-softened braking | RCTech owner thread; 7PX Brake mixing | S |
| 10 | **Lap timer done right**: lap switch with min-lap lockout (3 s default, adjustable), start on first trigger pull, last N laps, best, average, consistency (σ), **live delta to best/target**, undo last lap | Matches Futaba/Sanwa. Delta and undo extend the Phase 1 set | 10PX Lap timer (3 s lockout), M17 lap list | M |
| 11 | **Audio-first race feedback**: voice "lap time + delta" (e.g. "twelve-four, minus two"), pace beeps (lap-nav), countdown pre-alarms at 60/30/10 s, distinct alarm tones | Drivers can't look down. Futaba/Sanwa rely on buzzer, vibration and voice. The Velox VX10 has a speaker and haptic vibration | 10PX lap-nav, M17 VOICE; Velox VX10 spec | M |
| 12 | **Glanceable race dashboard**: one giant primary number (last lap or delta), colour state (green faster / red slower), time remaining bar, pack bar, link bar. Rotatable 180°, high-contrast outdoor theme, original visual identity | The 800×480 colour screen allows colour-coded state. Must read in a glance | Velox VX10 spec; glanceability inference | M |
| 13 | **Session manager**: countdown with race-length presets by class (ROAR: 5 min qual / 8 min A-main 1/10 off-road, 30–60 min 1/8 mains), pit-stop/pack-swap timer, auto-start on trigger | Real race formats vary a lot. Long nitro/e-buggy mains need a pit timer | ROAR 8.1 race-length table; 10PX fuel down timer | S |
| 14 | **Pack voltage alarm parity+**: LiPo/LiHV/LiFe, cell count auto-detect, sag-aware (ignore dips under load), per-cell display, end-of-run voltage logged per session | Avoids false alarms when the pack sags under throttle. LiFe for receiver packs | Phase 1 parity; 10PX battery fail-safe notes | S |
| 15 | **Pit view: session history & lap charts** (lap-time bar chart, best stint, per-lap telemetry: min V, max temp, link quality), saved per model/track/date | The M17's killer feature is logs plus graphs on the radio, which colour touch makes far better | M17 LOG DATA/GRAPH | L |
| 16 | **CSV export to SD** (laps + telemetry) | Racers analyse on a PC. Sanwa exports CSV | M17 manual | S |
| 17 | **Setup profiles: Car × Track × Condition** (e.g. "Buggy / Club carpet / high grip") with one-tap switching and diff view | Futaba Conditions, Flysky condition modes, Spektrum drive modes. Track-specific setups are normal racer practice | 10PX Condition; NB4 Pro; DX5 Pro | M |
| 18 | **Setup sheet / notes** per session (tyres, gearing, ESC profile, temperature, comment), with gear-ratio and rollout calculators | Futaba bundles calculators. Racers keep setup sheets anyway | 10PX roll-out and gear charts | M |
| 19 | **Class templates** (1/10 off-road, TC, 1/8 nitro, e-buggy, drift, crawler, basher) that preset which aids appear and their defaults | Different classes need different aids (ABS → nitro/1/5; gyro → drift; dig/4WS → crawler; drive modes → bash) | §1.3 | M |
| 20 | **Health alarms as warnings, not interventions** (ESC/motor temp, RPM limit, link quality) in race mode. Optional auto-throttle-limit only in Practice/Bash | Sanwa-style telemetry actions are closed loop, so keep them out of race mode | M17 Telemetry switch; ROAR 8.2.7 | S |
| 21 | **Beginner / kid mode**: throttle limit, steering limit, PIN-locked | Strong basher demand (Spektrum drive modes). Safe and race-irrelevant | DX5 Pro drive modes; forum | S |
| 22 | **Drift profile**: gyro gain on knob with on-screen gain bar, ASSIST/NOR presets | Gyros are standard and allowed in many drift comps | Yokomo, Adrenaline RC rules; Futaba gyro mixing | S |
| 23 | **Crawler profile**: drag brake, dig, 4WS mode selector (front/rear/crab), low-speed throttle curve, run timer | Crawler needs differ from racing | Axial Capra 4WS, Futaba 3PM-X | M |
| 24 | **Timed setting progression** (e.g. steering D/R or brake rate stepping at set times in a long main) | Sanwa R-MODE function. Unique and open-loop | M17 R-MODE function | S |
| 25 | **Practice timing integrations** (e.g. lap trigger from an external practice timer, if the hardware can feed Ethos) | Practice at untimed tracks is the radio lap timer's real niche. [UNVERIFIED feasibility] | LapMonitor/CloudLaps threads | L |

**Don't ship (or hide behind practice/bash only):** gyro steering in non-drift profiles, telemetry-driven traction or steer limiting in race mode, and any ESC timing change from the radio (ROAR 7.2).

---

## Open questions / to verify

- How the reference racing script implements DYNAMIC ABS and steer limit at speed: telemetry-driven or time-based? No public documentation was found.
- Whether ROAR or EFRA have *ever* ruled on transmitter-side ABS/TC. No ruling was found, and current practice suggests they are tolerated. Ask ROAR/EFRA/BRCA directly before marketing anything as "race legal". Phrase it as "uses no on-car sensors; check your class rules".
- Velox VX10: the exact built-in Ethos surface ABS/brake mixer parameters (manual dated 10 Oct 2026 exists but was not read), and which Ethos Lua APIs allow mixer-level output shaping at frame rate.
- FrSky surface receivers and ESC telemetry: S.Port ESCs (e.g. Scorpion, Hobbywing via adapter) need pole-pair and gear-ratio setup to report mechanical RPM. Surface-specific FrSky receivers were "still coming" at launch per forum posts.
- BRCA General Rules were read from a club-hosted copy (hnmc.co.uk). Confirm against brca.org.

---

## Sources

**Rules**
- ROAR Rule Book ver. 26-10a (eff. 16 Oct 2026): https://www.roarracing.com/downloads/ROAR_Rule_Book.pdf
- EFRA Handbook 2026 Appendix 3 (Electric): https://www.efra.ws/wp-content/uploads/2026/06/EFRA%20Handbook%202026%20App3%20v4.pdf
- EFRA Handbook 2025 Appendix 3: https://www.efra.ws/wp-content/uploads/2025/06/EFRA%20Handbook%202025%20App3.pdf
- EFRA Handbook 2024 General Rules (8.6.2): https://www.efra.ws/wp-content/uploads/2024/03/EFRA%20Handbook%202024%20Gen%20Rules.pdf
- EFRA Handbook 2023 Appendix 1 (IC track, 5.12; GT EP): https://www.efra.ws/wp-content/uploads/2023/04/EFRA%20Handbook%202023%20App1%20V2%20Web.pdf
- EFRA 2023 1/8–1/10 Track section minutes: https://www.efra.ws/wp-content/uploads/2023/11/Minutes-1-8-1-10-Trackv2.pdf
- EFRA 1/8 GT/Rally rules 2014: https://www.efra.ws/wp-content/uploads/2014/05/V2%20final%20EFRA%20Version%20GT8%20Rally%20rules%20June%203rd2014.pdf
- BRCA General Rules 2026 V1 (club-hosted copy): https://hnmc.co.uk/downloads/BRCA%20General%20Rules.pdf ; BRCA 2026 rules index: https://www.brca.org/racer-hub/brca-documents/2026-rules
- Big Squid RC, "Tractiongate" (ROAR 5.2.3, 5-year suspension, 2014): https://www.bigsquidrc.com/the-cub-report-06-23-2014-version-tractiongate-14/
- Red RC, "EFRA & IFMAR clarify gyro illegality" (2014): https://www.redrc.net/2014/06/efra-ifmar-clarify-gyro-illegality/
- LiveRC, "DNC gyros: why do we care": https://www.liverc.com/news/dnc-gyros-why-do-we-care/
- Tamiya Active Steering Assist (gyro bans in US competition/TCS): https://www.tamiyausa.com/shop/electronics/rc-active-steering-assist-unit/
- Tamiya TCS rules: https://tamiyausa.com/tcs/rules
- Adrenaline RC drift comp (gyros allowed): https://www.adrenalinercracing.com/products/adrenaline-rc-spring-drift-comp-2025-one-entry

**Manuals / manufacturer**
- Futaba T10PX full manual: https://futabausa.com/wp-content/uploads/2021/12/T10PX_FULL_ENG_Letter.pdf
- Futaba 7PX manual (ABS/TC parameters and example settings): https://futabausa.com/wp-content/uploads/2018/09/7PX.pdf
- Futaba 7PX traction control page (ManualsLib): https://www.manualslib.com/manual/1334228/Futaba-7px.html?page=94
- Futaba 4PK ABS (ManualsLib): https://www.manualslib.com/manual/378273/Futaba-4pk-2-4ghz.html?page=68
- Sanwa M17 manual: https://sanwa-denshi.com/rc/Manual/Transmitter/M17_ENG_Manual_C.pdf
- Sanwa M17S manual: https://sanwa-denshi.com/rc/Manual/Transmitter/M17S_ENG_Manual.pdf
- Sanwa MT-5 manual: https://sanwa-denshi.com/rc/Manual/Transmitter/MT-5_ENG_Manual_C.pdf
- KO Propo EX-NEXT (retailer/feature copy): https://shop.robitronic.com/en/kopropo-ex-next-ko10664 ; KO EX-RR (LiveRC): https://liverc.com/news/new-ko-propo-ex-rr-pro-level-24-ghz-radio-system
- Flysky Noble NB4 Pro listings: https://ozrc.com.au/products/flysky-noble-nb4-pro-2-4ghz-18ch-transmitter-with-2x-receivers-nb4proplus ; https://www.lindinger.at/en/RC-ELECTRONICS/TRANSMITTERS/Transmitters/for-Surface/Flysky-NB4-Pro-2-4Ghz-remote-control-with-2-Receiver/9791372
- Spektrum DX5 Pro: https://horizonhobby.com/product/dx5-pro-5-channel-dsmr-transmitter-only/SPMR5010.html
- FrSky Velox VX10 product page: https://www.frsky-rc.com/product/velox-vx10/
- FrSky Velox VX10 (AMain listing): https://www.amainhobbies.com/frsky-velox-vx10-900mhz-2.4ghz-24channels-surface-transmitter-frk-03010289/p1885126
- Ethos feedback/releases: https://github.com/FrSkyRC/ETHOS-Feedback-Community/releases
- Hobbywing S.BUS2 telemetry adapter: https://www.hobbywing.com/en/products/sbus2-telemetry-adapter-for-futaba94
- Castle telemetry link S.BUS2: https://www.hobbyshop.ch/telemetry-link-s-bus2-010015200.html
- Scorpion Tribunus III FrSky S.Port telemetry guide: https://scorpionsystem.com/files/FrSKY%20S.Port_Scorpion%20Tribunus%20III%20Telemetry%20User%20Guide.pdf

**Community**
- RCTech, FrSky Velox VX10 thread: https://www.rctech.net/forum/radio-electronics/1144300-frsky-velox-vx10-radio.html
- RCTech, transmitter speed servo function: https://www.rctech.net/forum/radio-electronics/611993-transmitter-speed-servo-function-printthread.html
- RCTech, How much dual rate / expo in TC: https://www.rctech.net/forum/electric-road/377623-how-much-dual-rate-do-you-use-tc-expo.html
- RCTech, Throttle/brake settings ESC vs TX: https://www.rctech.net/forum/electric-road/812058-throttle-brake-settings-esc-vs-tx.html
- RCTech, Learning your controller: https://www.rctech.net/forum/electric-off-road/1025273-learning-your-controller-settings-benefit-driving.html
- RCTech, Traction control – how do you do it?: https://www.rctech.net/forum/electric-off-road/555124-traction-control-how-do-you-do.html
- RCTech, Radio/receiver with gyro and traction control: https://www.rctech.net/forum/radio-electronics/1027032-radio-receiver-gyro-traction-control.html
- RCTech, Gyros/traction control illegal forever?: https://www.rctech.net/forum/electric-road/622531-gyros-traction-control-illegal-forever-post10656661.html
- RCTech, 1/8 GP braking technique: https://www.rctech.net/forum/nitro-road/1112557-1-8-gp-ic-track-proper-braking-technique.html
- RCTech, Sanwa telemetry options: https://www.rctech.net/forum/radio-electronics/1100396-sanwa-telemetry-options-printthread.html
- RCTech, LapMonitor: https://www.rctech.net/forum/radio-electronics/989450-lapmonitor-lap-timer-printthread.html ; CloudLaps: https://www.rctech.net/forum/radio-electronics/1059789-cloudlaps-decoderless-solution-laptiming-printthread.html
- RCTalk, How do I get ABS braking: https://www.rctalk.com/forum/threads/how-do-a-get-abs-braking.22007/
- RC Car Action, Futaba 3PM-X review (ABS delay/depth/speed): https://www.rccaraction.com/articles/product-probe-futaba-3pm-x
- Competition X, RC radio timer explained: https://www.competitionx.com/rc-radio-timer-explained/
- Axial Capra 4WS (dig/4WS): https://www.liverc.com/news/new-axial-capra-19-4ws-trail-buggy-rtr/
- Yokomo drift gyro: https://ozrc.com.au/products/yokomo-drift-performance-gyro-w-ep-adjustment-purple-dpp-302v4pb
