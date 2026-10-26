--[[
  Trackside - race dashboard and drive aids for the FrSky Velox VX10 (Ethos).
  Phase 1 feature spec: docs/FEATURES.md.

  Registers:
    - Lua sources "Throttle Aid" and "Steer Aid": multipliers used
      on Multiply mix lines for the throttle and steering channels
    - Widget "Trackside": the race dashboard
    - Settings (BRK / DRV / SET / VOLT) on the widget's Configure page
]]

local BASE = "SCRIPTS:/trackside/"
local bootAt = os.clock()

-- One shared table for every part of the suite (Ethos runs all scripts in one Lua state).
trackside = trackside or {}
trackside.BASE = BASE
trackside.VERSION = "0.1.0"

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

-- The settings form is UI only: load it the first time Configure opens.
function trackside.getForm()
    if not trackside.form then trackside.form = load("lib/form.lua") end
    return trackside.form
end

-- The mixer reads a Lua source's raw value on a 1024 = 100% scale (checked in
-- the VX10 sim: a value of 1.00 with 2 decimals multiplied throttle by ~0.098).
-- So a multiplier m is sent as round(m * 1024), with no decimals.
local MIX_SCALE = 1024
local floor = math.floor

local function aidSource(key, name, field)
    local last = nil
    return {
        key = key,
        name = name,
        init = function(source)
            source:decimals(0)
            source:value(MIX_SCALE)
            last = MIX_SCALE
        end,
        wakeup = function(source)
            trackside.core.update()
            local v = floor(trackside.core.out[field] * MIX_SCALE + 0.5)
            if v ~= last then
                last = v
                source:value(v)
            end
        end,
    }
end

local function init()
    -- Keys are saved in models: never change them.
    system.registerSource(aidSource("tsDrv", "Throttle Aid", "drive"))
    system.registerSource(aidSource("tsStr", "Steer Aid", "strmul"))
    system.registerWidget(load("widget/home.lua"))
    print(string.format("[trackside] boot %.3fs, RAM %d KB", os.clock() - bootAt, math.floor(collectgarbage("count"))))
end

return { init = init }
