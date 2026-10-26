--[[
  Telemetry for the dashboard.

  telemetry.get(key) returns a number or nil (no data). Keys:
    connected, lq, snr, txpower, pack, current, used, fuel, rpm, esc_temp, motor_temp, txbatt

  In the Ethos simulator, values come from SCRIPTS:/trackside.user/sim/sensors.lua,
  written by the sensor tool (bin/sensors/sensors.py) and re-read every 2 s. On a radio they come
  from real sensors, looked up by name.

  Real sensor names are a first guess per receiver system and still need
  checking on hardware (see docs/ROADMAP.md open questions).
]]

local telemetry = {}

local SIM_FILE = "SCRIPTS:/trackside.user/sim/sensors.lua"
local SIM_READ_EVERY = 2.0       -- seconds (simulator only)
local LOOKUP_RETRY = 2.0         -- seconds between retries for a missing sensor

local isSim = system.getVersion().simulation == true
telemetry.simulation = isSim

-- Candidate sensor names, tried in order (ELRS / FrSky / generic).
local NAMES = {
    lq = { "RQly", "LQ" },
    snr = { "RSNR", "SNR" },
    txpower = { "TPWR", "TX Power" },
    pack = { "RxBt", "VFAS", "LiPo", "Batt", "A1" },
    current = { "Curr", "Current" },
    used = { "Capa", "Consumption" },
    fuel = { "Fuel", "Bat%", "Batt%" },     -- a real fuel sensor; ours is "Pack Fuel"
    rpm = { "RPM", "ERPM" },
    esc_temp = { "ESC Temp", "Tmp1", "Temp1" },
    motor_temp = { "Motor Temp", "Tmp2", "Temp2" },
}

-- --- simulator ---------------------------------------------------------------
-- Values are resolved (jitter applied) once per file read into a reused table,
-- so they only change every SIM_READ_EVERY seconds, not on every lookup.
local sim = { values = {}, ok = false, readAt = -math.huge }

local function readSim(now)
    if now - sim.readAt < SIM_READ_EVERY then return end
    sim.readAt = now
    local values = sim.values
    for k in pairs(values) do values[k] = nil end
    sim.ok = false
    local chunk = loadfile(SIM_FILE)
    if not chunk then return end
    local ok, t = pcall(chunk)
    if not ok or type(t) ~= "table" then return end
    sim.ok = true
    for k, v in pairs(t) do
        if type(v) == "table" and type(v.value) == "number" then
            local value = v.value
            if v.jitter and v.jitter > 0 and value ~= 0 then
                value = value * (1 + (math.random() * 2 - 1) * v.jitter / 100)
            end
            values[k] = value
        end
    end
end

local function simGet(key)
    return sim.values[key]
end

-- --- real sensors ------------------------------------------------------------
local found = {}       -- key -> source
local retryAt = {}     -- key -> time of next lookup

local function lookup(key, now)
    local src = found[key]
    if src then return src end
    if (retryAt[key] or 0) > now then return nil end
    retryAt[key] = now + LOOKUP_RETRY
    for _, name in ipairs(NAMES[key] or {}) do
        local ok, s = pcall(system.getSource, name)
        if ok and s then
            found[key] = s
            return s
        end
    end
    return nil
end

local txBattSrc, telemActiveSrc

local function realGet(key, now)
    if key == "connected" then
        telemActiveSrc = telemActiveSrc or system.getSource({ category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE })
        if not telemActiveSrc then return nil end
        return (telemActiveSrc:state() and 1) or 0
    end
    local src = lookup(key, now)
    return src and src:value() or nil
end

-- --- public ------------------------------------------------------------------
function telemetry.get(key)
    local now = os.clock()

    if key == "txbatt" then
        txBattSrc = txBattSrc or system.getSource({ category = CATEGORY_SYSTEM, member = MAIN_VOLTAGE })
        return txBattSrc and txBattSrc:value() or nil
    end

    if isSim then
        readSim(now)
        if sim.ok then
            -- When the sim says the link is lost, every link sensor reads as no data.
            local conn = simGet("connected")
            if key ~= "connected" and conn == 0 then return nil end
            local v = simGet(key)
            if key == "fuel" and simGet("fuel_on") ~= 1 then return nil end   -- sim: no fuel sensor fitted
            return v
        end
    end
    return realGet(key, now)
end

-- Forget cached sensors (e.g. after a model change).
function telemetry.reset()
    found, retryAt = {}, {}
    telemActiveSrc = nil
end

return telemetry
