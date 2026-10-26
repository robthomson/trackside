--[[
  Trackside dashboard widget.

  Layout is a grid of boxes, in the style of the rfsuite dashboard. Phase 2
  swaps this for a themeable engine (pre-race / racing / post-race layouts).

  Hot-path rules (see CLAUDE.md, same as rfsuite/wfsuite):
    - wakeup reads numbers, quantises them, and only formats a string when the
      shown value changes; paint only draws cached strings.
    - lcd.invalidate() only when something visible changed.
    - box rectangles are computed once per window size.
]]

local core = trackside.core
local settings = trackside.settings
local telemetry = trackside.telemetry
local battery = trackside.battery
local laps = trackside.laps

local floor, abs = math.floor, math.abs
local format = string.format

local COLS, ROWS, PAD = 12, 8, 4
local TEXT_EVERY = 0.2      -- s, numbers and labels
local SCOPE_EVERY = 0.05    -- s, live throttle/steer bar
local THEME_EVERY = 1.0     -- s, re-read Ethos theme colours

-- Screen size never changes at runtime: read it once.
local LCD_W, LCD_H
do
    local v = system.getVersion()
    LCD_W, LCD_H = v.lcdWidth or 800, v.lcdHeight or 480
end

-- Like the rfsuite dashboard: the header row only shows when the widget fills
-- the whole screen. Otherwise Ethos already shows the model name and status.
local function isFullScreen(W, H)
    return W >= LCD_W - 4 and H >= LCD_H - 4
end

-- --- colours ---------------------------------------------------------------
local C = { letter = {} }

local function themed(key, fallback)
    if lcd.themeColor and key then
        local ok, c = pcall(lcd.themeColor, key)
        if ok and c then return c end
    end
    return fallback
end

-- Returns true if any surface colour changed (theme switched).
local function colors()
    local bg = themed(THEME_PAGE_BGCOLOR, lcd.RGB(16, 18, 22))
    local changed = bg ~= C.bg
    C.bg = bg
    C.box = themed(THEME_DEFAULT_BGCOLOR, lcd.RGB(32, 36, 44))
    C.title = themed(THEME_SECONDARY_COLOR, lcd.RGB(150, 156, 168))
    C.text = themed(THEME_DEFAULT_COLOR, lcd.RGB(240, 240, 240))
    C.off = themed(THEME_DISABLE_COLOR, lcd.RGB(70, 74, 84))
    -- Status colours are ours: they mean the same thing on every theme.
    C.throttle = lcd.RGB(64, 210, 110)
    C.brake = lcd.RGB(235, 70, 60)
    C.warn = lcd.RGB(255, 176, 32)
    C.letter.A = C.brake                      -- ABS
    C.letter.T = C.throttle                   -- traction
    C.letter.S = C.warn                       -- steer cut
    C.letter.C = lcd.RGB(200, 110, 255)       -- corner brake
    C.letter.D = lcd.RGB(60, 170, 255)        -- steer limit
    return changed
end

-- PACK box: amber value on LOW, background flashing red on ALARM (lib/alerts.lua).
local function packColor()
    local st = trackside.alerts.state
    if st == "LOW" then return C.warn end
    if st == "ALARM" then return C.text end
    local p = trackside.fuel.pct
    if not p then return nil end
    if p < 20 then return C.brake elseif p < 50 then return C.warn end
    return C.throttle
end
local function packBg()
    if trackside.alerts.state == "ALARM" and floor(os.clock() * 2) % 2 == 0 then return C.brake end
    return nil
end

-- Battery % colour: green, amber under 50%, red under 20%.
local function battColor()
    local p = trackside.fuel.pct
    if not p then return nil end
    if p < 20 then return C.brake elseif p < 50 then return C.warn end
    return C.throttle
end

-- Lap times: "12.34" under a minute, "1:02.3" over. Long form for the big box.
local function lapShort(t)
    if t < 60 then return format("%.2f", t) end
    return format("%d:%04.1f", floor(t / 60), t % 60)
end
local function lapLong(t)
    return format("%d:%04.1f", floor(t / 60), t % 60)
end

local BEST_FLASH = 3.0      -- s the BEST box shows green after a new best
local function bestColor()
    local at = laps.bestAt
    if at and os.clock() - at < BEST_FLASH then return C.throttle end
    return nil
end

-- --- boxes -------------------------------------------------------------------
-- src returns a number (or string) or nil; q = display step used for change
-- detection; pattern formats the number. Text is rebuilt only on change.
local function modelName() return (model.name and model.name()) or "VX10" end
local function cellsLabel() return battery.cells end

local boxes = {
    -- header (full screen only)
    { c = 0, r = 0, w = 6, h = 1, header = true, font = FONT_L, left = true, src = modelName },
    { c = 6, r = 0, w = 2, h = 1, header = true, font = FONT_STD, title = "LQ", src = function() return telemetry.get("lq") end, q = 1, pattern = "%d%%" },
    { c = 8, r = 0, w = 2, h = 1, header = true, font = FONT_STD, title = "TX", src = function() return telemetry.get("txbatt") end, q = 0.1, pattern = "%.1fV" },
    { c = 10, r = 0, w = 2, h = 1, header = true, font = FONT_STD, title = "PWR", src = function() return telemetry.get("txpower") end, q = 1, pattern = "%dmW" },

    -- left: battery
    { c = 0, r = 1, w = 6, h = 3, title = "PACK", font = FONT_XXL, color = packColor, bg = packBg,
      src = function() return battery.pack end, q = 0.01, pattern = "%.2fV",
      sub = cellsLabel, subPattern = "%dS" },
    { c = 0, r = 4, w = 2, h = 2, title = "CELL", src = function() return battery.cell end, q = 0.01, pattern = "%.2f" },
    { c = 2, r = 4, w = 2, h = 2, title = "BATT", color = battColor, src = function() return trackside.fuel.pct end, q = 1, pattern = "%d%%" },
    { c = 4, r = 4, w = 2, h = 2, title = "MIN", src = function() return battery.min end, q = 0.01, pattern = "%.2f" },

    -- right: laps. CUR shows a bar while the lap switch is held towards a reset.
    { c = 6, r = 1, w = 6, h = 3, title = "CUR", font = FONT_XXL, src = function() return laps.current() end,
      q = 0.1, fmt = lapLong, progress = function() return laps.holdFrac end },
    { c = 6, r = 4, w = 2, h = 2, title = "L1", src = function() return laps.last end, q = 0.01, fmt = lapShort },
    { c = 8, r = 4, w = 2, h = 2, title = "BEST", color = bestColor, src = function() return laps.best end, q = 0.01, fmt = lapShort },
    { c = 10, r = 4, w = 2, h = 2, title = "LAP", src = function() return laps.count end, q = 1, pattern = "%d" },

    -- footer: aid letters (or timer) + live scope
    { c = 0, r = 6, w = 6, h = 2, kind = "letters" },
    { c = 6, r = 6, w = 6, h = 2, kind = "scope" },
}

for _, b in ipairs(boxes) do
    b.text = "--"
    b.key = false        -- last quantised value shown
    b.subText = nil
    b.subKey = false
end

-- Quantise a value so tiny changes (sensor noise) don't cause a redraw.
local function quantise(v, q)
    if type(v) ~= "number" or not q then return v end
    return floor(v / q + 0.5)
end

-- Update one box's cached text. Returns true if it changed.
local function refreshBox(b)
    local changed = false
    if b.src then
        local v = b.src()
        local k = quantise(v, b.q)
        if k ~= b.key then
            b.key = k
            if v == nil then
                b.text = "--"
            elseif type(v) == "number" then
                -- k * q keeps integers integral, so "%d" patterns are safe
                local n = b.q and k * b.q or v
                b.text = b.fmt and b.fmt(n) or format(b.pattern or "%s", n)
            else
                b.text = v
            end
            changed = true
        end
    end
    if b.sub then
        local v = b.sub()
        if v ~= b.subKey then
            b.subKey = v
            b.subText = v and format(b.subPattern or "%s", v) or nil
            changed = true
        end
    end
    if b.progress then
        local p = b.progress()
        local k = p and floor(p * 20) or false
        if k ~= b.progKey then
            b.progKey = k
            changed = true
        end
    end
    if b.bg then
        local c = b.bg()
        if c ~= b.bgKey then
            b.bgKey = c
            changed = true
        end
    end
    if b.color then
        local c = b.color()
        if c ~= b.colorKey then
            b.colorKey = c
            changed = true
        end
    end
    return changed
end

-- --- layout (once per window size) ------------------------------------------
local layoutW, layoutH, layoutFull = nil, nil, nil

local function layout(W, H)
    if W == layoutW and H == layoutH then return end
    layoutW, layoutH = W, H
    layoutFull = isFullScreen(W, H)
    local rowShift = layoutFull and 0 or 1
    local rows = ROWS - rowShift
    local cw, rh = W / COLS, H / rows
    for _, b in ipairs(boxes) do
        local r = b.r - rowShift
        b.x = floor(b.c * cw) + PAD
        b.y = floor(r * rh) + PAD
        b.w = floor(b.w0 * cw) - 2 * PAD
        b.h = floor(b.h0 * rh) - 2 * PAD
    end
end

for _, b in ipairs(boxes) do b.w0, b.h0 = b.w, b.h end

-- --- drawing -----------------------------------------------------------------
local function drawValueBox(b)
    local x, y, w, h = b.x, b.y, b.w, b.h
    lcd.color(b.bgKey or C.box)
    lcd.drawFilledRectangle(x, y, w, h)
    local ty = y
    lcd.font(FONT_S)
    if b.title then
        lcd.color(C.title)
        lcd.drawText(x + 6, y + 2, b.title)
        local _, th = lcd.getTextSize(b.title)
        ty = y + th
    end
    if b.subText then
        lcd.color(C.title)
        local sw = lcd.getTextSize(b.subText)
        lcd.drawText(x + w - sw - 6, y + 2, b.subText)
    end
    lcd.font(b.font or FONT_XL)
    lcd.color(b.colorKey or C.text)
    local tw, th = lcd.getTextSize(b.text)
    local cy = ty + floor((y + h - ty - th) / 2)
    if b.left then
        lcd.drawText(x + 8, cy, b.text)
    else
        lcd.drawText(x + floor((w - tw) / 2), cy, b.text)
    end
    if b.progKey then
        -- hold-to-reset bar along the bottom
        lcd.color(C.warn)
        lcd.drawFilledRectangle(x + 4, y + h - 10, floor((w - 8) * math.min(1, b.progKey / 20)), 6)
    end
end

-- Footer countdown (Show Timer = ON). Blinks once it has run out.
local function timerText()
    local left = laps.timerLeft or 0
    local s = math.ceil(left)
    return format("%d:%02d", floor(s / 60), s % 60)
end

local function drawTimer(b)
    local x, y, w, h = b.x, b.y, b.w, b.h
    lcd.color(C.box)
    lcd.drawFilledRectangle(x, y, w, h)
    if laps.timerExpired and floor(os.clock() * 2) % 2 == 1 then return end
    lcd.font(FONT_XXL)
    local c = C.text
    if laps.timerExpired then c = C.brake elseif not laps.timerRunning then c = C.title end
    lcd.color(c)
    local t = timerText()
    local tw, th = lcd.getTextSize(t)
    lcd.drawText(x + floor((w - tw) / 2), y + floor((h - th) / 2), t)
end

local LETTERS = { "A", "T", "S", "C", "D" }

-- An aid is armed when its setting isn't OFF.
local function armed(l)
    if l == "A" then return settings.get("absMode") ~= 1 end
    if l == "T" then return not settings.isOff("traction") end
    if l == "S" then return not settings.isOff("steerCut") end
    if l == "C" then return not (settings.isOff("cornerBrake") and settings.isOff("cornerAbsHz")) end
    return not settings.isOff("steerLimit")
end

-- Letter colours: its own colour while working, white when armed,
-- dark grey when OFF. Aids Switch off: all dark grey, struck through.
local function drawLetters(b)
    local x, y, w, h = b.x, b.y, b.w, b.h
    lcd.color(C.box)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.font(FONT_XL)
    local on = core.aidsOn
    local cell = w / #LETTERS
    for i = 1, #LETTERS do
        local l = LETTERS[i]
        local c = C.off
        if on then
            if core.flags[l] then c = C.letter[l] elseif armed(l) then c = C.text end
        end
        lcd.color(c)
        local tw, th = lcd.getTextSize(l)
        lcd.drawText(x + floor((i - 0.5) * cell - tw / 2), y + floor((h - th) / 2), l)
    end
    if not on then
        lcd.color(C.warn)
        lcd.drawFilledRectangle(x + 8, y + floor(h / 2) - 1, w - 16, 3)
    end
end

-- Processed throttle/brake fill from centre (green throttle, red brake),
-- steering tick underneath.
local function drawScope(b)
    local x, y, w, h = b.x, b.y, b.w, b.h
    lcd.color(C.box)
    lcd.drawFilledRectangle(x, y, w, h)
    local mid = x + floor(w / 2)
    local barY, barH = y + floor(h * 0.25), floor(h * 0.35)
    local half = floor(w / 2) - 8

    local thr = core.proc.thr
    -- Brake Direction: Negative (1) means negative stick is brake
    local braking = (settings.get("brakeDir") == 1) == (thr < 0)
    lcd.color(braking and C.brake or C.throttle)
    local len = floor(abs(thr) * half)
    if thr >= 0 then
        lcd.drawFilledRectangle(mid, barY, len, barH)
    else
        lcd.drawFilledRectangle(mid - len, barY, len, barH)
    end

    lcd.color(C.text)
    lcd.drawLine(mid, y + 4, mid, y + h - 4)

    local steer = core.input.steer
    if settings.get("graphDir") == 2 then steer = -steer end
    local sx = mid + floor(steer * half)
    lcd.drawFilledRectangle(sx - 3, barY + barH + 6, 6, 8)
end

-- --- lap view (tap the lap boxes; tap again to close) -------------------------
-- Summary row (LAPS / BEST / AVG / TOT) over a grid of every lap kept, oldest
-- first, best in green. Only painted when opened or when a lap is added.
local LV_COLS = 4

local function drawLapView(W, H)
    lcd.color(C.bg)
    lcd.drawFilledRectangle(0, 0, W, H)
    local n = laps.count
    local summary = {
        { "LAPS", tostring(n) },
        { "BEST", laps.best and lapShort(laps.best) or "--" },
        { "AVG", n > 0 and lapShort(laps.total / n) or "--" },
        { "TOT", n > 0 and lapLong(laps.total) or "--" },
    }
    local sw, sh = floor(W / 4), floor(H * 0.2)
    for i, s in ipairs(summary) do
        local x = (i - 1) * sw + PAD
        lcd.color(C.box)
        lcd.drawFilledRectangle(x, PAD, sw - 2 * PAD, sh - 2 * PAD)
        lcd.font(FONT_S)
        lcd.color(C.title)
        lcd.drawText(x + 6, PAD + 2, s[1])
        lcd.font(FONT_L)
        lcd.color(i == 2 and laps.best and C.throttle or C.text)
        local tw, th = lcd.getTextSize(s[2])
        lcd.drawText(x + floor((sw - 2 * PAD - tw) / 2), PAD + floor((sh - 2 * PAD - th) / 2) + 6, s[2])
    end

    local list = laps.list
    local top = sh + PAD
    lcd.font(FONT_STD)
    local _, rowH = lcd.getTextSize("0")
    rowH = rowH + 6
    local rows = math.max(1, floor((H - top - PAD) / rowH))
    local cap = rows * LV_COLS
    local first = math.max(1, #list - cap + 1)
    local base = laps.count - #list            -- lap number of list[1] minus 1
    local cw = floor(W / LV_COLS)
    if #list == 0 then
        lcd.color(C.title)
        lcd.drawText(PAD + 6, top + 6, "No laps yet. Tap to close.")
        return
    end
    for i = first, #list do
        local k = i - first
        local x = floor(k / rows) * cw + PAD + 6
        local y = top + (k % rows) * rowH
        local t = list[i]
        lcd.color(C.title)
        lcd.drawText(x, y, format("%d", base + i))
        lcd.color(t == laps.best and C.throttle or C.text)
        local s = lapShort(t)
        local tw = lcd.getTextSize(s)
        lcd.drawText(x + cw - 24 - tw, y, s)
    end
end

-- --- widget callbacks --------------------------------------------------------
local SLIDE_HOLD = 0.35     -- s after the last touch move before redraws resume

local scopeBox, lettersBox
for _, b in ipairs(boxes) do
    if b.kind == "scope" then scopeBox = b elseif b.kind == "letters" then lettersBox = b end
end

local function create()
    colors()
    return { textAt = -math.huge, scopeAt = -math.huge, themeAt = os.clock(),
             thrKey = false, steerKey = false, flagKey = false,
             visible = false, slidingUntil = 0, full = true, pending = {},
             lapView = false, lapViewKey = false, touchX = nil, touchY = nil, touchMoved = false,
             tb = false, tbAt = 0, tbSel = nil, tbKey = false, gConsume = false, gConsumeAt = 0 }
end

-- Everything the letters box shows, as one number (redraw only on change).
local function flagKey()
    local f = core.flags
    local k = (f.A and 1 or 0) + (f.T and 2 or 0) + (f.S and 4 or 0) + (f.C and 8 or 0) + (f.D and 16 or 0)
    for i = 1, #LETTERS do
        if armed(LETTERS[i]) then k = k + 32 * 2 ^ (i - 1) end
    end
    if not core.aidsOn then k = k + 1024 end
    if settings.get("showTimer") == 2 then
        -- footer shows the countdown: redraw on each second, run state and blink
        k = 4096 + math.ceil(laps.timerLeft or 0) * 8 + (laps.timerRunning and 1 or 0)
            + (laps.timerExpired and (2 + floor(os.clock() * 2) % 2 * 4) or 0)
    end
    return k
end

-- Queue one box for redraw. Boxes are only invalidated as rectangles, never the
-- whole window, so a moving steering tick doesn't repaint the full screen.
local function markBox(widget, b)
    if b.header and not layoutFull then return end
    widget.pending[b] = true
end

local function flush(widget)
    if widget.full then
        widget.full = false
        for b in pairs(widget.pending) do widget.pending[b] = nil end
        lcd.invalidate()
        return
    end
    if not layoutW then return end            -- not laid out yet: first paint is full anyway
    for b in pairs(widget.pending) do
        widget.pending[b] = nil
        lcd.invalidate(b.x, b.y, b.w, b.h)
    end
end

-- --- toolbar ------------------------------------------------------------------
-- Swipe up (or long PAGE) opens a toolbar along the bottom; swipe down, a tap
-- above it, RTN or TB_TIMEOUT seconds closes it, and so does choosing any
-- button. Laps opens the lap view,
-- Timer starts/pauses the countdown, Reset asks then clears laps and timer,
-- Settings opens the Trackside tool. Only vertical swipes are ours, so
-- swiping sideways between screens still works.
local GFX = trackside.BASE .. "widget/gfx/"
local TB_TIMEOUT = 10
local GESTURE_DY, GESTURE_DX = 20, 40      -- px: min vertical, max sideways
local TAP_SLOP = 15                        -- px a tap may move
local GESTURE_HOLD = 0.75                  -- s to keep swallowing a used gesture
local DIM = lcd.RGB(0, 0, 0, 0.6)
local ICON = 55

local TB_ITEMS = {
    { id = "laps", label = "Laps", icon = "tb_laps" },
    { id = "timer", label = "Timer", icon = "tb_timer" },
    { id = "reset", label = "Reset", icon = "tb_reset" },
    { id = "tool", label = "Settings", icon = "tb_settings" },
}
local tbMasks = nil                        -- loaded while the toolbar is open
local tbRects = {}

local function tbMask(it)
    tbMasks = tbMasks or {}
    local m = tbMasks[it.icon]
    if m == nil then
        m = lcd.loadMask(GFX .. it.icon .. ".png") or false
        tbMasks[it.icon] = m
    end
    return m
end

local function tbLabel(it)
    if it.id == "timer" then
        if laps.timerRunning then return "Pause timer" end
        return laps.timerExpired and "Restart timer" or "Start timer"
    end
    return it.label
end

local function tbBounds(W, H)
    local barH = floor(math.max(H * 0.24, math.min(H * 0.40, W * 0.16)))
    return 0, H - barH, W, barH
end

local function setToolbar(widget, on)
    if widget.tb == on then return end
    widget.tb, widget.tbAt, widget.full = on, os.clock(), true
    widget.tbSel = on and (widget.tbSel or 1) or nil
    if not on then tbMasks = nil end
end

local function drawToolbar(widget, W, H)
    lcd.color(DIM)
    lcd.drawFilledRectangle(0, 0, W, H)
    local x, y, bw, bh = tbBounds(W, H)
    lcd.color(C.bg)
    lcd.drawFilledRectangle(x, y, bw, bh)
    lcd.color(C.title)
    lcd.drawFilledRectangle(x, y, bw, 4)
    local n = #TB_ITEMS
    local iw = bw / n
    local pad = W <= 640 and 6 or 12
    lcd.font(FONT_S)
    for i, it in ipairs(TB_ITEMS) do
        local ix = floor(x + (i - 1) * iw)
        local r = tbRects[i] or {}
        tbRects[i] = r
        r.x, r.y, r.w, r.h, r.item = ix, y, floor(iw), bh, it
        local tx, ty, tw, th = ix + pad, y + pad + 4, floor(iw) - 2 * pad, bh - 2 * pad - 4
        local sel = widget.tbSel == i
        lcd.color(sel and C.warn or C.box)
        lcd.drawFilledRectangle(tx, ty, tw, th)
        lcd.color(sel and C.bg or C.text)
        local label = tbLabel(it)
        local lw = lcd.getTextSize(label)
        lcd.drawText(tx + floor((tw - lw) / 2), ty + 6, label)
        local m = tbMask(it)
        if m and lcd.drawMask then lcd.drawMask(tx + floor((tw - ICON) / 2), ty + th - ICON - 8, m) end
    end
end

local function openLapView(widget)
    widget.lapView, widget.lapViewKey, widget.full = true, laps.count, true
end

local function closeLapView(widget)
    widget.lapView, widget.full = false, true
    for _, b in ipairs(boxes) do b.key = false end   -- rebuild every box's text
end

local function tbActivate(widget, it)
    if it.id == "laps" then
        setToolbar(widget, false)
        openLapView(widget)
    elseif it.id == "timer" then
        setToolbar(widget, false)
        laps.toggleTimer()
    elseif it.id == "reset" then
        setToolbar(widget, false)
        if form and form.openDialog then
            form.openDialog({
                title = "Reset",
                message = "Reset the laps and the timer?",
                buttons = {
                    { label = "Reset", action = function() laps.resetAll() return true end },
                    { label = "Cancel", action = function() return true end },
                },
            })
        else
            laps.resetAll()
        end
    elseif it.id == "tool" then
        setToolbar(widget, false)
        if trackside.toolHandle and system.openPage then system.openPage({ system = trackside.toolHandle }) end
    end
end

local function consumeTouch()
    if not system.killEvents then return end
    if TOUCH_START then system.killEvents(TOUCH_START) end
    if TOUCH_MOVE then system.killEvents(TOUCH_MOVE) end
    if TOUCH_END then system.killEvents(TOUCH_END) end
end

local function isLeft(v) return v == ROTARY_LEFT or v == KEY_ROTARY_LEFT end
local function isRight(v) return v == ROTARY_RIGHT or v == KEY_ROTARY_RIGHT end
local function isBack(v) return v == KEY_RTN_BREAK or v == KEY_EXIT_BREAK or v == KEY_DOWN_BREAK end

local function keyEvent(widget, value)
    if value == KEY_PAGE_LONG and lcd.hasFocus() then
        setToolbar(widget, not widget.tb)
        system.killEvents(value)
        return true
    end
    if widget.lapView and (isBack(value) or value == KEY_ENTER_BREAK) then
        closeLapView(widget)
        system.killEvents(value)
        return true
    end
    if widget.tb and lcd.hasFocus() then
        local n, i = #TB_ITEMS, widget.tbSel or 1
        if isLeft(value) or isRight(value) then
            i = i + (isLeft(value) and -1 or 1)
            if i < 1 then i = n elseif i > n then i = 1 end
            widget.tbSel, widget.tbAt, widget.full = i, os.clock(), true
            return true
        elseif value == KEY_ENTER_BREAK then
            tbActivate(widget, TB_ITEMS[i])
            return true
        elseif isBack(value) then
            setToolbar(widget, false)
            return true
        end
    end
    return false
end

local function event(widget, category, value, x, y)
    -- Swallow the rest of a swipe we acted on, so Ethos doesn't act on it too.
    if widget.gConsume and category == EVT_TOUCH then
        if value == TOUCH_START or os.clock() - widget.gConsumeAt > GESTURE_HOLD then
            widget.gConsume = false
        else
            consumeTouch()
            if value == TOUCH_END then widget.gConsume = false end
            return true
        end
    end
    if category == EVT_KEY then return keyEvent(widget, value) end
    if category ~= EVT_TOUCH then return false end

    if value == TOUCH_START then
        widget.touchX, widget.touchY, widget.touchMoved = x, y, false
    elseif value == TOUCH_MOVE then
        widget.slidingUntil = os.clock() + SLIDE_HOLD
        if not widget.touchX then widget.touchX, widget.touchY, widget.touchMoved = x, y, false end
        local dx, dy = x - widget.touchX, y - widget.touchY
        if abs(dx) > TAP_SLOP or abs(dy) > TAP_SLOP then widget.touchMoved = true end
        if abs(dx) <= GESTURE_DX and not widget.lapView then
            local act = (dy <= -GESTURE_DY and not widget.tb) or (dy >= GESTURE_DY and widget.tb)
            if act then
                setToolbar(widget, dy < 0)
                widget.gConsume, widget.gConsumeAt, widget.touchX = true, os.clock(), nil
                consumeTouch()
                return true
            end
        end
    elseif value == TOUCH_END then
        widget.slidingUntil = os.clock() + 0.1
        local wasTap = widget.touchX and not widget.touchMoved
        widget.touchX = nil
        if not wasTap then return false end
        if widget.lapView then
            closeLapView(widget)
            return true
        end
        if widget.tb then
            for i = 1, #TB_ITEMS do
                local r = tbRects[i]
                if r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then
                    widget.tbSel = i
                    tbActivate(widget, r.item)
                    return true
                end
            end
            setToolbar(widget, false)               -- tap above the bar closes it
            return true
        end
    end
    return false
end

local function wakeup(widget)
    -- Same rule as the rfsuite dashboard: no work while another screen is shown.
    -- The drive aids keep running from the Lua sources regardless.
    if not lcd.isVisible() then
        widget.visible = false
        return
    end
    if not widget.visible then
        widget.visible = true
        widget.full = true                    -- came back into view: redraw everything once
    end

    core.update()
    laps.update()
    local now = os.clock()

    if now - widget.themeAt >= THEME_EVERY then
        widget.themeAt = now
        if colors() then widget.full = true end
    end

    if widget.tb then
        if now - widget.tbAt >= TB_TIMEOUT then
            setToolbar(widget, false)
        else
            local k = (laps.timerRunning and 1 or 0) + (laps.timerExpired and 2 or 0)
            if k ~= widget.tbKey then widget.tbKey, widget.full = k, true end
        end
    end

    if widget.lapView then
        if now - widget.textAt >= TEXT_EVERY then
            widget.textAt = now
            trackside.background()
            if laps.count ~= widget.lapViewKey then
                widget.lapViewKey = laps.count
                widget.full = true
            end
        end
        if now >= widget.slidingUntil then flush(widget) end
        return
    end

    if now - widget.textAt >= TEXT_EVERY then
        widget.textAt = now
        trackside.background()
        for i = 1, #boxes do
            local b = boxes[i]
            if b.src or b.sub or b.color then
                if refreshBox(b) then markBox(widget, b) end
            end
        end
    end

    if now - widget.scopeAt >= SCOPE_EVERY then
        widget.scopeAt = now
        local t = floor(core.proc.thr * 100 + 0.5)
        local s = floor(core.input.steer * 100 + 0.5)
        if t ~= widget.thrKey or s ~= widget.steerKey then
            widget.thrKey, widget.steerKey = t, s
            markBox(widget, scopeBox)
        end
        local f = flagKey()
        if f ~= widget.flagKey then
            widget.flagKey = f
            markBox(widget, lettersBox)
        end
    end

    -- Hold redraws while the screen is being swiped; flush once it settles.
    if now < widget.slidingUntil then return end
    flush(widget)
end


-- Set trackside.DEBUG_PAINT = true (main.lua) to log paints per second.
local paintCount, paintLogAt = 0, 0

local function paint(widget)
    if trackside.DEBUG_PAINT then
        paintCount = paintCount + 1
        local now = os.clock()
        if now - paintLogAt >= 2 then
            print(format("[trackside] paints/s %.1f", paintCount / (now - paintLogAt)))
            paintCount, paintLogAt = 0, now
        end
    end
    local W, H = lcd.getWindowSize()
    layout(W, H)
    if widget.lapView then
        drawLapView(W, H)
        return
    end
    lcd.color(C.bg)
    lcd.drawFilledRectangle(0, 0, W, H)
    for i = 1, #boxes do
        local b = boxes[i]
        if not (b.header and not layoutFull) then
            if b.kind == "letters" then
                if settings.get("showTimer") == 2 then drawTimer(b) else drawLetters(b) end
            elseif b.kind == "scope" then
                drawScope(b)
            else
                drawValueBox(b)
            end
        end
    end
    if widget.tb then drawToolbar(widget, W, H) end
end

-- Settings live in the Trackside system tool (per model, not per widget).
local function configure(widget)
    local line = form.addLine("Settings")
    form.addStaticText(line, nil, "System > Trackside")
end

return {
    key = "tshome",
    name = "Trackside",
    create = create,
    wakeup = wakeup,
    paint = paint,
    event = event,
    configure = configure,
    title = false,
}
