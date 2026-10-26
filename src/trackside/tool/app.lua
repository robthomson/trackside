--[[
  Trackside system tool (System menu -> Trackside).

  Menu of icon tiles -> one page each:
    Check setup   live status + Aid Test (proves the Multiply lines work)
    Brake / ABS, Drive aids, Inputs, Timer & laps, Battery alarm   settings

  Loaded on first open (main.lua registers a small stub). Settings save per
  model when a page is left and when the tool closes.
]]

local settings = trackside.settings
local core = trackside.core
local fields = trackside.getForm()

local GFX = trackside.BASE .. "tool/gfx/"
local function mask(name) return lcd.loadMask(GFX .. name .. ".png") end

local ICONS = {
    CHECK = mask("check"), BRK = mask("brake"), DRV = mask("drive"),
    IN = mask("inputs"), LAP = mask("laps"), VOLT = mask("battery"),
}
local BACK_ICON = mask("back")

local TITLES = {}
for _, p in ipairs(settings.PAGES) do TITLES[p.id] = p.title end

-- Menu groups (each starts a new row under its heading).
local GROUPS = {
    { title = "Settings", pages = { "BRK", "DRV", "IN", "LAP", "VOLT" } },
    { title = "Diagnostics", pages = { "CHECK" } },
}

local TILE_COLS, TILE_H, TILE_PAD, TILE_LEFT = 5, 124, 8, 4

local app = {}
local page = nil          -- nil = menu, else a page id
local lastTile = nil      -- page id of the tile pressed last (focus on return)
local check = nil         -- Check setup page state while it is open

-- Header row: title on the left, back button on the right.
local function header(title, onBack)
    local line = form.addLine("")
    local slots = form.getFieldSlots(line, { 0, 60 })
    form.addStaticText(line, { x = 0, y = slots[1].y, w = slots[2].x - 8, h = slots[1].h }, title)
    if onBack then
        return form.addButton(line, slots[2], { icon = BACK_ICON, press = onBack })
    end
end

local showMenu

local function leavePage()
    if page == "CHECK" and core.testUntil then
        core.setTest(false)
        trackside.audio.say("aidtest_off")
    end
    check = nil
    fields.save()
end

---------------------------------------------------------------- Check setup

local MOVE_MIN = 0.2      -- input must be past 20% to judge a channel
local SEEN_TIMEOUT = 2.5  -- s without a wakeup = source/sensor not running

local function pct(v) return string.format("%d%%", math.floor(v * 100 + (v >= 0 and 0.5 or -0.5))) end

local function newAxis(inKey, chKey, inName)
    return { inKey = inKey, chKey = chKey, inName = inName, base = nil, verdict = nil }
end

-- Ratio of channel output to input. With the aids at x1.0 this is the
-- baseline (rates, end points). During the Aid Test it should halve.
local function judge(a, inp, out, testing)
    if inp > -MOVE_MIN and inp < MOVE_MIN then return end
    local r = out / inp
    if not testing then
        a.base = r
        return
    end
    local rel = r / ((a.base and a.base > 0.05) and a.base or 1)
    if rel > 0.35 and rel < 0.65 then
        a.verdict = "OK: moves half as far"
    elseif rel >= 0.8 then
        a.verdict = "Not working: aid line missing or off"
    else
        a.verdict = "Wrong: set Operation Multiply"
    end
end

local function setText(f, slot, text)
    if check.last[slot] ~= text then
        check.last[slot] = text
        f:value(text)
    end
end

local function buildCheck()
    check = {
        last = {},
        thr = newAxis("throttleSrc", "throttleCh", "Throttle"),
        str = newAxis("steerSrc", "steerCh", "Steering"),
        at = 0,
    }
    local function staticLine(label)
        return form.addStaticText(form.addLine(label), nil, "")
    end
    check.sensor = staticLine("Trackside sensor")
    check.fuel = staticLine("Fuel")
    local testLine = form.addLine("Aid Test (both aids x0.5)")
    form.addBooleanField(testLine, nil,
        function() return core.testUntil ~= nil end,
        function(on)
            core.setTest(on)
            trackside.audio.say(on and "aidtest_on" or "aidtest_off")
            check.thr.verdict, check.str.verdict = nil, nil
        end)
    check.drive = staticLine("Throttle Aid")
    check.strmul = staticLine("Steer Aid")
    check.thrLive = staticLine("Throttle")
    check.strLive = staticLine("Steering")
    check.thrRes = staticLine("Throttle result")
    check.strRes = staticLine("Steering result")
end

local function aidText(field)
    local seen = trackside.seen[field]
    if not seen or os.clock() - seen > SEEN_TIMEOUT then
        return "Not running: turn on in Model > Lua"
    end
    return string.format("x%.2f", core.out[field])
end

local FUEL_FROM = { sensor = "fuel sensor", mAh = "mAh used", voltage = "voltage" }

local function fuelText()
    local f = trackside.fuel
    if not f.pct then return "Waiting for pack voltage" end
    return string.format("%d%% from %s", math.floor(f.pct + 0.5), FUEL_FROM[f.mode] or "?")
end

local function liveAxis(a, liveField, resField, inp, testing)
    local ch = settings.source(a.chKey)
    local chName = ch and ch:name() or "---"
    local out = ch and (ch:value() or 0) / 1024 or 0
    judge(a, inp, out, testing)
    setText(liveField, liveField, string.format("In %s   %s %s", pct(inp), chName, pct(out)))
    local res
    if not testing then
        res = "Turn on Aid Test"
    elseif a.verdict then
        res = a.verdict
    else
        res = (a == check.thr) and "Pull the trigger" or "Turn the wheel"
    end
    setText(resField, resField, res)
end

local function wakeupCheck()
    local now = os.clock()
    if now - check.at < 0.2 then return end
    check.at = now
    local alive = trackside.aliveAt
    setText(check.sensor, check.sensor,
        (alive and now - alive < SEEN_TIMEOUT) and "Sending (LS1 can use it)" or "Not sending")
    setText(check.fuel, check.fuel, fuelText())
    setText(check.drive, check.drive, aidText("drive"))
    setText(check.strmul, check.strmul, aidText("strmul"))
    local testing = core.testUntil ~= nil
    liveAxis(check.thr, check.thrLive, check.thrRes, core.input.thr, testing)
    liveAxis(check.str, check.strLive, check.strRes, core.input.steer, testing)
end

---------------------------------------------------------------- pages

local function openPage(id)
    page = id
    lastTile = id
    form.clear()
    header(TITLES[id], showMenu)
    if id == "CHECK" then
        buildCheck()
    else
        fields.addFields(id)
    end
end

function showMenu()
    if page then leavePage() end
    page = nil
    form.clear()
    -- Tiles stretched to the window so the full names fit.
    local winW = lcd.getWindowSize()
    local tileW = math.floor((winW - 2 * TILE_LEFT - (TILE_COLS - 1) * TILE_PAD) / TILE_COLS)
    local focusBtn, firstBtn
    for gi, g in ipairs(GROUPS) do
        local line = form.addLine(g.title)
        if gi == 1 then
            -- Settings are per model: say which one.
            local name = model.name and model.name() or ""
            if name ~= "" then form.addStaticText(line, nil, name) end
        end
        local y = form.height() + TILE_PAD
        local col = 0
        for _, id in ipairs(g.pages) do
            local x = TILE_LEFT + col * (tileW + TILE_PAD)
            local btn = form.addButton(nil, { x = x, y = y, w = tileW, h = TILE_H }, {
                text = TITLES[id],
                icon = ICONS[id],
                options = FONT_S,
                press = function() openPage(id) end,
            })
            firstBtn = firstBtn or btn
            if id == lastTile then focusBtn = btn end
            col = col + 1
            if col >= TILE_COLS then
                col = 0
                y = y + TILE_H + TILE_PAD
            end
        end
    end
    local b = focusBtn or firstBtn
    if b then b:focus() end
end

---------------------------------------------------------------- tool callbacks

local function isClose(category, value)
    if value == KEY_ENTER_LONG then return false end
    if category == EVT_CLOSE then return value == 0 or value == KEY_DOWN_BREAK end
    if category == EVT_KEY then
        return value == KEY_EXIT_BREAK or value == KEY_RTN_BREAK or value == KEY_DOWN_BREAK
    end
    return false
end

function app.create()
    settings.ensureModel(true)
    page, check = nil, nil
    showMenu()
    return {}
end

function app.wakeup()
    if check then wakeupCheck() end
end

function app.event(state, category, value)
    if page and isClose(category, value) then
        showMenu()
        return true
    end
    return false
end

function app.close()
    if core.testUntil then trackside.audio.say("aidtest_off") end
    core.setTest(false)
    check, page = nil, nil
    fields.save()
end

return app
