--[[
  Spoken + haptic alerts, run from trackside.background() (every 0.5 s).

  Voltage alarm (Battery page: Voltage Alarm, Alarm Cell Voltage)
    States: OFF · NOTEL (no cell voltage) · OK · LOW · ALARM.
    Voltage under throttle sags, so only readings taken after REST_DELAY off
    the throttle count. LOW_HOLD seconds of those below the level -> ALARM:
    "Battery low" + cell voltage + haptic, repeated every REPEAT seconds.
    Clears once a resting reading is HYST above the level.

  Fuel callouts (Battery page: Fuel Callouts)
    "Fuel <n> percent" once per pack as fuel passes each of FUEL_LEVELS.
    Levels already below the pack's starting fuel are skipped.

  Aid Test ending by itself (60 s) -> "Aid test off".

  Aids Switch flipped -> "Drive aids on" / "Drive aids off" + a short buzz
  (not at start-up).
]]

local settings = trackside.settings
local battery = trackside.battery
local fuel = trackside.fuel
local core = trackside.core
local audio = trackside.audio

local alerts = { state = "OFF" }

local LOW_HOLD = 5.0
local REPEAT = 30.0
local HYST = 0.05
local REST_DELAY = 1.0
local REST_THR = 0.10
local FUEL_LEVELS = { 50, 30, 20, 10 }   -- high to low
local HAPTIC = "- - -"

local lastAt, offSince, lowFor, alarmAt = nil, nil, 0, nil
local aidsWere = nil        -- core.aidsOn at the last update
local fuelSaid = nil        -- lowest level already announced (or skipped) this pack

local function announceLow(cell)
    audio.say("battery_low")
    audio.number(math.floor(cell * 100 + 0.5) / 100, UNIT_VOLT, 2)
    audio.haptic(HAPTIC)
end

local function voltageAlarm(now, dt)
    if settings.get("voltAlarm") ~= 2 then
        alerts.state, lowFor = "OFF", 0
        return
    end
    local cell = battery.cell
    if not cell then
        alerts.state, lowFor = "NOTEL", 0
        return
    end
    local level = (settings.get("alarmCell") or 350) / 100

    local thr = core.input.thr
    if thr < 0 then thr = -thr end
    if thr >= REST_THR then offSince = nil else offSince = offSince or now end
    local resting = offSince and now - offSince >= REST_DELAY

    if alerts.state == "ALARM" then
        if resting and cell >= level + HYST then
            alerts.state, lowFor = "OK", 0
        elseif now - alarmAt >= REPEAT then
            alarmAt = now
            announceLow(cell)
        end
        return
    end

    if not resting then return end
    if cell < level then
        lowFor = lowFor + dt
        alerts.state = "LOW"
        if lowFor >= LOW_HOLD then
            alerts.state, alarmAt = "ALARM", now
            announceLow(cell)
        end
    elseif cell >= level + HYST or alerts.state ~= "LOW" then
        alerts.state, lowFor = "OK", 0
    end
end

local function fuelCallouts()
    local pct = fuel.pct
    if not pct or settings.get("fuelCallouts") ~= 2 then
        fuelSaid = nil
        return
    end
    if not fuelSaid or pct > fuelSaid + 10 then
        -- New pack: skip levels at or above the starting fuel.
        fuelSaid = 101
        for i = 1, #FUEL_LEVELS do
            if FUEL_LEVELS[i] >= pct then fuelSaid = FUEL_LEVELS[i] end
        end
        return
    end
    local crossed = nil
    for i = 1, #FUEL_LEVELS do
        local l = FUEL_LEVELS[i]
        if pct <= l and l < fuelSaid then crossed = l end
    end
    if crossed then
        fuelSaid = crossed
        audio.say("fuel")
        audio.number(crossed, UNIT_PERCENT, 0)
    end
end

function alerts.update(now)
    local dt = lastAt and (now - lastAt) or 0
    lastAt = now
    voltageAlarm(now, dt)
    fuelCallouts()
    if aidsWere ~= nil and core.aidsOn ~= aidsWere then
        audio.say(core.aidsOn and "aids_enabled" or "aids_disabled")
        audio.haptic(".")
    end
    aidsWere = core.aidsOn
    if core.testExpired then
        core.testExpired = false
        audio.say("aidtest_off")
    end
end

return alerts
