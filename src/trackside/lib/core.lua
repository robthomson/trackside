--[[
  Drive-aid core. Shared by the Throttle Aid / Steer Aid sources and the
  Trackside widget.

  Model mixes keep a raw stick ADD line and multiply it by our output:
      throttle channel: Throttle (Add) x Throttle Aid (Multiply)
      steering channel: Steering (Add) x Steer Aid (Multiply)
  If the script is missing or stops, the Trackside sensor goes lost, LS1 (the
  lines' Active condition) turns off and the stick drives the car. On a Lua error the
  sources send x1.0 (see main.lua).

  Processing order (fixed):
      Traction Control -> Steer Cut Throttle -> Corner Brake -> ABS -> Steer Limit

  The aids use the driver's inputs and time only, no telemetry.
]]

local settings = trackside.settings

local core = {}

-- Live state, read by the dashboard.
core.input = { thr = 0, steer = 0 }          -- raw sticks, -1..1
core.proc = { thr = 0, steer = 0 }           -- after the aid pipeline, -1..1
core.out = { drive = 1.0, strmul = 1.0 }     -- multipliers for the mixes
core.ok = true                               -- false if the last update() raised an error
core.aidsOn = true                           -- false while the Aids Switch is off

-- Aid Test (Check setup page): both aids pulse between TEST_MUL and x1.0 every
-- TEST_PHASE seconds, so Check setup can compare the channel at the same stick
-- position (curves, expo and rates cancel out) and the pulse shows on the
-- Channels page. Ends by itself after TEST_MAX seconds.
local TEST_MUL = 0.5
local TEST_PHASE = 0.6
local TEST_MAX = 60
core.testUntil = nil
core.testExpired = false     -- set when the test times out (alerts says so)
core.testMul = 1.0           -- multiplier the test is sending now
core.testPhaseAt = 0         -- when testMul last changed
local testStart = 0
function core.setTest(on)
    local now = os.clock()
    core.testUntil = on and (now + TEST_MAX) or nil
    testStart, core.testMul, core.testPhaseAt = now, TEST_MUL, now
end
core.flags = { A = false, T = false, S = false, C = false, D = false }

local STICK_MAX = 1024
local lastTick = nil

local function readStick(key)
    local src = settings.source(key)
    if not src then return 0 end
    local v = src:value() or 0
    v = v / STICK_MAX
    if v > 1 then v = 1 elseif v < -1 then v = -1 end
    return v
end

-- --- aid stages ----------------------------------------------------------
-- Each stage reads settings, changes st.thr / st.steer (only ever towards 0)
-- and sets its letter while it is actually changing the output. They use the
-- driver's inputs and time only (no telemetry).

local OFF = settings.OFF
local get = settings.get
local abs = math.abs
local MAX_CUT = 0.6          -- most that steer cut / corner brake / steer limit remove
local ACTIVE = 0.02          -- change that lights a letter

local function on(key)
    local v = get(key)
    return v ~= nil and v ~= OFF
end

-- Brake Direction: Negative (1) = trigger below centre brakes.
local function isBrake(thr)
    if get("brakeDir") == 2 then return thr > 0 end
    return thr < 0
end

-- Traction Control: throttle may only rise at a limited rate; release is
-- instant. 0% = 0.1 s from zero to full, 100% = 1.0 s.
-- The mixer applies a new stick position about one Lua update before the
-- source's new multiplier arrives. At rest the throttle channel is ~0 anyway,
-- so Throttle Aid waits at tcRest (the rise allowed in ~one update) instead
-- of x1.0: the first frame of a sudden launch is then small, not full.
local tcOut = 0
local tcRest = nil
local TC_LAG = 0.03          -- s, about one source update
local function tractionControl(st)
    local fl = core.flags
    local thr = st.thr
    local fwd = (not isBrake(thr)) and abs(thr) or 0
    if not on("traction") then
        tcOut, tcRest, fl.T = fwd, nil, false
        return
    end
    local rampTime = 0.1 + 0.9 * get("traction") / 100
    tcRest = TC_LAG / rampTime
    if tcRest > 1 then tcRest = 1 end
    local limit = tcOut + st.dt / rampTime
    local outFwd = fwd
    if fwd > limit then outFwd = limit end
    tcOut = outFwd
    fl.T = fwd - outFwd > ACTIVE
    if fwd > 0 then st.thr = (thr < 0) and -outFwd or outFwd end
end

-- Steer Cut Throttle: less throttle the more you steer.
local function steerCutThrottle(st)
    local fl = core.flags
    if not on("steerCut") or isBrake(st.thr) then
        fl.S = false
        return
    end
    local cut = get("steerCut") / 100 * abs(st.steer) * MAX_CUT
    st.thr = st.thr * (1 - cut)
    fl.S = cut > ACTIVE and abs(st.thr) > ACTIVE
end

-- Corner Brake: less brake the more you steer.
local function cornerBrake(st)
    local fl = core.flags
    if not on("cornerBrake") or not isBrake(st.thr) then
        fl.C = false
        return
    end
    local cut = get("cornerBrake") / 100 * abs(st.steer) * MAX_CUT
    st.thr = st.thr * (1 - cut)
    fl.C = cut > ACTIVE and abs(st.thr) > ACTIVE
end

-- ABS: past ABS Trigger the brake pulses. Each cycle (1 / frequency) holds
-- full brake for half the cycle plus the hold time, then drops to Brake Floor.
-- Dynamic: deeper brake moves the rate toward Dynamic Target, eases the floor
-- toward 60% of Brake Floor and the hold toward Dynamic Min Delay. Corner ABS
-- Hz and Corner Delay do the same from steering; the shorter hold wins.
local absPhase = 0
local function absStage(st, rawThr)
    local fl = core.flags
    local mode = get("absMode") or 1
    local rawBrake = isBrake(rawThr) and abs(rawThr) or 0
    local trig = (get("absTrigger") or 30) / 100
    if mode == 1 or rawBrake < trig or not isBrake(st.thr) then
        absPhase, fl.A = 0, false
        return
    end
    local steer = abs(st.steer)
    local freq = get("absFreq") or 5
    local floorPct = (get("brakeFloor") or 40) / 100
    local hold = (get("pulseDelay") or 50) / 1000
    if mode == 3 then
        local depth = trig < 1 and (rawBrake - trig) / (1 - trig) or 1
        freq = freq + ((get("dynTarget") or freq) - freq) * depth
        floorPct = floorPct * (1 - 0.4 * depth)
        if on("dynMinDelay") then
            local dynHold = hold + (get("dynMinDelay") / 1000 - hold) * depth
            if dynHold < hold then hold = dynHold end
        end
    end
    if on("cornerAbsHz") then freq = freq + get("cornerAbsHz") * steer end
    if on("cornerDelay") then
        local cHold = hold + (get("cornerDelay") / 1000 - hold) * steer
        if cHold < hold then hold = cHold end
    end
    if freq < 1 then freq = 1 end
    local period = 1 / freq
    local fullLen = period * 0.5 + hold
    if fullLen > period * 0.85 then fullLen = period * 0.85 end

    absPhase = absPhase + st.dt
    if absPhase >= period then absPhase = absPhase % period end
    fl.A = true
    if absPhase >= fullLen then st.thr = st.thr * floorPct end
end

-- Steer Limit: past Steer Limit Start, steering travel shrinks with throttle,
-- up to MAX_CUT at full throttle and 100%.
local function steerLimit(st)
    local fl = core.flags
    local thr = st.thr
    local start = (get("steerLimitStart") or 50) / 100
    local fwd = (not isBrake(thr)) and abs(thr) or 0
    if not on("steerLimit") or fwd <= start or start >= 1 then
        fl.D = false
        return
    end
    local shrink = get("steerLimit") / 100 * MAX_CUT * (fwd - start) / (1 - start)
    st.steer = st.steer * (1 - shrink)
    fl.D = shrink > ACTIVE and abs(st.steer) > ACTIVE
end

local function ratio(processed, raw)
    if raw > -0.01 and raw < 0.01 then return 1.0 end
    return processed / raw
end

-- Both sources and the widget call update(); the pipeline runs at most once
-- per MIN_STEP so it isn't repeated within one Ethos loop.
local MIN_STEP = 0.004
local st = { thr = 0, steer = 0, dt = 0 }   -- reused every run (no per-tick allocation)

function core.update()
    local now = os.clock()
    if lastTick and now - lastTick < MIN_STEP then return end
    st.dt = lastTick and (now - lastTick) or 0
    lastTick = now
    core.ok = false     -- set again only if the whole pipeline finishes

    settings.ensureModel()

    local thr = readStick("throttleSrc")
    local steer = readStick("steerSrc")
    core.input.thr, core.input.steer = thr, steer

    st.thr, st.steer = thr, steer
    tractionControl(st)
    steerCutThrottle(st)
    cornerBrake(st)
    absStage(st, thr)
    steerLimit(st)

    -- Aids Switch off: the sticks pass straight through and no aid shows active.
    local sw = settings.source("aidsSrc")
    core.aidsOn = not sw or sw:state() == true
    if core.aidsOn then
        core.proc.thr, core.proc.steer = st.thr, st.steer
        core.out.drive = ratio(st.thr, thr)
        core.out.strmul = ratio(st.steer, steer)
        if tcRest and thr > -0.01 and thr < 0.01 then core.out.drive = tcRest end
    else
        local fl = core.flags
        fl.A, fl.T, fl.S, fl.C, fl.D = false, false, false, false, false
        core.proc.thr, core.proc.steer = thr, steer
        core.out.drive, core.out.strmul = 1.0, 1.0
    end
    if core.testUntil then
        if now < core.testUntil then
            local mul = (math.floor((now - testStart) / TEST_PHASE) % 2 == 0) and TEST_MUL or 1.0
            if mul ~= core.testMul then core.testMul, core.testPhaseAt = mul, now end
            core.out.drive, core.out.strmul = mul, mul
        else
            core.testUntil = nil
            core.testExpired = true
        end
    end
    core.ok = true
end

return core
