--[[
  Settings schema + per-model persistence.

  Ranges, steps and defaults for the Phase 1 feature set (docs/FEATURES.md).
  Inputs and switches use Ethos source pickers, so any stick, switch or channel
  can drive them.

  OFF is stored as -1 for settings that support it ("off = true").
]]

local OFF = -1

local settings = { OFF = OFF }

-- kind: "num"    number field (min/max/step, optional off)
--       "choice" list of labels, value is 1-based index
--       "source" Ethos source picker, stored as {category, member}
--       "switch" Ethos switch picker (switch positions, logic switches), stored the same way
settings.schema = {
    -- BRK - brake / ABS
    { key = "absMode",       tab = "BRK",  label = "ABS Mode",          kind = "choice", choices = { "OFF", "Static", "Dynamic" }, default = 1 },
    { key = "absFreq",       tab = "BRK",  label = "ABS Frequency",     kind = "num", min = 5,  max = 33,  step = 1, unit = "Hz", default = 5 },
    { key = "brakeFloor",    tab = "BRK",  label = "Brake Floor",       kind = "num", min = 0,  max = 100, step = 5, unit = "%",  default = 40 },
    { key = "pulseDelay",    tab = "BRK",  label = "Pulse Delay",       kind = "num", min = 0,  max = 100, step = 5, unit = "ms", default = 50 },
    { key = "absTrigger",    tab = "BRK",  label = "ABS Trigger",       kind = "num", min = 5,  max = 100, step = 5, unit = "%",  default = 30 },
    { key = "dynTarget",     tab = "BRK",  label = "Dynamic Target",    kind = "num", min = 5,  max = 33,  step = 1, unit = "Hz", default = 6 },
    { key = "dynMinDelay",   tab = "BRK",  label = "Dynamic Min Delay", kind = "num", min = 5,  max = 100, step = 5, unit = "ms", default = OFF, off = true },

    -- DRV - drive / stability
    -- Aids Switch: any switch; off = every aid sends x1.0. Not set = aids always on.
    { key = "aidsSrc",       tab = "DRV",  label = "Aids Switch",       kind = "switch", default = nil },
    { key = "traction",      tab = "DRV",  label = "Traction Control",  kind = "num", min = 0,  max = 100, step = 5, unit = "%",  default = OFF, off = true },
    { key = "steerCut",      tab = "DRV",  label = "Steer Cut Throttle",kind = "num", min = 0,  max = 100, step = 5, unit = "%",  default = OFF, off = true },
    { key = "cornerBrake",   tab = "DRV",  label = "Corner Brake",      kind = "num", min = 0,  max = 100, step = 5, unit = "%",  default = OFF, off = true },
    { key = "cornerAbsHz",   tab = "DRV",  label = "Corner ABS Hz",     kind = "num", min = 0,  max = 7,   step = 1, unit = "Hz", default = OFF, off = true },
    { key = "cornerDelay",   tab = "DRV",  label = "Corner Delay",      kind = "num", min = 5,  max = 100, step = 5, unit = "ms", default = OFF, off = true },
    { key = "steerLimit",    tab = "DRV",  label = "Steer Limit",       kind = "num", min = 0,  max = 100, step = 5, unit = "%",  default = OFF, off = true },
    { key = "steerLimitStart",tab = "DRV", label = "Steer Limit Start", kind = "num", min = 0,  max = 100, step = 5, unit = "%",  default = 50 },

    -- ROCK - rock the car off its roof (lib/rock.lua). Rock Switch not set = feature off.
    { key = "rockSrc",       tab = "ROCK", label = "Rock Switch",       kind = "switch", default = nil },
    { key = "rockStyle",     tab = "ROCK", label = "Reverse Style",     kind = "choice", choices = { "Direct", "Via neutral", "Double tap" }, default = 2 },
    { key = "rockDwell",     tab = "ROCK", label = "Neutral Dwell",     kind = "num", min = 20, max = 500,  step = 10, unit = "ms", default = 150 },
    { key = "rockPulseStart",tab = "ROCK", label = "Pulse Start",       kind = "num", min = 50, max = 1000, step = 10, unit = "ms", default = 100 },
    { key = "rockPulseMax",  tab = "ROCK", label = "Pulse Max",         kind = "num", min = 50, max = 1000, step = 10, unit = "ms", default = 400 },
    { key = "rockCycles",    tab = "ROCK", label = "Ramp Cycles",       kind = "num", min = 1,  max = 12,   step = 1,  default = 6 },
    { key = "rockPowerStart",tab = "ROCK", label = "Power Start",       kind = "num", min = 10, max = 100,  step = 5,  unit = "%",  default = 60 },
    { key = "rockPowerMax",  tab = "ROCK", label = "Power Max",         kind = "num", min = 10, max = 100,  step = 5,  unit = "%",  default = 100 },
    { key = "rockLimit",     tab = "ROCK", label = "Hold Limit",        kind = "num", min = 1,  max = 15,   step = 1,  unit = "s",  default = 6 },

    -- IN - inputs and the channels the aids drive
    { key = "throttleSrc",   tab = "IN",   label = "Throttle Input",    kind = "source", default = { "ANALOG", 1 } },
    { key = "steerSrc",      tab = "IN",   label = "Steering Input",    kind = "source", default = { "ANALOG", 0 } },
    -- Only used by Check setup to compare input and channel output.
    { key = "throttleCh",    tab = "IN",   label = "Throttle Channel",  kind = "source", default = { "CHANNEL", 1 } },
    { key = "steerCh",       tab = "IN",   label = "Steering Channel",  kind = "source", default = { "CHANNEL", 0 } },
    { key = "brakeDir",      tab = "IN",   label = "Brake Direction",   kind = "choice", choices = { "Negative", "Positive" }, default = 1 },
    { key = "graphDir",      tab = "IN",   label = "Graph Direction",   kind = "choice", choices = { "Normal", "Reversed" }, default = 1 },

    -- LAP - timer and laps
    { key = "timer",         tab = "LAP",  label = "Timer",             kind = "num", min = 1,  max = 45,  step = 1, unit = "min", default = 5 },
    { key = "timerSrc",      tab = "LAP",  label = "Timer Switch",      kind = "switch", default = nil },
    { key = "showTimer",     tab = "LAP",  label = "Show Timer",        kind = "choice", choices = { "OFF", "ON" }, default = 1 },
    { key = "lapSrc",        tab = "LAP",  label = "Lap Switch",        kind = "switch", default = nil },
    { key = "lapHaptic",     tab = "LAP",  label = "Lap Haptic",        kind = "choice", choices = { "OFF", "ON" }, default = 2 },
    -- Speaks each lap time ("Best lap" first on a new best).
    { key = "lapCallout",    tab = "LAP",  label = "Lap Callout",       kind = "choice", choices = { "OFF", "ON" }, default = 2 },
    { key = "throttleStartLap", tab = "LAP", label = "Throttle Start Lap", kind = "choice", choices = { "OFF", "ON" }, default = 1 },

    -- VOLT - battery: alarm and fuel
    { key = "battType",      tab = "VOLT", label = "Battery Type",      kind = "choice", choices = { "LiPo", "LiHV" }, default = 1 },
    { key = "cells",         tab = "VOLT", label = "Cells",             kind = "choice", choices = { "Auto", "1S", "2S", "3S", "4S", "5S", "6S" }, default = 1 },
    { key = "voltAlarm",     tab = "VOLT", label = "Voltage Alarm",     kind = "choice", choices = { "OFF", "ON" }, default = 1 },
    -- centivolts: 320 = 3.20 V
    { key = "alarmCell",     tab = "VOLT", label = "Alarm Cell Voltage",kind = "num", min = 320, max = 390, step = 5, unit = "V", decimals = 2, default = 350 },
    -- Fuel by mAh used (needs a consumption sensor). OFF = estimate from voltage.
    { key = "packCapacity",  tab = "VOLT", label = "Pack Capacity",     kind = "num", min = 500, max = 10000, step = 100, unit = "mAh", default = OFF, off = true },
    -- "Fuel <n> percent" at 50, 30, 20 and 10 (lib/alerts.lua).
    { key = "fuelCallouts",  tab = "VOLT", label = "Fuel Callouts",     kind = "choice", choices = { "OFF", "ON" }, default = 2 },
}

-- Pages in the Trackside tool, in menu order (CHECK is the live check page).
settings.PAGES = {
    { id = "CHECK", title = "Check setup" },
    { id = "BRK",   title = "Brake / ABS" },
    { id = "DRV",   title = "Drive aids" },
    { id = "ROCK",  title = "Rock" },
    { id = "IN",    title = "Inputs" },
    { id = "LAP",   title = "Timer & laps" },
    { id = "VOLT",  title = "Battery" },
}

settings.byKey = {}
for _, s in ipairs(settings.schema) do
    settings.byKey[s.key] = s
end

-- Current values for the loaded model.
settings.values = {}

local CATEGORY = { ANALOG = CATEGORY_ANALOG, CHANNEL = CATEGORY_CHANNEL, SWITCH = CATEGORY_SWITCH_POSITION }

local function defaultValue(s)
    if s.kind == "source" and s.default then
        return { CATEGORY[s.default[1]], s.default[2] }
    end
    return s.default
end

function settings.resetDefaults()
    for _, s in ipairs(settings.schema) do
        settings.values[s.key] = defaultValue(s)
    end
end

function settings.get(key)
    return settings.values[key]
end

function settings.set(key, value)
    settings.values[key] = value
    settings.dirty = true
end

function settings.isOff(key)
    return settings.values[key] == OFF
end

-- Resolve a "source" setting to an Ethos source object (cached per change).
local sourceCache = {}
function settings.source(key)
    local v = settings.values[key]
    if not v then return nil end
    local c = sourceCache[key]
    if c and c.cat == v[1] and c.mem == v[2] then return c.src end
    local src = system.getSource({ category = v[1], member = v[2] })
    sourceCache[key] = { cat = v[1], mem = v[2], src = src }
    return src
end

-- Persistence: one small Lua table file per model, read back with loadfile
-- (Ethos io has no read("a")). Kept outside the script folder so a deploy
-- (which mirrors src/trackside) never wipes user settings.
local USER_DIR = "SCRIPTS:/trackside.user/"
local DIR = USER_DIR .. "models/"
settings.loadedFor = nil

local function modelFile()
    local name = (model and model.name and model.name()) or "default"
    name = name:gsub("[^%w%-_]", "_")
    return DIR .. name .. ".lua", name
end

function settings.load()
    settings.resetDefaults()
    local path, name = modelFile()
    settings.loadedFor = name
    settings.dirty = false
    local chunk = loadfile(path)
    if not chunk then return end
    local ok, saved = pcall(chunk)
    if not ok or type(saved) ~= "table" then return end
    for _, s in ipairs(settings.schema) do
        local v = saved[s.key]
        if s.kind == "source" or s.kind == "switch" then
            if type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" then
                settings.values[s.key] = { v[1], v[2] }
            elseif v == false then
                settings.values[s.key] = nil
            end
        elseif type(v) == "number" then
            settings.values[s.key] = v
        end
    end
end

function settings.save()
    local path = modelFile()
    if os.mkdir then
        pcall(os.mkdir, USER_DIR)
        pcall(os.mkdir, DIR)
    end
    local f = io.open(path, "w")
    if not f then
        print("[trackside] could not write " .. path)
        return false
    end
    f:write("return {\n")
    for _, s in ipairs(settings.schema) do
        local v = settings.values[s.key]
        if s.kind == "source" or s.kind == "switch" then
            -- false = explicitly cleared, so the default source is not restored
            if v then
                f:write("  ", s.key, " = { ", v[1], ", ", v[2], " },\n")
            else
                f:write("  ", s.key, " = false,\n")
            end
        elseif v ~= nil then
            f:write("  ", s.key, " = ", tostring(v), ",\n")
        end
    end
    f:write("}\n")
    f:close()
    settings.dirty = false
    return true
end

-- Reload when the active model changes. Called from the drive-aid loop, so the
-- model name (a string build) is only checked once a second unless forced.
local CHECK_EVERY = 1.0
local checkedAt = -math.huge

function settings.ensureModel(force)
    local now = os.clock()
    if not force and settings.loadedFor and now - checkedAt < CHECK_EVERY then return end
    checkedAt = now
    local _, name = modelFile()
    if name ~= settings.loadedFor then settings.load() end
end

settings.resetDefaults()

return settings
