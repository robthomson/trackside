--[[
  Lap timer and session countdown. laps.update() runs on every Trackside
  update (switch presses need better than the 0.5 s background tick).

  Lap Switch (Timer & laps page)
    press      first press starts the clock; each later press ends a lap.
               Presses under MIN_LAP apart are ignored (debounce).
    hold       HOLD seconds resets the session (laps.holdFrac drives the bar).
    Throttle Start Lap: the first throttle starts the clock instead.
    Each lap: Lap Haptic buzz, Lap Callout speaks the time ("Best lap" first
    on a new best, and laps.bestAt makes the BEST box flash).

  Timer Switch
    press      start / pause; restart after it has run out.
    hold       HOLD seconds resets it to Timer minutes.
    "One minute" at 1:00 left, "Time up" at 0:00, then haptic every
    BUZZ_EVERY seconds for BUZZ_FOR seconds.
]]

local settings = trackside.settings
local core = trackside.core
local audio = trackside.audio

local MIN_LAP = 3.0
local HOLD = 1.2
local KEEP = 100             -- laps kept per session
local BUZZ_EVERY, BUZZ_FOR = 10, 60
local START_THR = 0.10       -- throttle that starts the clock (Throttle Start Lap)

local laps = {
    running = false,  -- lap clock running
    count = 0,
    last = nil, best = nil, total = 0,
    bestAt = nil,     -- os.clock() of the latest new best (dashboard flash)
    holdFrac = nil,   -- 0..1 while the lap switch is held towards a reset
    list = {},        -- lap times, oldest first (max KEEP)

    timerLeft = nil,  -- seconds left on the countdown
    timerRunning = false,
    timerExpired = false,
}

local lapStart = nil
local lapDown, lapDownAt, lapHeld = false, nil, false
local tmDown, tmDownAt, tmHeld = false, nil, false
local timerSet = nil          -- Timer minutes the countdown was set from
local oneMinSaid, expiredAt, lastBuzz = false, nil, nil
local lastAt = nil

local function switchOn(key)
    local s = settings.source(key)
    return s ~= nil and s:state() == true
end

local function isThrottle(thr)
    if settings.get("brakeDir") == 2 then return thr < -START_THR end
    return thr > START_THR
end

function laps.reset()
    laps.running, laps.count, laps.last, laps.best, laps.total = false, 0, nil, nil, 0
    laps.bestAt, laps.holdFrac = nil, nil
    for i = #laps.list, 1, -1 do laps.list[i] = nil end
    lapStart = nil
end

function laps.resetTimer()
    timerSet = settings.get("timer") or 5
    laps.timerLeft = timerSet * 60
    laps.timerRunning, laps.timerExpired = false, false
    oneMinSaid, expiredAt, lastBuzz = false, nil, nil
end

-- Current lap time in seconds (0 before the clock starts).
function laps.current(now)
    if not laps.running or not lapStart then return 0 end
    return (now or os.clock()) - lapStart
end

local function sayLap(t, isBest)
    if settings.get("lapCallout") ~= 2 then return end
    if isBest then audio.say("best_lap") end
    audio.number(math.floor(t * 10 + 0.5) / 10, UNIT_SECOND, 1)
end

local function endLap(now)
    local t = now - lapStart
    lapStart = now
    laps.count = laps.count + 1
    laps.last = t
    laps.total = laps.total + t
    local list = laps.list
    if #list >= KEEP then table.remove(list, 1) end
    list[#list + 1] = t
    local isBest = not laps.best or t < laps.best
    if isBest then
        laps.best, laps.bestAt = t, now
    end
    if settings.get("lapHaptic") == 2 then audio.haptic(".") end
    sayLap(t, isBest and laps.count > 1)
end

local function lapSwitch(now)
    local down = switchOn("lapSrc")
    if down and not lapDown then
        lapDown, lapDownAt, lapHeld = true, now, false
        if not laps.running then
            laps.running, lapStart = true, now
        elseif now - lapStart >= MIN_LAP then
            endLap(now)
        end
    elseif down and lapDown then
        local held = now - lapDownAt
        if not lapHeld then
            laps.holdFrac = held / HOLD
            if held >= HOLD then
                lapHeld = true
                laps.reset()
                audio.say("laps_reset")
                audio.haptic(". .")
            end
        end
    elseif not down and lapDown then
        lapDown, laps.holdFrac = false, nil
    end

    if not laps.running and settings.get("throttleStartLap") == 2 and isThrottle(core.input.thr) then
        laps.running, lapStart = true, now
    end
end

local function timerSwitch(now, dt)
    local set = settings.get("timer") or 5
    if set ~= timerSet and not laps.timerRunning then laps.resetTimer() end

    local down = switchOn("timerSrc")
    if down and not tmDown then
        tmDown, tmDownAt, tmHeld = true, now, false
    elseif down and tmDown then
        if not tmHeld and now - tmDownAt >= HOLD then
            tmHeld = true
            laps.resetTimer()
            audio.say("timer_reset")
        end
    elseif not down and tmDown then
        tmDown = false
        if not tmHeld then
            if laps.timerExpired then
                laps.resetTimer()
                laps.timerRunning = true
            else
                laps.timerRunning = not laps.timerRunning
            end
        end
    end

    if laps.timerRunning then
        local left = laps.timerLeft - dt
        if left <= 60 and not oneMinSaid and timerSet > 1 then
            oneMinSaid = true
            audio.say("one_minute")
        end
        if left <= 0 then
            left = 0
            laps.timerRunning, laps.timerExpired = false, true
            expiredAt, lastBuzz = now, now
            audio.say("time_up")
            audio.haptic("- - - -")
        end
        laps.timerLeft = left
    elseif laps.timerExpired and expiredAt and now - expiredAt < BUZZ_FOR and now - lastBuzz >= BUZZ_EVERY then
        lastBuzz = now
        audio.haptic("- - - -")
    end
end

function laps.update()
    local now = os.clock()
    if lastAt and now - lastAt < 0.01 then return end   -- several callers per Ethos loop: run once
    local dt = lastAt and (now - lastAt) or 0
    lastAt = now
    if not laps.timerLeft then laps.resetTimer() end
    lapSwitch(now)
    timerSwitch(now, dt)
end

return laps
