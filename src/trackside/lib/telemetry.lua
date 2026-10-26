--[[
  Telemetry for the dashboard.

  telemetry.get(key) returns a number or nil (no data). Keys:
    connected, lq, snr, txpower, pack, current, used, rpm, esc_temp, motor_temp, txbatt

  In the Ethos simulator, values come from SCRIPTS:/trackside.user/sim/sensors.lua,
  written live by the sensor tool (bin/sensors/sensors.py). On a radio they come
  from real sensors, looked up by name.

  Real sensor names are a first guess per receiver system and still need
  checking on hardware (see docs/ROADMAP.md open questions).
]]

local telemetry = {}

local SIM_FILE = "SCRIPTS:/trackside.user/sim/sensors.lua"
local SIM_READ_EVERY = 1.0       -- seconds (simulator only)
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
    rpm = { "RPM", "ERPM" },
    esc_temp = { "ESC Temp", "Tmp1", "Temp1" },
    motor_temp = { "Motor Temp", "Tmp2", "Temp2" },
}

-- --- simulator ---------------------------------------------------------------
local sim = { values = nil, readAt = -math.huge }

local function readSim(now)
    if now - sim.readAt < SIM_READ_EVERY then return end
    sim.readAt = now
    local chunk = loadfile(SIM_FILE)
    if not chunk then
        sim.values = nil
        return
    end
    local ok, t = pcall(chunk)
    sim.values = (ok and type(t) == "table") and t or nil
end

local function simGet(key)
    local v = sim.values and sim.values[key]
    if type(v) ~= "table" or type(v.value) ~= "number" then return nil end
    local value = v.value
    if v.jitter and v.jitter > 0 and value ~= 0 then
        value = value * (1 + (math.random() * 2 - 1) * v.jitter / 100)
    end
    return value
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
        if sim.values then
            -- When the sim says the link is lost, every link sensor reads as no data.
            local conn = simGet("connected")
            if key ~= "connected" and conn == 0 then return nil end
            return simGet(key)
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
