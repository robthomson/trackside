--[[
  Settings form for the Trackside widget's Configure page.
  One expansion panel per tab: BRK, DRV, SET, VOLT.
  Values are per model (SCRIPTS:/trackside.user/models/), not per widget, because
  the Throttle Aid / Steer Aid sources need them even when no widget is on screen.
]]

local settings = trackside.settings
local OFF = settings.OFF

local PANEL_TITLES = {
    BRK = "BRK - Brake / ABS",
    DRV = "DRV - Drive / stability",
    SET = "SET - Setup",
    VOLT = "VOLT - Battery alarm",
}
local PANEL_ORDER = { "BRK", "DRV", "SET", "VOLT" }

local function addNumber(line, s)
    -- OFF-capable settings use one step below min as the OFF position.
    local lo = s.off and (s.min - s.step) or s.min
    local field = form.addNumberField(line, nil, lo, s.max,
        function()
            local v = settings.get(s.key)
            if v == OFF then return lo end
            return v
        end,
        function(v)
            if s.off and v < s.min then v = OFF end
            settings.set(s.key, v)
        end)
    field:step(s.step)
    if s.decimals then field:decimals(s.decimals) end
    if s.unit then field:suffix(s.unit) end
    if s.off and field.text then
        field:text(function(v)
            if v < s.min then return "OFF" end
            if s.decimals then
                return string.format("%." .. s.decimals .. "f%s", v / 10 ^ s.decimals, s.unit or "")
            end
            return tostring(v) .. (s.unit or "")
        end)
    end
end

local function addChoice(line, s)
    local values = {}
    for i, label in ipairs(s.choices) do values[i] = { label, i } end
    form.addChoiceField(line, nil, values,
        function() return settings.get(s.key) end,
        function(v) settings.set(s.key, v) end)
end

local function addSource(line, s)
    form.addSourceField(line, nil,
        function()
            local v = settings.get(s.key)
            if not v then return nil end
            return system.getSource({ category = v[1], member = v[2] })
        end,
        function(src)
            if src then
                settings.set(s.key, { src:category(), src:member() })
            else
                settings.set(s.key, nil)
            end
        end)
end

local M = {}

function M.build()
    for _, tab in ipairs(PANEL_ORDER) do
        local panel = form.addExpansionPanel(PANEL_TITLES[tab])
        panel:open(tab == "BRK")
        for _, s in ipairs(settings.schema) do
            if s.tab == tab then
                local line = panel:addLine(s.label)
                if s.kind == "num" then
                    addNumber(line, s)
                elseif s.kind == "choice" then
                    addChoice(line, s)
                elseif s.kind == "source" then
                    addSource(line, s)
                end
            end
        end
    end
    local line = form.addLine("Version")
    form.addStaticText(line, nil, trackside.VERSION)
end

function M.save()
    if settings.dirty then settings.save() end
end

return M
