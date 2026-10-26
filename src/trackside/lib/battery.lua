--[[
  Pack battery: cell count, per-cell voltage, percent and session minimum.
  The low-voltage alarm (LOW / ALARM states, haptics) is still to do; see docs/FEATURES.md.

  Cells = Auto: guessed from the first valid pack voltage and locked, unlocked
  again after ~5 s without telemetry (new pack).
]]

local settings = trackside.settings
local telemetry = trackside.telemetry

local battery = {
    pack = nil,      -- volts
    cells = nil,     -- count in use
    cell = nil,      -- volts per cell
    pct = nil,       -- 0..100
    min = nil,       -- lowest pack voltage this session
}

local EMPTY = 3.50
local FULL = { 4.20, 4.35 }      -- by Battery Type: LiPo, LiHV
local UNLOCK_AFTER = 5.0         -- seconds without a pack reading

local autoCells, lostSince = nil, nil

local function guessCells(v, full)
    -- Fewest cells that keep each cell at or under full charge (with a little headroom).
    for n = 1, 6 do
        if v / n <= full + 0.05 then return n end
    end
    return 6
end

function battery.update()
    local now = os.clock()
    local v = telemetry.get("pack")
    local full = FULL[settings.get("battType")] or FULL[1]

    if not v or v < 0.5 then
        lostSince = lostSince or now
        if now - lostSince > UNLOCK_AFTER then autoCells = nil end
        battery.pack, battery.cell, battery.pct = nil, nil, nil
        battery.cells = nil
        return
    end
    lostSince = nil

    local cellSetting = settings.get("cells") or 1     -- 1 = Auto, 2..7 = 1S..6S
    local cells
    if cellSetting == 1 then
        autoCells = autoCells or guessCells(v, full)
        cells = autoCells
    else
        cells = cellSetting - 1
    end

    local cell = v / cells
    local pct = (cell - EMPTY) / (full - EMPTY) * 100
    if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end

    battery.pack, battery.cells, battery.cell, battery.pct = v, cells, cell, pct
    if not battery.min or v < battery.min then battery.min = v end
end

function battery.resetSession()
    battery.min = nil
end

return battery
