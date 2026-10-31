--[[
  Rock: hold the Rock Switch and the throttle channel pulses forward and
  reverse to rock a car off its roof. The car is upside down, so the wheels
  are in the air: the rocking comes from the motor's torque reaction, which
  wants short hard pulses. Without a sensor the pulse length and power ramp
  up over Ramp Cycles and start again, so one of the cycles meets the car's
  natural rock period.

  Mixing (SETUP.md): the Rock source sits on an Add line after the Throttle
  Aid Multiply line. While rocking, Throttle Aid sends 0 so the trigger line
  contributes nothing and the channel is the rock waveform alone. A missing
  Rock source adds 0, so the line needs no LS1 guard.

  The ESC decides whether reverse works at all. Most car ESCs won't go into
  reverse straight from forward, so Reverse Style builds the sequence:
      Direct       F  R  F  R ...            (crawler / instant-reverse ESCs)
      Via neutral  F  N  R  N ...            (N = Neutral Dwell, the ESC's reverse delay)
      Double tap   F  N  T  N  R  N ...      (T = a brake tap, then reverse)
  Reverse is on the brake side of the trigger (Brake Direction).

  Safety: starts only once the switch has been seen off since boot, only with
  the trigger near centre, stops when the switch is released, when the
  trigger is pulled past TRIG_ABORT, or after Hold Limit seconds. After a stop
  the switch must be released before it can start again.

  rock.update() runs from core.update() (hot path: no allocation per tick).
]]

local settings = trackside.settings

local rock = {}

rock.active = false      -- sending pulses
rock.level = 0           -- -1..1, what the Rock source sends
rock.step = nil          -- "F", "R", "T" or "N" while active (Check setup)
rock.cycle = 0           -- 1-based cycle of the current hold (Check setup)
rock.stopped = nil       -- "limit" or "trigger" when it stopped by itself (alerts.lua clears it)

local get = settings.get
local abs = math.abs

local TRIG_START = 0.15  -- trigger must be within this of centre to start
local TRIG_ABORT = 0.30  -- pulling the trigger past this stops the rock

-- Step sequences per Reverse Style (settings choice index).
local SEQ = {
    { "F", "R" },
    { "F", "N", "R", "N" },
    { "F", "N", "T", "N", "R", "N" },
}

local armed = false      -- switch seen off since boot
local latched = false    -- stopped by itself: wait for the switch to be released
local startAt = 0        -- when the hold started
local stepIdx = 0        -- index into the sequence
local stepAt = 0         -- when the current step began
local stepLen = 0        -- s, length of the current step
local cycle = 0          -- 0-based cycle of the hold
local fwd = 1            -- +1 or -1: trigger side that is forward

-- Pulse length and power ramp from Start to Max over Ramp Cycles, then wrap.
local function ramp()
    local cycles = get("rockCycles") or 6
    local n = cycle % cycles
    if cycles <= 1 then return 1 end
    return n / (cycles - 1)
end

local function beginStep(now, seq)
    stepIdx = stepIdx + 1
    if stepIdx > #seq then
        stepIdx = 1
        cycle = cycle + 1
    end
    local kind = seq[stepIdx]
    local r = ramp()
    if kind == "F" or kind == "R" then
        local pStart = (get("rockPulseStart") or 100) / 1000
        local pMax = (get("rockPulseMax") or 400) / 1000
        if pMax < pStart then pMax = pStart end
        stepLen = pStart + (pMax - pStart) * r
        local wStart = (get("rockPowerStart") or 60) / 100
        local wMax = (get("rockPowerMax") or 100) / 100
        if wMax < wStart then wMax = wStart end
        local power = wStart + (wMax - wStart) * r
        rock.level = (kind == "F") and fwd * power or -fwd * power
    elseif kind == "T" then
        stepLen = (get("rockDwell") or 150) / 1000
        rock.level = -fwd * ((get("rockPowerStart") or 60) / 100)
    else
        stepLen = (get("rockDwell") or 150) / 1000
        rock.level = 0
    end
    rock.step = kind
    rock.cycle = cycle + 1
    stepAt = now
end

local function stop(why)
    rock.active = false
    rock.level = 0
    rock.step = nil
    if why then
        rock.stopped = why
        latched = true
    end
end

local function start(now)
    fwd = (get("brakeDir") == 2) and -1 or 1
    rock.active = true
    startAt = now
    stepIdx = 0
    cycle = 0
    beginStep(now, SEQ[get("rockStyle") or 2] or SEQ[2])
    trackside.audio.haptic(".")
end

-- thr: raw trigger, -1..1
function rock.update(now, thr)
    local sw = settings.source("rockSrc")
    local held = sw ~= nil and sw:state() == true

    if not held then
        if rock.active then stop(nil) end
        armed, latched = true, false
        return
    end

    if rock.active then
        if abs(thr) > TRIG_ABORT then
            stop("trigger")
            return
        end
        local limit = get("rockLimit") or 6
        if now - startAt >= limit then
            stop("limit")
            return
        end
        if now - stepAt >= stepLen then
            beginStep(now, SEQ[get("rockStyle") or 2] or SEQ[2])
        end
        return
    end

    if not armed or latched then return end
    if abs(thr) > TRIG_START then return end
    start(now)
end

return rock
