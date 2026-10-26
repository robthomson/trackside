--[[
  Trackside - race dashboard and drive aids for the FrSky Velox VX10 (Ethos).
  Phase 1 feature spec: docs/FEATURES.md.

  Registers:
    - Lua sources "Drive" and "StrMul": multipliers used on MULTIPLY mix lines
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

local function sourceDrive()
    return {
        key = "tsDrv",
        name = "Drive",
        init = function(source)
            source:decimals(2)
            source:value(1.0)
        end,
        wakeup = function(source)
            trackside.core.update()
            source:value(trackside.core.out.drive)
        end,
    }
end

local function sourceStrMul()
    return {
        key = "tsStr",
        name = "StrMul",
        init = function(source)
            source:decimals(2)
            source:value(1.0)
        end,
        wakeup = function(source)
            trackside.core.update()
            source:value(trackside.core.out.strmul)
        end,
    }
end

local function init()
    system.registerSource(sourceDrive())
    system.registerSource(sourceStrMul())
    system.registerWidget(load("widget/home.lua"))
    print(string.format("[trackside] boot %.3fs, RAM %d KB", os.clock() - bootAt, math.floor(collectgarbage("count"))))
end

return { init = init }
