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
    CHECK = mask("check"), BRK = mask("brake"), DRV = mask("drive"), ROCK = mask("rock"),
    IN = mask("inputs"), LAP = mask("laps"), VOLT = mask("battery"),
}
local BACK_ICON = mask("back")

local TITLES = {}
for _, p in ipairs(settings.PAGES) do TITLES[p.id] = p.title end

-- Menu groups (each starts a new row under its heading).
local GROUPS = {
    { title = "Settings", pages = { "BRK", "DRV", "ROCK", "IN", "LAP", "VOLT" } },
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

local MOVE_MIN = 0.3      -- input must be past 30% to compare the two pulse halves
local CENTRE = 0.05       -- input under 5%: centre-stick check
local STEADY = 0.03       -- input may move this much between the two halves
local SETTLE = 0.4        -- s into a pulse half before sampling (source + mixer delay)
local SEEN_TIMEOUT = 2.5  -- s without a wakeup = source/sensor not running

local function pct(v) return string.format("%d%%", math.floor(v * 100 + (v >= 0 and 0.5 or -0.5))) end

-- Per channel: the last sample taken in each half of the Aid Test pulse.
local function newAxis(inKey, chKey)
    return { inKey = inKey, chKey = chKey, verdict = nil, at = nil,
             hIn = nil, hOut = nil, hAt = nil,      -- half (x0.5)
             fIn = nil, fOut = nil, fAt = nil }     -- full (x1.0)
end

local function resetAxis(a)
    a.verdict, a.at, a.hIn, a.hOut, a.hAt, a.fIn, a.fOut, a.fAt = nil, nil, nil, nil, nil, nil, nil, nil
end

-- Compare the two halves taken back to back at the same stick position: with
-- Multiply the x0.5 half is exactly half the x1.0 half, whatever the curves.
local function judge(a)
    if not (a.hAt and a.fAt) or math.abs(a.hAt - a.fAt) > 1.0 then return end
    if math.abs(a.hIn - a.fIn) > STEADY then return end           -- stick moved
    local inp = (a.hIn + a.fIn) / 2
    if inp > -CENTRE and inp < CENTRE then
        -- Multiply keeps a centred stick at ~0; Add pushes the channel off centre.
        if math.abs(a.fOut) > 0.25 then a.verdict = "Wrong: set Operation Multiply" end
        return
    end
    if inp > -MOVE_MIN and inp < MOVE_MIN then return end
    if math.abs(a.fOut) < 0.1 then
        -- Both halves near 0: the channel isn't driven. Only one: an Add line.
        a.verdict = (math.abs(a.hOut) < 0.1) and "No output: check the channel" or "Wrong: set Operation Multiply"
        return
    end
    local rel = a.hOut / a.fOut
    if rel > 0.4 and rel < 0.6 then
        a.verdict = "OK: moves half as far"
    elseif rel >= 0.85 then
        a.verdict = "Not working: aid line missing or off"
    else
        a.verdict = "Wrong: set Operation Multiply"
    end
end

-- Rock (the Add line): while the Rock Switch is held, remember the largest
-- Rock value sent and the largest throttle channel value seen; judge when it
-- stops. With the line right the channel reaches what Rock sent (the Throttle
-- Aid Multiply line is at 0, so the trigger adds nothing).
local function watchRock(now)
    local rk = check.rock
    local rock = trackside.rock
    if rock.active then
        rk.was = true
        local lvl = core.out.rock
        if lvl < 0 then lvl = -lvl end
        if lvl > rk.maxLevel then rk.maxLevel = lvl end
        local ch = settings.source("throttleCh")
        local out = ch and (ch:value() or 0) / 1024 or 0
        if out < 0 then out = -out end
        if out > rk.maxOut then rk.maxOut = out end
    elseif rk.was then
        rk.was = false
        if rk.maxLevel >= 0.05 then
            if rk.maxOut < 0.1 then
                rk.verdict = "No output: Rock line missing, off or not Add"
            elseif rk.maxOut > rk.maxLevel * 0.8 and rk.maxOut < rk.maxLevel * 1.2 then
                rk.verdict = "OK: channel follows Rock"
            else
                rk.verdict = string.format("Check weight: channel %s for Rock %s", pct(rk.maxOut), pct(rk.maxLevel))
            end
        end
        rk.maxLevel, rk.maxOut = 0, 0
    end
end

local function rockText()
    local rock = trackside.rock
    if not settings.get("rockSrc") then return "Off: set a Rock Switch" end
    local seen = trackside.seen.rock
    if not seen or os.clock() - seen > SEEN_TIMEOUT then
        return "Not running: turn on in Model > Lua"
    end
    if rock.active then
        return string.format("Cycle %d, %s %s", rock.cycle, rock.step or "-", pct(core.out.rock))
    end
    return "Ready: hold the Rock Switch"
end

local function sample(a, inp, now)
    if trackside.rock.active then return end        -- Throttle Aid is at 0 while rocking
    if now - core.testPhaseAt < SETTLE or a.at == core.testPhaseAt then return end
    a.at = core.testPhaseAt
    local ch = settings.source(a.chKey)
    local out = ch and (ch:value() or 0) / 1024 or 0
    if core.testMul < 1 then
        a.hIn, a.hOut, a.hAt = inp, out, now
    else
        a.fIn, a.fOut, a.fAt = inp, out, now
    end
    judge(a)
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
        thr = newAxis("throttleSrc", "throttleCh"),
        str = newAxis("steerSrc", "steerCh"),
        rock = { was = false, maxLevel = 0, maxOut = 0, verdict = nil },
        at = 0,
    }
    local function staticLine(label)
        return form.addStaticText(form.addLine(label), nil, "")
    end
    local version = trackside.VERSION
    if trackside.BUILD ~= version then version = version .. " (" .. trackside.BUILD .. ")" end
    form.addStaticText(form.addLine("Version"), nil, version)
    check.sensor = staticLine("Trackside sensor")
    check.fuel = staticLine("Fuel")
    local testLine = form.addLine("Aid Test (aids pulse x0.5)")
    form.addBooleanField(testLine, nil,
        function() return core.testUntil ~= nil end,
        function(on)
            core.setTest(on)
            trackside.audio.say(on and "aidtest_on" or "aidtest_off")
            resetAxis(check.thr)
            resetAxis(check.str)
        end)
    check.drive = staticLine("Throttle Aid")
    check.strmul = staticLine("Steer Aid")
    check.thrLive = staticLine("Throttle")
    check.strLive = staticLine("Steering")
    check.thrRes = staticLine("Throttle result")
    check.strRes = staticLine("Steering result")
    check.rockLive = staticLine("Rock")
    check.rockRes = staticLine("Rock result")
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
    setText(liveField, liveField, string.format("In %s   %s %s", pct(inp), chName, pct(out)))
    local res
    if not testing then
        res = "Turn on Aid Test"
    elseif a.verdict then
        res = a.verdict
    else
        res = (a == check.thr) and "Hold the trigger steady past 30%" or "Hold the wheel steady past 30%"
    end
    setText(resField, resField, res)
end

local function wakeupCheck()
    local now = os.clock()
    local testing = core.testUntil ~= nil
    if testing then
        sample(check.thr, core.input.thr, now)
        sample(check.str, core.input.steer, now)
    end
    watchRock(now)
    if now - check.at < 0.2 then return end
    check.at = now
    local alive = trackside.aliveAt
    setText(check.sensor, check.sensor,
        (alive and now - alive < SEEN_TIMEOUT) and "Sending (LS1 can use it)" or "Not sending")
    setText(check.fuel, check.fuel, fuelText())
    setText(check.drive, check.drive, aidText("drive"))
    setText(check.strmul, check.strmul, aidText("strmul"))
    liveAxis(check.thr, check.thrLive, check.thrRes, core.input.thr, testing)
    liveAxis(check.str, check.strLive, check.strRes, core.input.steer, testing)
    setText(check.rockLive, check.rockLive, rockText())
    setText(check.rockRes, check.rockRes, check.rock.verdict or "Hold the Rock Switch, then release")
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
