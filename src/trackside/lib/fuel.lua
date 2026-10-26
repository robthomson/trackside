--[[
  Pack fuel (% left), from the best source available:

    1. sensor   a real fuel sensor (e.g. "Fuel" from the ESC): used as is,
                and Trackside publishes nothing.
    2. mAh      Pack Capacity is set and a mAh-used sensor exists: starts from
                the resting voltage, then counts down by mAh used.
    3. voltage  resting-voltage curve. Voltage under load sags, so it is only
                read once the throttle has been off for REST_DELAY (a car
                lifts often); on throttle the value holds. Once driven it
                never goes back up and falls at most MAX_DROP per second.

  For 2 and 3 the result is published as the "Pack Fuel" telemetry sensor.

  A new pack is detected by the voltage rising before the car is driven, or by
  telemetry being gone for UNLOCK_AFTER seconds.
]]

local settings = trackside.settings
local telemetry = trackside.telemetry
local battery = trackside.battery
local diysensor = trackside.diysensor

local fuel = {
    pct = nil,       -- 0..100, or nil while unknown
    mode = nil,      -- "sensor" | "mAh" | "voltage" | nil
}

local SAMPLES = 5            -- readings that must agree before a pack is trusted
local STABLE_SPAN = 0.15     -- V, max spread of those readings (whole pack)
local SETTLE = 1.5           -- s to wait after a pack appears
local UNLOCK_AFTER = 5.0     -- s without pack voltage = pack removed
local FALL_PER_CELL = 0.05   -- V/s per cell: faster drops are treated as sag
local MAX_DROP = 0.5         -- %/s fastest the voltage estimate may fall
local DRIVEN_AT = 0.10       -- throttle (0..1) that counts as driving
local REST_DELAY = 1.0       -- s off throttle before the voltage counts as resting

-- LiPo resting voltage per cell -> %. LiHV is mapped onto it (4.35 V = 4.20 V).
local CURVE = {
    { 3.30, 0 }, { 3.60, 3 }, { 3.69, 10 }, { 3.71, 15 }, { 3.73, 20 }, { 3.75, 25 },
    { 3.77, 30 }, { 3.79, 35 }, { 3.80, 40 }, { 3.82, 45 }, { 3.84, 50 }, { 3.85, 55 },
    { 3.87, 60 }, { 3.91, 65 }, { 3.95, 70 }, { 3.98, 75 }, { 4.02, 80 }, { 4.08, 85 },
    { 4.11, 90 }, { 4.15, 95 }, { 4.20, 100 },
}
local LIHV_FULL = 4.35

local function restPct(cellV)
    if settings.get("battType") == 2 then
        cellV = 3.30 + (cellV - 3.30) * (4.20 - 3.30) / (LIHV_FULL - 3.30)
    end
    if cellV <= CURVE[1][1] then return 0 end
    for i = 2, #CURVE do
        local hi = CURVE[i]
        if cellV <= hi[1] then
            local lo = CURVE[i - 1]
            return lo[2] + (cellV - lo[1]) / (hi[1] - lo[1]) * (hi[2] - lo[2])
        end
    end
    return 100
end

local publish = diysensor.new(0x5E11, "Pack Fuel", { unit = UNIT_PERCENT, decimals = 0, min = 0, max = 100 })

-- Per-pack state (reused tables, no allocation per update).
local ring, ringN, ringI = {}, 0, 0
local st = {
    seenAt = nil, settleUntil = nil, stable = false, driven = false,
    filtV = nil, lastAt = nil, startPct = nil, startUsed = nil, lastV = nil,
    offSince = nil, pctAt = nil,
}

local function resetPack()
    ringN, ringI = 0, 0
    st.seenAt, st.settleUntil, st.stable, st.driven = nil, nil, false, false
    st.filtV, st.lastAt, st.startPct, st.startUsed, st.lastV = nil, nil, nil, nil, nil
    st.offSince, st.pctAt = nil, nil
    fuel.pct, fuel.mode = nil, nil
end

local function addSample(v)
    ringI = ringI % SAMPLES + 1
    ring[ringI] = v
    if ringN < SAMPLES then ringN = ringN + 1 end
end

local function samplesStable()
    if ringN < SAMPLES then return false end
    local lo, hi = ring[1], ring[1]
    for i = 2, SAMPLES do
        local v = ring[i]
        if v < lo then lo = v elseif v > hi then hi = v end
    end
    return hi - lo <= STABLE_SPAN
end

local lostSince = nil

function fuel.update(now)
    -- 1. A real fuel sensor wins.
    local real = telemetry.get("fuel")
    if real then
        if real < 0 then real = 0 elseif real > 100 then real = 100 end
        fuel.pct, fuel.mode = real, "sensor"
        publish:set(nil)
        return
    end

    local v, cells = battery.pack, battery.cells
    if not v or not cells then
        lostSince = lostSince or now
        if now - lostSince > UNLOCK_AFTER then resetPack() end
        publish:set(nil)
        return
    end
    lostSince = nil

    -- Wait for the voltage to settle on a new pack.
    if not st.seenAt then
        st.seenAt, st.settleUntil = now, now + SETTLE
    end
    if now < st.settleUntil then return end
    addSample(v)
    if not st.stable then
        if not samplesStable() then return end
        st.stable = true
    end

    local thr = trackside.core.input.thr
    if thr < 0 then thr = -thr end
    if thr >= DRIVEN_AT then
        st.driven = true
        st.offSince = nil
    else
        st.offSince = st.offSince or now
    end
    local resting = st.offSince and now - st.offSince >= REST_DELAY

    -- Voltage rising before the first drive = a fresh pack: start again.
    if not st.driven and st.lastV and v > st.lastV + STABLE_SPAN then
        resetPack()
        return
    end
    st.lastV = v

    -- Take sag spikes out: drops faster than FALL_PER_CELL are followed slowly.
    local dt = st.lastAt and (now - st.lastAt) or 0
    st.lastAt = now
    local fv = st.filtV
    if not fv or v >= fv then
        fv = v
    else
        local maxFall = dt * FALL_PER_CELL * cells
        if fv - v > maxFall then fv = fv - maxFall else fv = v end
    end
    st.filtV = fv

    local vPct = restPct(fv / cells)

    -- 2. mAh counting when the pack size is known.
    local capacity = settings.get("packCapacity")
    local used = telemetry.get("used")
    local pct
    if capacity and capacity ~= settings.OFF and capacity > 0 and used then
        if not st.startPct then
            st.startPct, st.startUsed = restPct(v / cells), used
        end
        pct = st.startPct - (used - st.startUsed) / capacity * 100
        fuel.mode = "mAh"
    else
        -- 3. Voltage only: read at rest, never back up once driven, and fall
        -- no faster than MAX_DROP. On throttle the last value holds.
        local last = fuel.pct
        if fuel.mode == "voltage" and last and not resting then
            publish:set(math.floor(last + 0.5))
            return
        end
        pct = vPct
        dt = st.pctAt and (now - st.pctAt) or 0
        st.pctAt = now
        if st.driven and last and fuel.mode == "voltage" then
            if pct > last then
                pct = last
            elseif pct < last - MAX_DROP * dt then
                pct = last - MAX_DROP * dt
            end
        end
        fuel.mode = "voltage"
    end
    if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
    fuel.pct = pct
    publish:set(math.floor(pct + 0.5))
end

return fuel
