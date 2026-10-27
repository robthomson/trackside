--[[
  Trackside - race dashboard and drive aids for the FrSky Velox VX10 (Ethos).
  Phase 1 feature spec: docs/FEATURES.md.

  Registers:
    - Lua sources "Throttle Aid" and "Steer Aid": multipliers used
      on Multiply mix lines for the throttle and steering channels
    - Telemetry sensor "Trackside" (1 while running): feeds logic switch LS1,
      the Active condition for those lines
    - Widget "Trackside": the race dashboard
    - System tool "Trackside": Check setup (Aid Test) and all settings
]]

local BASE = "SCRIPTS:/trackside/"
local bootAt = os.clock()

-- One shared table for every part of the suite (Ethos runs all scripts in one Lua state).
trackside = trackside or {}
trackside.BASE = BASE
trackside.VERSION = "0.1.0"
-- Build name, stamped by bin/package/build_package.py (e.g. 0.1.0, commit-abc1234).
trackside.BUILD = "dev"

local function load(rel)
    return assert(loadfile(BASE .. rel))()
end

-- Collect garbage a bit sooner than Lua's default (200%), as rfsuite does,
-- so retained RAM doesn't creep. Guarded: not every Lua build has setpause.
pcall(collectgarbage, "setpause", 120)

-- Core modules load eagerly: they run all the time (sources, dashboard).
trackside.settings = load("lib/settings.lua")
trackside.core = load("lib/core.lua")
trackside.telemetry = load("lib/telemetry.lua")
trackside.battery = load("lib/battery.lua")
trackside.diysensor = load("lib/diysensor.lua")
trackside.fuel = load("lib/fuel.lua")
trackside.audio = load("lib/audio.lua")
trackside.alerts = load("lib/alerts.lua")
trackside.laps = load("lib/laps.lua")

-- The settings fields and the tool pages are UI only: loaded on first use.
function trackside.getForm()
    if not trackside.form then trackside.form = load("lib/form.lua") end
    return trackside.form
end

-- The mixer reads a Lua source's raw value on a 1024 = 100% scale (checked in
-- the VX10 sim: a value of 1.00 with 2 decimals multiplied throttle by ~0.098).
-- So a multiplier m is sent as round(m * 1024), with no decimals.
local MIX_SCALE = 1024
local floor = math.floor

-- "Trackside" telemetry sensor: reads 1 while Trackside runs. Logic switch LS1
-- (Trackside > 0) is the Active condition of the Multiply lines, so a missing
-- script switches them off (a missing Lua source multiplies by 0: no steering
-- or throttle). A sensor lives in the model, so Ethos keeps the link even
-- when the scripts are missing. Ethos marks a sensor lost after ~4 s without
-- a value, so it is re-sent every second.
local ALIVE_EVERY = 1.0
local aliveAt = -ALIVE_EVERY
local aliveSensor = trackside.diysensor.new(0x5E10, "Trackside", { min = 0, max = 1 })

local function heartbeat()
    local now = os.clock()
    if now - aliveAt < ALIVE_EVERY then return end
    aliveAt = now
    trackside.aliveAt = now     -- shown on Check setup
    aliveSensor:set(1)
end

-- Battery and fuel run in the background (from the aid sources and the
-- dashboard), so the Pack Fuel sensor keeps updating with no dashboard on screen.
local BG_EVERY = 0.5
local bgAt = -BG_EVERY
function trackside.background()
    local now = os.clock()
    if now - bgAt < BG_EVERY then return end
    bgAt = now
    trackside.battery.update()
    trackside.fuel.update(now)
    trackside.alerts.update(now)
end

-- Safety: an aid may only reduce its channel (0..1). On a Lua error Ethos keeps
-- the source's last value, which could hold the car mid ABS pulse, so any error
-- sends x1.0 (stick passes straight through) until the next good update.
local function aidSource(key, name, field)
    local last = nil
    local reported = false

    local function step(source)
        local core = trackside.core
        core.update()
        -- core.ok is false if this or the other source's update call failed
        local v = core.ok and floor(core.out[field] * MIX_SCALE + 0.5) or MIX_SCALE
        if not (v >= 0) then v = MIX_SCALE end      -- negative or NaN
        if v > MIX_SCALE then v = MIX_SCALE end
        if v ~= last then
            last = v
            source:value(v)
        end
    end

    return {
        key = key,
        name = name,
        init = function(source)
            source:decimals(0)
            source:value(MIX_SCALE)
            last = MIX_SCALE
        end,
        wakeup = function(source)
            trackside.seen[field] = os.clock()     -- shown on Check setup
            pcall(heartbeat)
            pcall(trackside.background)
            pcall(trackside.laps.update)
            local ok, err = pcall(step, source)
            if not ok then
                if last ~= MIX_SCALE then
                    last = MIX_SCALE
                    source:value(MIX_SCALE)
                end
                if not reported then
                    reported = true
                    print("[trackside] " .. name .. " error, aid released: " .. tostring(err))
                    if not trackside.aidsOffSaid then     -- once, not once per source
                        trackside.aidsOffSaid = true
                        pcall(trackside.audio.say, "aids_off")
                        pcall(trackside.audio.haptic, "- - -")
                    end
                end
            end
        end,
    }
end

-- When each aid source last ran (Check setup shows "not running" otherwise).
trackside.seen = {}

-- System tool: a stub here, the pages load from tool/app.lua on first open.
local toolApp = nil
local function tool()
    if not toolApp then toolApp = load("tool/app.lua") end
    return toolApp
end

local toolDef = {
    name = "Trackside",
    icon = lcd.loadMask(BASE .. "tool/gfx/icon.png"),
    create = function() return tool().create() end,
    wakeup = function(state) tool().wakeup(state) end,
    event = function(state, category, value, x, y) return tool().event(state, category, value) end,
    close = function(state) tool().close(state) end,
}

local function init()
    -- Keys are saved in models: never change them.
    system.registerSource(aidSource("tsDrv", "Throttle Aid", "drive"))
    system.registerSource(aidSource("tsStr", "Steer Aid", "strmul"))
    system.registerWidget(load("widget/home.lua"))
    -- The handle lets the dashboard open the tool (system.openPage, Ethos 26.1+).
    trackside.toolHandle = system.registerSystemTool(toolDef)
    print(string.format("[trackside] boot %.3fs, RAM %d KB", os.clock() - bootAt, math.floor(collectgarbage("count"))))
end

return { init = init }
